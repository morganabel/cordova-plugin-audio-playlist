package com.mabel.plugins;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.mabel.plugins.CordovaPluginAudioPlaylist;
import com.mabel.plugins.AudioTrack;

import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnErrorListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.os.Environment;
import android.os.Handler;
import java.util.*;
import android.content.Intent;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

public class AudioPlayer implements OnCompletionListener, OnPreparedListener, OnErrorListener, AudioManager.OnAudioFocusChangeListener {
    // AudioPlayer states
    public enum STATE { 
                        READY,
                        PLAYING,
                        FAILED,
                        PAUSED,
                        LOADING,
                        ENDED
                      };

    public STATE state = STATE.READY;   
    public float duration = -1;    
    public boolean prepareOnly = true; 
    public Integer playIndex = 0;  
    public List<AudioTrack> queuedItems = new ArrayList();
    public static final String Broadcast_PLAY_NEW_AUDIO = "com.mabel.plugins.CordovaPluginAudioPlaylist.PlayNewAudio";

    private CordovaPluginAudioPlaylist cordovaLink = null;
    private AudioManager audioManager = null;
    private Handler progressTimerHandler = new Handler();
    private Runnable progressRunnable = null;
    private final Integer progressTimerInterval = 500;
    private boolean stopRunnable = false;      
    private boolean autoLoop = false;   
    private AudioPlayerService audioPlayerService;
    private boolean serviceBound = false;

    public AudioPlayer(CordovaPluginAudioPlaylist link) {
        this.cordovaLink = link;
        this.autoLoop = link.autoLoopPlaylist;

        IntentFilter iff = new IntentFilter(AudioPlayerService.ACTION_STATE_CHANGE);
        LocalBroadcastManager.getInstance(this).registerReceiver(onStateChange, iff);
    }

    public void destroy() {
        this.setState(STATE.READY);
        this.endProgressTimer();
        LocalBroadcastManager.getInstance(this).unregisterReciever(onStateChange);
    }

    public void play() {
        this.play(this.playIndex);
    }

    public void play(Integer index) {
        if (index >= this.queuedItems.size()) {
            if (this.queuedItems.size() > 0 && this.autoLoop) {
                this.replay();
            }
            return;
        }

        if (this.playIndex == index) {
            this.resumePlaying();
        } else {
            this.endProgressTimer();
            this.state = STATE.READY;
            this.playIndex = index;
            this.playAudio(index);
            //this.startPlaying(this.queuedItems.get(index).url);
        }
    }

    public void pause() {
        // If playing, then pause
        if (this.state == STATE.PLAYING) {
            this.audioPlayerService.pauseMedia();
            this.endProgressTimer();
            this.setState(STATE.PAUSED);
        }
    }

    public void toggle() {
        if (this.state == STATE.PLAYING) {
            this.pause();
        } else {
            this.play();
        }
    }

    public void stop() {
        if ((this.state == STATE.PLAYING) || (this.state == STATE.PAUSED)) {
            this.endProgressTimer();
            this.audioPlayerService.stopMedia();
            this.setState(STATE.READY);
        }
    }

    public void replay() {
        this.play(0);
    }

    public void setAutoLoop(boolean shouldAutoLoop) {
        this.autoLoop = shouldAutoLoop;
    }

    public void playNext() {
        this.play(this.playIndex + 1);
    }

    public void playPrevious() {
        this.play(this.playIndex - 1);
    }

    public void replayCurrentItem() {
        this.audioPlayerService.restartMedia();
    }

    public void resumePlaying() {
        this.audioPlayerService.resumeMedia();
    }

    public void addItem(JSONObject object) {
        AudioTrack track = new AudioTrack(object);
        queuedItems.add(track);

        storeAudioPlaylist();
    }

    public void removeAllItems() {
        queuedItems.clear();
        this.player.pause();
        this.player.release();
        this.playIndex = 0;
        this.player = null;
        this.prepareOnly = true;
    }

    public String getCurrentTrackId() {
        return queuedItems.get(this.playIndex).id;
    }

    public Integer getPlayIndex() {
        return this.playIndex;
    }

    public Integer getTotalTrackCount() {
        return this.queuedItems.size();
    }

    public boolean isLastTrack() {
        if (this.playIndex >= queuedItems.size()-1) {
            return true;
        } else {
            return false;
        }
    }

    public float getCurrentPosition() {
        if ((this.state == STATE.PLAYING) || (this.state == STATE.PAUSED)) {
            return (this.player.getCurrentPosition() / 1000.0f);
        }
        else {
            return -1;
        }
    }

    public float getDuration() {
        // If audio file already loaded and started, then return duration
        if (this.player != null) {
            return this.duration;
        }

        return 0;
    }

    public String getCurrentTrackTitle() {
        return queuedItems.get(this.playIndex).title;
    }

    public boolean isRemoteAudio(String file) {
        if (file.contains("http://") || file.contains("https://") || file.contains("rtsp://")) {
            return true;
        }
        else {
            return false;
        }
    }

    @Override
    public void onCompletion(MediaPlayer player) {
        if (this.playIndex >= queuedItems.size()-1) {
            if (this.autoLoop) {
                this.replay();
            } else {
                this.stop();
                this.setState(STATE.ENDED);
            }
        } else {
            this.playNext();
        }
    }

