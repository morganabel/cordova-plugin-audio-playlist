package com.mabel.plugins;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.mabel.plugins.CordovaPluginAudioPlaylist;
import com.mabel.plugins.AudioTrack;

import android.content.BroadcastReceiver;
import android.support.v4.content.LocalBroadcastManager;
import android.content.ComponentName;
import android.content.Context;
import android.os.IBinder;
import android.content.IntentFilter;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnErrorListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.os.Environment;
import android.os.Handler;
import java.util.*;
import android.content.Intent;
import android.content.ServiceConnection;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

public class AudioPlayer {
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
    public Integer playIndex = 0;  
    public ArrayList<AudioTrack> queuedItems = new ArrayList();
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
        IntentFilter trackChangeIntent = new IntentFilter(AudioPlayerService.ACTION_TRACK_CHANGE);
        LocalBroadcastManager.getInstance(this.cordovaLink.cordova.getActivity().getApplicationContext()).registerReceiver(onStateChange, iff);
        LocalBroadcastManager.getInstance(this.cordovaLink.cordova.getActivity().getApplicationContext()).registerReceiver(onTrackChange, trackChangeIntent);
    }

    public void destroy() {
        this.setState(STATE.READY);
        this.endProgressTimer();
        LocalBroadcastManager.getInstance(this.cordovaLink.cordova.getActivity().getApplicationContext()).unregisterReceiver(onStateChange);
        LocalBroadcastManager.getInstance(this.cordovaLink.cordova.getActivity().getApplicationContext()).unregisterReceiver(onTrackChange);
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
            if (serviceBound) {
                this.resumePlaying();
            } else {
                this.playAudio(index);
            }
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
        StorageUtil storage = new StorageUtil(this.cordovaLink.cordova.getActivity().getApplicationContext());
        storage.storeAutoPlay(shouldAutoLoop);
    }

    public void playNext() {
        this.audioPlayerService.skipToNext();
    }

    public void playPrevious() {
        this.audioPlayerService.skipToPrevious();
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
        storeAudioPlaylist();
        this.audioPlayerService.stopMedia();
        this.playIndex = 0;
        new StorageUtil(this.cordovaLink.cordova.getActivity().getApplicationContext()).storeAudioIndex(this.playIndex);
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
        if (audioPlayerService != null) {
            return audioPlayerService.getCurrentPosition();
        }

        return -1;
    }

    public float getDuration() {
        // If audio file already loaded and started, then return duration
        if (audioPlayerService != null) {
            return audioPlayerService.getDuration();
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

    private void setState(STATE inputState) {
        this.state = inputState;
        handleChangeState();
        
    }

    private void handleChangeState() {
        switch (this.state) {
            case PAUSED:
            case ENDED:
                this.endProgressTimer();
                break;
            case PLAYING:
                this.startProgressTimer();
                break;
            case READY:
                this.endProgressTimer();
                break;
            case FAILED:
                this.endProgressTimer();
                // Send error to cordova.
                this.cordovaLink.notifyOnError();
                break;
            case LOADING:
                this.endProgressTimer();
                break;
            default:
                break;
        }

        this.cordovaLink.updateSongStatus();
    }

    private void playAudio(int audioIndex) {
        Context localContext = this.cordovaLink.cordova.getActivity();

        //Check is service is active
        if (!serviceBound) {
            //Store Serializable audioList to SharedPreferences
            storeAudioPlaylist();
            StorageUtil storage = new StorageUtil(this.cordovaLink.cordova.getActivity().getApplicationContext());
            storage.storeAudioIndex(playIndex);

            Intent playerIntent = new Intent(localContext, AudioPlayerService.class);
            localContext.startService(playerIntent);
            localContext.bindService(playerIntent, serviceConnection, Context.BIND_AUTO_CREATE);
        } else {
            //Store the new audioIndex to SharedPreferences
            StorageUtil storage = new StorageUtil(this.cordovaLink.cordova.getActivity().getApplicationContext());
            storage.storeAudioIndex(playIndex);

            //Service is active
            //Send a broadcast to the service -> PLAY_NEW_AUDIO
            Intent broadcastIntent = new Intent(Broadcast_PLAY_NEW_AUDIO);
            
            localContext.sendBroadcast(broadcastIntent);
        }
    }

    private void storeAudioPlaylist() {
        //Store Serializable audioList to SharedPreferences
        StorageUtil storage = new StorageUtil(this.cordovaLink.cordova.getActivity().getApplicationContext());
        storage.storeAudio(queuedItems);

        if (serviceBound && audioPlayerService != null) {
            audioPlayerService.refreshTrackList();
        }
    }

    private BroadcastReceiver onStateChange = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            // intent can contain anydata
            AudioPlayer.STATE newState = (AudioPlayer.STATE)intent.getSerializableExtra("state");
            setState(newState);
        }
    };

    private BroadcastReceiver onTrackChange = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            // intent can contain anydata
            Integer newIndex = intent.getIntExtra("playIndex", 0);
            playIndex = newIndex;
            cordovaLink.updateSongStatus();
        }
    };

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