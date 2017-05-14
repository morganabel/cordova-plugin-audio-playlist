var exec = require('cordova/exec');

var downloadStatus = {
    NONE: 0,
    INPROGRESS: 1,
    DONE: 2,
    FAILED: 3
}

var playlistPrefix = "playlist-";

var isInit = false;
var localForageInit = false;
var tracks = [];
var playlistIdLookup = null;
var getIdsPromise = null;

exports.initAudio = function(success, error) {
    if (!localForageInit) {
        configureLocalForage();
    }

    isInit = true;

    return execPromise(success, error, "CordovaPluginAudioPlaylist", "initAudio", []);
};

exports.isInit = function() {
    return isInit;
}

exports.clearPlaylist = function(success, error) {
    tracks = [];
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "clearPlaylist", []);
}

exports.getCurrentTrack = function(success, error) {
    return new Promise(function(resolve, reject) {
        execPromise(success, error, "CordovaPluginAudioPlaylist", "getPlayIndex", []).then((index) => {
            resolve(tracks[index]);
        }).catch((err) => {
            reject(reject);
        });
    });
}

exports.getTracks = function() {
    return tracks;
}

exports.isLastTrack = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "isLastTrack", []);
}

exports.addItem = function(arg0, success, error) {
    if (arg0 instanceof Object && arg0.hasOwnProperty("id") && arg0.hasOwnProperty("url")) {
        tracks.push(arg0);

        return audioPlugin.localForage.getItem("track-url-" + arg0.id).then(function(result) {
            if (null !== result) {
                arg0.url = result;
            }
        }).catch(function(err) {
            return Promise.reject(err);
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
                tracks.push(track);

                return audioPlugin.localForage.getItem("track-url-" + track.id).then(function(result) {
                    if (null !== result) {
                        track.url = result;
                    }
                })
            })
        ).then(function(successResult) {

        }).catch(function(err) {
            return Promise.reject(err);
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

exports.toggle = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "toggle", []);
}

exports.next = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "next", []);
}

exports.previous = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "previous", []);
}

exports.stop = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "stop", []);
}

exports.loop = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "loop", []);
}

exports.watch = function(successCallback, error) {
    return exec(successCallback, error, "CordovaPluginAudioPlaylist", "watch", [])
}

exports.isPlaylistSaved = function(playlistId) {
    if (!localForageInit) {
        configureLocalForage();
    }

    return new Promise(function(resolve, reject) {
        getPlaylistLookupAsync().then(function(success) {
            resolve(playlistIdLookup.hasOwnProperty(playlistId));
        }).catch(function(err) {
            reject(err);
        });
    });
}

exports.savePlaylistOffline = function(inputPlaylist) {
    if (!localForageInit) {
        configureLocalForage();
    }

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

    return audioPlugin.localForage.setItem(playlistPrefix + playlist.id, playlist).then(function() {
        if (!isEmpty(playlistIdLookup)) {
            playlistIdLookup[playlist.id] = true;
        }

        downloadPlaylist(playlist);
    });
}

exports.getPlaylistOffline = function(playlistId) {
    if (!localForageInit) {
        configureLocalForage();
    }

    return audioPlugin.localForage.getItem(playlistPrefix + playlistId);
}

exports.getAllPlaylistsOffline = function() {
    if (!localForageInit) {
        configureLocalForage();
    }

    return new Promise(function(resolve, reject) {
        getPlaylistLookupAsync().then(function() {
            var promiseArray = [];

            for(var prop in playlistIdLookup) {
                promiseArray.push(audioPlugin.localForage.getItem(playlistPrefix + prop));
            }

            Promise.all(promiseArray).then(function(results) {
                resolve(results);
            }).catch(function(err) {
                reject(err);
            });
        }).catch(function(err) {
            reject(err);
        });
    });
}

exports.removePlaylistOffline = function(playlistId) {
    if (!localForageInit) {
        configureLocalForage();
    }

    // TODO: Actually delete stored tracks.
    return audioPlugin.localForage.removeItem(playlistPrefix + playlistId).then(function() {
        if (!isEmpty(playlistIdLookup)) {
            delete playlistIdLookup[playlistId];
        }
    });
}

