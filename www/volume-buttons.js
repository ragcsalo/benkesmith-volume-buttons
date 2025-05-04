var exec = require('cordova/exec');

var VolumeButtons = {
  onVolumeButtonPressed: function (success, failure) {
    exec(success, failure, 'VolumeButtons', 'onVolumeButtonPressed', []);
  },
  setMonitoringMode: function (mode, success, failure) {
    exec(success, failure, 'VolumeButtons', 'setMonitoringMode', [mode]);
  },
  setBaselineVolume: function (value, success, failure) {
    exec(success, failure, 'VolumeButtons', 'setBaselineVolume', [value]);
  }
};

module.exports = VolumeButtons;

