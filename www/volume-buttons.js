var exec = require('cordova/exec');

var VolumeButtons = {
    onVolumeButtonPressed: function(callback, errorCallback) {
        exec(callback, errorCallback, 'VolumeButtons', 'onVolumeButtonPressed', []);
    }
};

module.exports = VolumeButtons;