exports.syncPlaylistOffline = function(playlistFromServer) {
    if (!localForageInit) {
        configureLocalForage();
    }

    return downloadPlaylist(playlist);
}

exports.resumeDownload = function(playlistId) {
    if (!localForageInit) {
        configureLocalForage();
    }

    return audioPlugin.localForage.getItem(playlistPrefix + playlistId).then((playlist) => {
        if (!isEmpty(playlist)) {
            downloadPlaylist(playlist);
        }
    })
};

exports.downloadTrack = function(track) {
    if (!localForageInit) {
        configureLocalForage();
    }

    return downloadTrack(track);
}

function downloadPlaylist(playlist) {
    return new Promise(function(resolve, reject) {
        audioPlugin.localForage.getItem(playlistPrefix + playlist.id).then(function(result) {
            if (result !== null) {
                playlist = syncPlaylists(playlist, result);
            }

            Promise.all(
                playlist.songs.map(function(song, index) {
                    switch (song.downloadStatus) {
                        case downloadStatus.NONE:
                        case downloadStatus.FAILED:
                            return downloadTrack(song).then(function(trackResult) {
                                return audioPlugin.localForage.setItem("track-url-" + song.id, trackResult).then(function(storeSongResult) {
                                    playlist.songs[index].url = trackResult;
                                    playlist.songs[index].downloadStatus = downloadStatus.DONE;
                                });
                            }).catch(function(trackErr) {
                                playlist.songs[index].downloadStatus = downloadStatus.FAILED;
                            });
                        default:
                            return Promise.resolve();
                    }
                })
            ).then(function(allSuccess) {
                playlist.downloadStatus = downloadStatus.DONE;
                audioPlugin.localForage.setItem(playlistPrefix + playlist.id, playlist).then(function() {
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
        window.resolveLocalFileSystemURL(cordova.file.dataDirectory, function (dirEntry) {
            var fileTransfer = new FileTransfer();
            var uri = track.url;

            // Parameters passed to getFile create a new file or return the file if it already exists.
            dirEntry.getFile(track.id + '.mp3', { create: true, exclusive: false }, function (fileEntry) {
                fileTransfer.download(
                    uri,
                    fileEntry.nativeURL,
                    function(entry) {
                        resolve(entry.nativeURL);
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

/**
 * Syncs an incoming playlist from server with saved playlist on device.
 * 
 * @param {any} inputPlaylist 
 * @param {any} savedPlaylist 
 * @returns 
 */
function syncPlaylists(inputPlaylist, savedPlaylist) {
    var mergedSongList = syncSongLists(inputPlaylist.songs, savedPlaylist.songs);

    var output = extend(savedPlaylist, inputPlaylist, true);
    output.songs = mergedSongList;

    return output;
}

/**
 * Syncs song lists to ensure already downloaded songs not downloaded again.
 * 
 * @param {any} inputSongs 
 * @param {any} savedSongs 
 * @returns 
 */
function syncSongLists(inputSongs, savedSongs) {
    var lookup = {};

    // Create lookup object for faster matching.
    savedSongs.forEach(function(song) {
        lookup[song.id] = song;
    });

    inputSongs.forEach(function(song, index) {
        if (lookup.hasOwnProperty(song.id)) {
            var savedMatch = lookup[song.id];
            song = extend(song, savedMatch, false);
        }
    });

    return inputSongs;
}

function getPlaylistLookupAsync() {
    if (isEmpty(playlistIdLookup)) {
        if (isEmpty(getIdsPromise)) {
            getIdsPromise = new Promise(function(resolve, reject) {
                audioPlugin.localForage.keys().then(function(keys) {
                    playlistIdLookup = {};

                    keys.forEach(function(key) {
                        if (key.lastIndexOf(playlistPrefix, 0) === 0) {
                            playlistIdLookup[key.substring(playlistPrefix.length)] = true;
                        }
                    });

                    resolve(playlistIdLookup);
                }).catch(function(err) {
                    reject(err);
                });
            });
        }

        return getIdsPromise;
    } else {
        return Promise.resolve(playlistIdLookup);
    }
}

function configureLocalForage() {
    // Configure local forage.
    audioPlugin.localForage.config({
        name: 'cordovaAudioPlaylists'
    });

    localForageInit = true;
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