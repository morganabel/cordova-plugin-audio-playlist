var exec = require('cordova/exec');

exports.initAudio = function(success, error) {
    audioPlugin.localForage.config({
        name: 'cordovaAudioPlaylits'
    });

    return execPromise(success, error, "CordovaPluginAudioPlaylist", "initAudio", []);
};

exports.clearPlaylist = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "clear", []);
}

exports.addItem = function(arg0, success, error) {
    if (arg0 instanceof Object && arg0.hasOwnProperty("uid") && arg0.hasOwnProperty("url")) {
        return audioPlugin.localForage.getItem("track-url-" + arg0.uid).then(function(result) {
            if (null !== result) {
                arg0.url = result;
            }
        }).catch(function(err) {

        }).then(function() {
            return execPromise(success, error, "CordovaPluginAudioPlaylist", "addItem", [arg0]);
        })
    } else {
        throw "Track not a valid object";
    }
};

exports.addManyItems = function(arg0, success, error) {
    if (Array.isArray(arg0)) {
        return Promise.all(arg0.map(
            function(track) {
                return audioPlugin.localForage.getItem("track-url-" + track.uid).then(function(result) {
                    if (null !== result) {
                        track.url = result;
                    }
                })
            })
        ).then(function(successResult) {

        }).catch(function(err) {

        }).then(function() {
            // Finally.
            return execPromise(success, error, "CordovaPluginAudioPlaylist", "addManyItems", [arg0]);
        });
    } else {
        throw "Add Many Items must be an array."
    }
};

exports.play = function(arg0, success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "play", [arg0]);
};

exports.pause = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "pause", []);
};

exports.watch = function(successCallback, error) {
    return exec(successCallback, error, "CordovaPluginAudioPlaylist", "watch", [])
}

exports.savePlaylistOffline = function(arg0, success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "savePlaylistOffline", [arg0]);
}

exports.getPlaylistOffline = function(arg0, success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "getPlaylistOffline", [arg0]);
}

function execPromise(success, error, pluginName, method, args) {
    return new Promise(function (resolve, reject) {
        exec(function (result) {
                resolve(result);
                if (typeof success === "function") {
                    success(result);
                }
            },
            function (reason) {
                reject(reason);
                if (typeof error === "function") {
                    error(reason);
                }
            },
            pluginName,
            method,
            args);
    });
}