    @Override
    public void onPrepared(MediaPlayer player) {
        // Listen for playback completion
        this.player.setOnCompletionListener(this);
        this.startProgressTimer();

        // If start playing after prepared
        if (!this.prepareOnly) {
            this.player.start();
            this.setState(STATE.PLAYING);
        } else {
            this.setState(STATE.READY);
        }
        // Save off duration
        this.duration = getDurationInSeconds();
        // reset prepare only flag
        this.prepareOnly = true;
    }

    @Override
    public boolean onError(MediaPlayer player, int arg1, int arg2) {
        // we don't want to send success callback
        // so we don't call setState() here
        this.state = STATE.FAILED;
        this.endProgressTimer();
        this.destroy();
        // Send error notification to JavaScript
        //sendErrorStatus(arg1);

        // Send error to cordova.
        this.cordovaLink.notifyOnError();

        return false;
    }

    private void setState(STATE inputState) {
        this.state = inputState;
        this.cordovaLink.updateSongStatus();
    }

    private float getDurationInSeconds() {
        return (this.player.getDuration() / 1000.0f);
    }

    private void startPlaying(String file) {
        if (this.readyPlayer(file) && this.player != null) {
            this.player.start();
            this.setState(STATE.PLAYING);
        } else {
            this.prepareOnly = false;
        }
    }

    private boolean readyPlayer(String file) {
        switch (this.state) {
            case READY:
            case FAILED:
                if (this.player == null) {
                    this.player = new MediaPlayer();
                    this.player.setOnErrorListener(this);
                }
                this.player.reset();
                this.startProgressTimer();
                try {
                    this.loadAudioFile(file);
                } catch (Exception e) {
                    //sendErrorStatus(MEDIA_ERR_ABORTED);
                }
                return false;
            case LOADING:
                this.prepareOnly = false;
                return false;
            case PLAYING:
            case PAUSED:
                return true;
            default:
                //sendErrorStatus(MEDIA_ERR_ABORTED);
        }
        
        return false;
    }

    private void playAudio(int audioIndex) {
        //Check is service is active
        if (!serviceBound) {
            //Store Serializable audioList to SharedPreferences
            storeAudioPlaylist();
            StorageUtil storage = new StorageUtil(getApplicationContext());
            storage.storeAudioIndex(playIndex);

            Intent playerIntent = new Intent(this, AudioPlayerService.class);
            startService(playerIntent);
            bindService(playerIntent, serviceConnection, Context.BIND_AUTO_CREATE);
        } else {
            //Store the new audioIndex to SharedPreferences
            StorageUtil storage = new StorageUtil(getApplicationContext());
            storage.storeAudioIndex(playIndex);

            //Service is active
            //Send a broadcast to the service -> PLAY_NEW_AUDIO
            Intent broadcastIntent = new Intent(Broadcast_PLAY_NEW_AUDIO);
            sendBroadcast(broadcastIntent);
        }
    }

    private void storeAudioPlaylist() {
        //Store Serializable audioList to SharedPreferences
        StorageUtil storage = new StorageUtil(getApplicationContext());
        storage.storeAudio(queuedItems);
    }

    private BroadcastReceiver onStateChange = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            // intent can contain anydata
            AudioPlayer.STATE newState = (AudioPlayer.STATE)intent.getSerializableExtra("state");
            setState(newState);
        }
    };

    private void loadAudioFile(String file) throws IllegalArgumentException, SecurityException, IllegalStateException, IOException {
        if (this.isRemoteAudio(file)) {
            this.player.setDataSource(file);
            this.player.setAudioStreamType(AudioManager.STREAM_MUSIC);
            //if it's a streaming file, play mode is implied
            this.setState(STATE.LOADING);
            this.player.setOnPreparedListener(this);
            this.player.prepareAsync();
        } else {
            if (file.startsWith("/android_asset/")) {
                String f = file.substring(15);
                android.content.res.AssetFileDescriptor fd = this.cordovaLink.cordova.getActivity().getAssets().openFd(f);
                this.player.setDataSource(fd.getFileDescriptor(), fd.getStartOffset(), fd.getLength());
            }
            else {
                File fp = new File(file);
                if (fp.exists()) {
                    FileInputStream fileInputStream = new FileInputStream(file);
                    this.player.setDataSource(fileInputStream.getFD());
                    fileInputStream.close();
                }
                else {
                    this.player.setDataSource(Environment.getExternalStorageDirectory().getPath() + "/" + file);
                }
            }

            this.setState(STATE.LOADING);
            this.player.setOnPreparedListener(this);
            this.player.prepareAsync();
        }
    }

    private void startProgressTimer() {
        if (this.stopRunnable == false && this.progressRunnable != null) {
            return;
        }

        this.stopRunnable = false;
        
        if (this.progressRunnable == null) {

            this.progressRunnable = new Runnable() {
                @Override
                public void run() {
                    cordovaLink.updateSongStatus();

                    if (stopRunnable == false) {
                        progressTimerHandler.postDelayed(this, progressTimerInterval);
                    }
                }
            };

            this.progressTimerHandler.post(this.progressRunnable);
        } else {
            this.progressTimerHandler.postDelayed(this.progressRunnable, progressTimerInterval);
        }
    }

    private void endProgressTimer() {
        this.stopRunnable = true;
    }

    //Binding this Client to the AudioPlayer Service
    private ServiceConnection serviceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            // We've bound to LocalService, cast the IBinder and get LocalService instance
            AudioPlayerService.LocalBinder binder = (AudioPlayerService.LocalBinder) service;
            audioPlayerService = binder.getService();
            serviceBound = true;
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            serviceBound = false;
        }
    };
}