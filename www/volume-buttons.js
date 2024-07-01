var exec = require('cordova/exec');

var VolumeButtons = {
    onVolumeButtonPressed: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, 'VolumeButtons', 'onVolumeButtonPressed', []);
    }
};

module.exports = VolumeButtons;
