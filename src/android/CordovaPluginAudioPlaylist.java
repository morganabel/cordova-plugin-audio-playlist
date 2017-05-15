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

import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnErrorListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.os.Environment;
import android.net.Uri;
import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

public class CordovaPluginAudioPlaylist extends CordovaPlugin {
    private CallbackContext callbackId = null;
    private AudioPlayer audioPlayer = null;


    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
    }

    public void onDestroy() {
        if (this.audioPlayer != null) this.audioPlayer.destroy();
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

    private void initAudio() {
        this.audioPlayer = new AudioPlayer(this);
    }

    private void clearPlaylist() {
        this.audioPlayer.destroy();
        this.audioPlayer = new AudioPlayer(this);
    }

    private void watch(CallbackContext context) {
        this.callbackId = context;
    }

    private void addItem(JSONObject track) {
        try {
            String url = track.getString("url");
            this.audioPlayer.addItem(this.stripFileProtocol(url));

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

    private JSONObject getCurrentSongStatus() {
        JSONObject output = new JSONObject();

        try {
            output.put("duration", this.audioPlayer.getDuration());
            output.put("currentTime", this.audioPlayer.getCurrentPosition());
            output.put("playIndex", this.audioPlayer.playIndex);
            output.put("state", this.audioPlayer.state.toString().toLowerCase());
            output.put("isLastTrack", this.audioPlayer.isLastTrack());
        } catch (JSONException e) {
            
        }

        return output;
    }

    private String stripFileProtocol(String uriString) {
        if (uriString.startsWith("file://")) {
            return Uri.parse(uriString).getPath();
        }
        return uriString;
    }
}
