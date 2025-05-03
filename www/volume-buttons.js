var exec = require('cordova/exec');

var VolumeButtons = {
  onVolumeButtonPressed: function(success, failure) {
    exec(success, failure, 'VolumeButtons', 'onVolumeButtonPressed', []);
  },
  setMonitoringMode: function(mode, success, failure) {
    // mode: "aggressive" | "silent" | "none"
    exec(success, failure, 'VolumeButtons', 'setMonitoringMode', [mode]);
  }
};

module.exports = VolumeButtons;
