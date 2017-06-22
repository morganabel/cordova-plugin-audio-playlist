package com.mabel.plugins;

import org.apache.cordova.CordovaPlugin;

import java.util.ArrayList;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.mabel.plugins.AudioPlayer.STATE;

import java.io.File;
import java.io.FileNotFoundException;

import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnErrorListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.os.Environment;
import android.os.Bundle;
import android.net.Uri;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

public class CordovaPluginAudioPlaylist extends CordovaPlugin {
    private CallbackContext callbackId = null;
    private CallbackContext errorCallbackId = null;
    private AudioPlayer audioPlayer = null;
    public boolean autoLoopPlaylist = false;
    public String cacheDirectory = null;


    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        Context context = cordova.getActivity();
        cacheDirectory = Uri.fromFile(context.getCacheDir()).toString() + '/';
    }

    public void onDestroy() {
        super.onDestroy();
        if (this.audioPlayer != null) this.audioPlayer.destroy();
    }

    public Bundle onSaveInstanceState() 
    {
        Bundle state = new Bundle();
        return state;
    }

    public void onRestoreStateForActivityResult(Bundle state, CallbackContext callbackContext) 
    {
        //this.callbackContext = callbackContext;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        PluginResult.Status status = PluginResult.Status.OK;
        String result = "";

        if (action.equals("initAudio")) {
            this.initAudio();
        } else if (action.equals("clearPlaylist")) {
            this.clearPlaylist();
        } else if (action.equals("watch")) {
            this.watch(callbackContext);
            return true;
        } else if (action.equals("onError")) {
            this.onError(callbackContext);
            return true;
        } else if (action.equals("addItem")) {
            this.addItem(args.getJSONObject(0));
        } else if (action.equals("addManyItems")) {
            this.addManyItems(args.getJSONArray(0));
        } else if (action.equals("toggle")) {
            this.toggle();
        } else if (action.equals("play")) {
            this.play();
        } else if (action.equals("pause")) {
            this.pause();
        } else if (action.equals("next")) {
            this.next();
        } else if (action.equals("previous")) {
            this.previous();
        } else if (action.equals("stop")) {
            this.stop();
        } else if (action.equals("loop")) {
            this.loop();
        } else if (action.equals("setAutoLoop")) {
            this.setAutoLoop(args.getBoolean(0));
        } else if (action.equals("getPlayIndex")) {
            callbackContext.sendPluginResult(new PluginResult(status, this.audioPlayer.getPlayIndex()));
            return true;
        } else if (action.equals("isLastTrack")) {
            callbackContext.sendPluginResult(new PluginResult(status, this.audioPlayer.isLastTrack()));
            return true;
        } else {
            return false;
        }

        callbackContext.sendPluginResult(new PluginResult(status, result));

        return true;
    }

    public void updateSongStatus() {
        JSONObject message = this.getCurrentSongStatus();

        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, message);
        pluginResult.setKeepCallback(true);
        if (callbackId != null) {
            callbackId.sendPluginResult(pluginResult);
        }
    }

    public void notifyOnError() {
        JSONObject message = this.getCurrentSongStatus();

        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, message);
        pluginResult.setKeepCallback(true);
        if (errorCallbackId != null) {
            errorCallbackId.sendPluginResult(pluginResult);
        }
    }

    private void initAudio() {
        this.audioPlayer = new AudioPlayer(this);
    }

    private void clearPlaylist() {
        this.audioPlayer.pause();
        this.audioPlayer.destroy();
        this.audioPlayer = new AudioPlayer(this);
    }

    private void watch(CallbackContext context) {
        this.callbackId = context;
    }

    private void onError(CallbackContext context) {
        this.errorCallbackId = context;
    }

    private void addItem(JSONObject track) {
        try {
            this.audioPlayer.addItem(track);

            if (track.getBoolean("autoPlay") && this.audioPlayer.state != STATE.PLAYING) {
                this.audioPlayer.play();
            }
        } catch (JSONException e) {
            
        }
    }

    private void addManyItems(JSONArray jsonArray) {
        try {
            for (int i=0;i<jsonArray.length();i++){ 
                this.addItem(jsonArray.getJSONObject(i));
            }
        } catch (JSONException e) {

        }
    }

    private void toggle() {
        this.audioPlayer.toggle();
    }

    private void play() {
        this.audioPlayer.play();
    }

    private void pause() {
        this.audioPlayer.pause();
    }

    private void next() {
        this.audioPlayer.playNext();
    }

    private void previous() {
        this.audioPlayer.playPrevious();
    }

    private void stop() {
        this.audioPlayer.stop();
    }

    private void loop() {
        this.audioPlayer.replay();
    }

    private void setAutoLoop(boolean shouldLoop) {
        this.autoLoopPlaylist = shouldLoop;
        this.audioPlayer.setAutoLoop(shouldLoop);
    }

    private JSONObject getCurrentSongStatus() {
        JSONObject output = new JSONObject();

        try {
            output.put("trackId", this.audioPlayer.getCurrentTrackId());
            output.put("duration", this.audioPlayer.getDuration());
            output.put("currentTime", this.audioPlayer.getCurrentPosition());
            output.put("playIndex", this.audioPlayer.playIndex);
            output.put("title", this.audioPlayer.getCurrentTrackTitle());
            output.put("state", this.audioPlayer.state.toString().toLowerCase());
            output.put("isLastTrack", this.audioPlayer.isLastTrack());
        } catch (JSONException e) {
            
        }

        return output;
    }
}
