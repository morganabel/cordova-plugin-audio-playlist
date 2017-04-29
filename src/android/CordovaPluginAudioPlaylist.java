package com.mabel.plugins;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnErrorListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.media.MediaRecorder;
import android.os.Environment;

public class CordovaPluginAudioPlaylist extends CordovaPlugin {

    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("initAudio")) {
            this.initAudio(callbackContext);
        } else if (action.equals("")) {

        } else {
            return false;
        }

        return true;
    }

    private void initAudio(CallbackContext callbackContext) {
        callbackContext.success();
    }

    private void clearPlaylist() {

    }

    private void addItem() {

    }

    private void play() {

    }

    private void pause() {

    }
}
