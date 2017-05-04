package com.mabel.plugins;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.mabel.plugins.CordovaPluginAudioPlaylist;

import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnErrorListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.os.Environment;
import android.os.Handler;
import java.util.*;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

public class AudioPlayer implements OnCompletionListener, OnPreparedListener, OnErrorListener {
    // AudioPlayer states
    public enum STATE { 
                        READY,
                        PLAYING,
                        FAILED,
                        PAUSED,
                        LOADING,
                        ENDED
                      };

    public MediaPlayer player = null;
    public STATE state = STATE.READY;   
    public float duration = -1;    
    public boolean prepareOnly = true; 
    public Integer playIndex = 0;  
    public List<String> queuedItems = new ArrayList();

    private CordovaPluginAudioPlaylist cordovaLink = null;
    private Handler progressTimerHandler = new Handler();
    private Runnable progressRunnable = null;
    private final Integer progressTimerInterval = 500;
    private boolean stopRunnable = false;         

    public AudioPlayer(CordovaPluginAudioPlaylist link) {
        this.cordovaLink = link;
    }

    public void destroy() {
        // Stop any play or record
        if (this.player != null) {
            if ((this.state == STATE.PLAYING) || (this.state == STATE.PAUSED)) {
                this.player.stop();
                this.setState(STATE.READY);
            }
            this.player.release();
            this.player = null;
            this.endProgressTimer();
        }
    }

    public void play() {
        this.play(this.playIndex);
    }

    public void play(Integer index) {
        if (this.playIndex == index) {
            this.resumePlaying();
        } else {
            this.endProgressTimer();
            this.state = STATE.READY;
            this.playIndex = index;
            this.startPlaying(this.queuedItems.get(index));
        }
    }

    public void pause() {

        // If playing, then pause
        if (this.state == STATE.PLAYING && this.player != null) {
            this.player.pause();
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
            this.player.pause();
            this.endProgressTimer();
            this.player.seekTo(0);
            this.player.release();
            this.setState(STATE.READY);
        }
    }

    public void replay() {
        this.player.seekTo(0);
        this.play(0);
    }

    public void playNext() {
        this.play(this.playIndex + 1);
    }

    public void playPrevious() {
        this.play(this.playIndex - 1);
    }

    public void replayCurrentItem() {
        this.player.seekTo(0);
        this.play();
    }

    public void resumePlaying() {
    	this.startPlaying(this.queuedItems.get(this.playIndex));
    }

    public void addItem(String file) {
        queuedItems.add(file);
    }

    public void removeAllItems() {
        queuedItems.clear();
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

    public boolean isRemoteAudio(String file) {
        if (file.contains("http://") || file.contains("https://") || file.contains("rtsp://")) {
            return true;
        }
        else {
            return false;
        }
    }

    public void onCompletion(MediaPlayer player) {
        if (this.playIndex >= queuedItems.size()-1) {
            this.stop();
            this.setState(STATE.ENDED);
        } else {
            this.playNext();
        }
    }

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

    public boolean onError(MediaPlayer player, int arg1, int arg2) {
        // we don't want to send success callback
        // so we don't call setState() here
        this.state = STATE.FAILED;
        this.endProgressTimer();
        this.destroy();
        // Send error notification to JavaScript
        //sendErrorStatus(arg1);

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
            this.player.prepare();

            // Get duration
            this.duration = getDurationInSeconds();
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
}