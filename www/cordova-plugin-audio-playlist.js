var exec = require('cordova/exec');

exports.initAudio = function(success, error) {
    exec(success, error, "CordovaPluginAudioPlaylist", "initAudio", []);
};

exports.clearPlaylist = function(arg0, success, error) {
    exec(success, error, "CordovaPluginAudioPlaylist", "clear", [arg0]);
}

exports.addItem = function(arg0, success, error) {
    exec(success, error, "CordovaPluginAudioPlaylist", "addItem", [arg0]);
};

exports.play = function(arg0, success, error) {
    exec(success, error, "CordovaPluginAudioPlaylist", "play", [arg0]);
};

exports.pause = function(arg0, success, error) {
    exec(success, error, "CordovaPluginAudioPlaylist", "pause", [arg0]);
};

exports.savePlaylistOffline = function(arg0, success, error) {
    exec(success, error, "CordovaPluginAudioPlaylist", "savePlaylistOffline", [arg0]);
}

exports.getPlaylistOffline = function(arg0, success, error) {
    exec(success, error, "CordovaPluginAudioPlaylist", "getPlaylistOffline", [arg0]);
}