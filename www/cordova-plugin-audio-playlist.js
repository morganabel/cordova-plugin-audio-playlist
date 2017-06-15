var exec = require('cordova/exec');

var downloadStatus = {
    NONE: 0,
    INPROGRESS: 1,
    DONE: 2,
    FAILED: 3
}

var playlistPrefix = "playlist-";
var cachePrefix = "cache-";
var savedTrackPrefix = "track-url-";
var cacheDirectoryConst = "APP_CACHE/";
var savedDirectoryConst = "APP_SAVED/";

var pq;
var onProgressLookupIdToPercentages = {};
var onProgressFn = null;

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
    clearCache();
    pq = new audioPlugin.promiseQueue.default({ concurrency: 2 });

    return execPromise(success, error, "CordovaPluginAudioPlaylist", "initAudio", []);
};

exports.isInit = function() {
    return isInit;
}

exports.clearPlaylist = function(success, error) {
    tracks = [];
    pq.pause();
    pq = new audioPlugin.promiseQueue.default({ concurrency: 2 });
    
    return clearCache().then(function() {
    }).catch(function(err) {
    }).then(function() {
        return execPromise(success, error, "CordovaPluginAudioPlaylist", "clearPlaylist", []);
    })    
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

exports.getTotalTrackCount = function() {
    return tracks.length;
}

exports.addItem = function(arg0, progressFn, success, error) {
    if (arg0 instanceof Object && arg0.hasOwnProperty("id") && arg0.hasOwnProperty("url")) {
        var trackProgress = isFunction(progressFn);
        if (trackProgress) {
            onProgressLookupIdToPercentages = {};
            onProgressFn = progressFn;
        }

        tracks.push(arg0);
        if (trackProgress) {
            onProgressLookupIdToPercentages[arg0.id] = 0;
        }

        pq.add(function() {
            return getSavedOrCachedTrackFileUrl(arg0).then(function(result) {
                if (null !== result) {
                    arg0.remoteUrl = arg0.url;
                    arg0.url = result;
                }

                if (trackProgress) {
                    onProgressLookupIdToPercentages[arg0.id] = 100;
                    calculateAndReportOnProgress();
                }
            }).catch(function(err) {
                return Promise.reject(err);
            }).then(function() {
                return execPromise(success, error, "CordovaPluginAudioPlaylist", "addItem", [arg0]);
            })
        });

        return Promise.resolve();
    } else {
        throw "Track not a valid object";
    }
};

exports.addManyItems = function(arg0, progressFn, success, error) {
    if (Array.isArray(arg0)) {
        var trackProgress = isFunction(progressFn);
        if (trackProgress) {
            onProgressLookupIdToPercentages = {};
            onProgressFn = progressFn;
        }

        return Promise.all(arg0.map(
            function(track) {
                tracks.push(track);
                if (trackProgress) {
                    onProgressLookupIdToPercentages[track.id] = 0;
                }

                return getSavedOrCachedTrackFileUrl(track).then(function(result) {
                    if (null !== result) {
                        track.remoteUrl = track.url;
                        track.url = result;
                    }

                    if (trackProgress) {
                        onProgressLookupIdToPercentages[track.id] = 100;
                        calculateAndReportOnProgress();
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

exports.setAutoLoop = function(shouldLoop, success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "setAutoLoop", [shouldLoop]);
}

exports.loop = function(success, error) {
    return execPromise(success, error, "CordovaPluginAudioPlaylist", "loop", []);
}

exports.watch = function(successCallback, error) {
    return exec(successCallback, error, "CordovaPluginAudioPlaylist", "watch", [])
}

exports.onError = function(callback, error) {
    // TODO: Consider deleting onError? 
    // By number of times, error code, etc.
    // By network status

    return exec(callback, error, "CordovaPluginAudioPlaylist", "onError", [])
}

exports.isPlaylistSaved = function(playlistId) {
    if (!localForageInit) {
        configureLocalForage();
    }

    return isPlaylistSavedAsync(playlistId);
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

        return downloadPlaylist(playlist);
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

exports.removeSavedTracksByPrefix = function(prefix) {
    if (!localForageInit) {
        configureLocalForage();
    }

    if (prefix.length < 1) return;

    return clearCache(prefix);
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

function downloadPlaylist(playlist, cache) {
    if (cache === void 0) { cache = false; }

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
                                return audioPlugin.localForage.setItem(savedTrackPrefix + song.id, trackResult).then(function(storeSongResult) {
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

function downloadTrack(track, cache) {
    if (cache === void 0) { cache = false; }
    var dataStorageLocation = (!cache) ? cordova.file.dataDirectory : cordova.file.cacheDirectory; 
    var prefix = (!cache) ? savedDirectoryConst : cacheDirectoryConst;

    return new Promise(function(resolve, reject) {
        window.resolveLocalFileSystemURL(dataStorageLocation, function (dirEntry) {
            var fileTransfer = new FileTransfer();
            var uri = track.url;

            // Parameters passed to getFile create a new file or return the file if it already exists.
            dirEntry.getFile(track.id + '.mp3', { create: true, exclusive: false }, function (fileEntry) {
                if (onProgressLookupIdToPercentages.hasOwnProperty(track.id)) {
                    fileTransfer.onProgress = function(progressEvent) {
                        if (!onProgressLookupIdToPercentages.hasOwnProperty(track.id)) return;
                        if (progressEvent.lengthComputable) {
                            onProgressLookupIdToPercentages[track.id] = (progressEvent.loaded / progressEvent.total) * 100;
                        } else {
                            if (onProgressLookupIdToPercentages[track.id] <= 99) {
                                onProgressLookupIdToPercentages[track.id]++;
                            }
                        }

                        calculateAndReportOnProgress();
                    }
                }

                fileTransfer.download(
                    uri,
                    fileEntry.nativeURL,
                    function(entry) {
                        resolve(prefix + entry.name);
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

function deleteFileUrlFromDisk(url) {
    return new Promise(function(resolve, reject) {
        url = replaceAll(url, savedDirectoryConst, cordova.file.dataDirectory);
        url = replaceAll(url, cacheDirectoryConst, cordova.file.cacheDirectory);

        window.resolveLocalFileSystemURL(url, function(file) {
            file.remove(function(){
                resolve();
            }, function(err) {
                reject(err);
            });
        }, function (err) {
            reject(err);
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

function isPlaylistSavedAsync(playlistId, cache) {
    if (cache === void 0) { cache = false; }
    
    return new Promise(function(resolve, reject) {
        getPlaylistLookupAsync().then(function(success) {
            resolve(playlistIdLookup.hasOwnProperty(playlistId));
        }).catch(function(err) {
            reject(err);
        });
    });
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


function getSavedOrCachedTrackFileUrl(track) {
    return new Promise(function(resolve, reject) {
        audioPlugin.localForage.getItem(savedTrackPrefix + track.id).then(function(result) {
            if (null !== result) {
                result = replaceAll(result, savedDirectoryConst, cordova.file.dataDirectory);
                resolve(result);
            } else {
                getOrCacheTrackFileUrl(track).then(function(downloadTrackFileUrl) {
                    downloadTrackFileUrl = replaceAll(downloadTrackFileUrl, cacheDirectoryConst, cordova.file.cacheDirectory);
                    resolve(downloadTrackFileUrl);
                }).catch(function(err) {
                    reject(err);
                });
            }
        }).catch(function(err) {
            reject(err);
        });
    });
}

function getOrCacheTrackFileUrl(track) {
    return new Promise(function(resolve, reject) {
        audioPlugin.localForage.getItem(cachePrefix + track.id).then(function(result) {
            if (null !== result) {
                resolve(result);
            }

            downloadTrack(track, true).then(function(downloadTrackFileUrl) {
                audioPlugin.localForage.setItem(cachePrefix + track.id, downloadTrackFileUrl).then(function() {
                    resolve(downloadTrackFileUrl);
                }).catch(function(err) {
                    reject(err);
                });
            }).catch(function(err) {
                reject(err);
            });
        }).catch(function(err) {
            reject(err);
        })
    });
}

function clearCache(prefix) {
    if (prefix === void 0) { prefix = cachePrefix; }
    var matches = [];

    return audioPlugin.localForage.iterate(function(value, key, iterationNumber) {
        if (startsWith(key, prefix)) {
            matches.push({
                key: key,
                value: value
            });
        }
    }).then(function() {
        if (matches.length > 0) {
            var concurrencyCount = (device.platform === "Android") ? 1 : 10;
            var matchQueue = new audioPlugin.promiseQueue.default({ concurrency: concurrencyCount });
            
            matches.forEach(function(match) {
                matchQueue.add(function() {
                    return deleteFileUrlFromDisk(match.value).then(function() {
                        return audioPlugin.localForage.removeItem(match.key);
                    }).catch(function(err) {
                        if (err.hasOwnProperty("code") && err.code === 1) {
                            return audioPlugin.localForage.removeItem(match.key);
                        }
                    });
                });
            });
        }
    }).catch(function(err) {
        
    });
}

function calculateAndReportOnProgress() {
    if (null === onProgressFn) return;

    var count = 0;
    var completed = 0;
    var percentageTotal = 0;

    for (prop in onProgressLookupIdToPercentages) {
        if (onProgressLookupIdToPercentages.hasOwnProperty(prop)) {
            count++;
            percentageTotal += onProgressLookupIdToPercentages[prop];

            if (onProgressLookupIdToPercentages[prop] >= 99) {
                completed++;
            }
        }
    }

    var percentage = percentageTotal / count;

    var output = {
        percentage: percentage,
        completed: completed,
        total: count
    };

    onProgressFn(output);
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

function startsWith(str, prefix) {
    if (str.length < prefix.length)
        return false;
    for (var i = prefix.length - 1; (i >= 0) && (str[i] === prefix[i]); --i)
        continue;
    return i < 0;
}

function replaceAll(input, search, replacement) {
    return input.replace(new RegExp(escapeRegExp(search), 'g'), replacement)
}

function escapeRegExp(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // $& means the whole matched string
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

function isFunction(obj) {
    return !!(obj && obj.constructor && obj.call && obj.apply);
}