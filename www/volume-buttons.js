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
  },
  getCurrentVolume: function (setAsBaseline, success, failure) {
    exec(success, failure, 'VolumeButtons', 'getCurrentVolume', [!!setAsBaseline]);
  },
  setVolume: function (value, success, error) {
    exec(success, error, 'VolumeButtons', 'setVolume', [value]);
  },

  increaseVolume: function (delta, success, error) {
    exec(success, error, 'VolumeButtons', 'increaseVolume', [delta]);
  },

  decreaseVolume: function (delta, success, error) {
    exec(success, error, 'VolumeButtons', 'decreaseVolume', [delta]);
  }
};

module.exports = VolumeButtons;

