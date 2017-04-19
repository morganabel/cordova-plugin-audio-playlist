var exec = require('cordova/exec');

exports.initAudio = function(arg0, success, error) {
    exec(success, error, "CordovaPluginIosAudioPlaylist", "initAudio", [arg0]);
};
