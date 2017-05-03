var exec = require('cordova/exec');

var downloadStatus = {
    NONE: 0,
    INPROGRESS: 1,
    DONE: 2,
    FAILED: 3
}

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
    if (arg0 instanceof Object && arg0.hasOwnProperty("id") && arg0.hasOwnProperty("url")) {
        return audioPlugin.localForage.getItem("track-url-" + arg0.id).then(function(result) {
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
                return audioPlugin.localForage.getItem("track-url-" + track.id).then(function(result) {
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

exports.play = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "play", []);
};

exports.pause = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "pause", []);
};

exports.watch = function(successCallback, error) {
    return exec(successCallback, error, "CordovaPluginAudioPlaylist", "watch", [])
}

exports.savePlaylistOffline = function(inputPlaylist) {
    var playlist =  {
        id: "",
        title: "",
        albumPicture: "",
        songs: null,
        downloadStatus: downloadStatus.NONE
    }

    playlist = extend(playlist, inputPlaylist, true);
    playlist.songs.forEach(function(song) {
        song.downloadStatus = downloadStatus.NONE;
    });

    return audioPlugin.localForage.setItem("playlist-" + playlist.id, playlist).then(function() {
        downloadPlaylist(playlist);
    });
}

exports.getPlaylistOffline = function(playlistId) {
    return audioPlugin.localForage.getItem("playlist-" + playlistId);
}

exports.downloadTrack = function(track) {
    return downloadTrack(track);
}

function downloadPlaylist(playlist) {
    return new Promise(function(resolve, reject) {
        audioPlugin.localForage.getItem("playlist-" + playlist.id).then(function(result) {
            if (result !== null) {
                playlist = result;
            }

            Promise.all(
                playlist.songs.map(function(song) {
                    switch (song.downloadStatus) {
                        case downloadStatus.NONE:
                        case downloadStatus.FAILED:
                            return downloadTrack(song).then(function(trackResult) {
                                audioPlugin.localForage.setItem("track-url-" + song.id).then(function(storeSongResult) {
                                    song.url = trackResult;
                                    song.downloadStatus = downloadStatus.DONE;
                                });
                            }).catch(function(trackErr) {
                                song.downloadStatus = downloadStatus.FAILED;
                            });
                        default:
                            return Promise.resolve();
                    }
                })
            ).then(function(allSuccess) {
                audioPlugin.localForage.setItem("playlist-" + playlist.id, playlist).then(function() {
                    resolve(playlist);
                }).catch(function(saveErr) {
                    reject(saveErr);
                });
            }).catch(function(allErr) {
                reject(allErr);
            });
        }); 
    });
}

function downloadTrack(track) {
    return new Promise(function(resolve, reject) {
        window.requestFileSystem(cordova.file.dataDirectory, 0, function (fs) {
            var fileTransfer = new FileTransfer();
            var uri = encodeURI(track.url);

            // Parameters passed to getFile create a new file or return the file if it already exists.
            fs.root.getFile(track.id + '.mp3', { create: true, exclusive: false }, function (fileEntry) {
                fileTransfer.download(
                    uri,
                    fileEntry,
                    function(entry) {
                        resolve(entry.toURL());
                    },
                    function(error) {
                        reject(error);
                    },
                    false,
                    {
                        headers: {}
                    }
                );
            }, function(onErrorCreateFile) {
                reject(onErrorCreateFile);
            });
        }, function(onErrorFs) {
            reject(onErrorFs);
        });
    });
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

function extend(obj, src, overwrite) {
    Object.keys(src).forEach(function(key) { 
        if (obj.hasOwnProperty(key)) {
            if (isEmpty(obj[key]) || overwrite === true) {
                obj[key] = src[key];
            }
        } else {
            obj[key] = src[key]; 
        }
    });
    return obj;
}

function isEmpty(e) {
  switch (e) {
    case "":
    case 0:
    case "0":
    case null:
    case false:
    case typeof this === "undefined":
      return true;
    default:
      return false;
  }
}