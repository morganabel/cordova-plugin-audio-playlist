package com.mabel.plugins;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.os.Environment;
import android.net.Uri;
import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import java.util.*;

public class AudioTrack {
    public String id = "";
    public String title = "";
    public String artist = "";
    public String album = "";
    public String url = "";
    public String remoteUrl = "";

    public AudioTrack(JSONObject track) {
        try {
            String inputUrl = track.getString("url");
            url = this.stripFileProtocol(inputUrl);
            remoteUrl = this.stripFileProtocol(uriString.getString("remoteUrl"));

            id = track.getString("id");
            title = track.getString("title");
            album = track.getString("album");
            artist = track.getString("artist");
        } catch (JSONException e) {
            
        }
    }

    private String stripFileProtocol(String uriString) {
        if (uriString.startsWith("file://")) {
            return Uri.parse(uriString).getPath();
        }
        return uriString;
    }
}