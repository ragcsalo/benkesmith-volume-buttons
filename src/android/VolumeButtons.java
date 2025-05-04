package com.benkesmith.plugins;

import android.app.Activity;
import android.content.Context;
import android.media.AudioManager;
import android.view.KeyEvent;
import android.view.View;

import org.apache.cordova.*;

public class VolumeButtons extends CordovaPlugin {

    private String callbackId;
    private String mode = "aggressive"; // default
    private AudioManager audioManager;
    private float baselineVolume = -1;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        final View rootView = webView.getView();
        audioManager = (AudioManager) cordova.getActivity().getSystemService(Context.AUDIO_SERVICE);

        rootView.setFocusableInTouchMode(true);
        rootView.requestFocus();

        rootView.setOnKeyListener(new View.OnKeyListener() {
            @Override
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if (event.getAction() != KeyEvent.ACTION_DOWN) return false;

                if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                    String dir = (keyCode == KeyEvent.KEYCODE_VOLUME_UP) ? "up" : "down";

                    if (callbackId != null) {
                        PluginResult result = new PluginResult(PluginResult.Status.OK, dir);
                        result.setKeepCallback(true);
                        webView.sendPluginResult(result, callbackId);
                    }

                    if (mode.equals("aggressive")) {
                        resetVolume();
                        return true; // consume
                    }

                    return mode.equals("silent") ? false : false; // silent: allow change, none: do nothing
                }

                return false;
            }
        });
    }

    private void resetVolume() {
        if (baselineVolume < 0) return;

        int stream = AudioManager.STREAM_MUSIC;
        int max = audioManager.getStreamMaxVolume(stream);
        int target = Math.round(baselineVolume * max);
        audioManager.setStreamVolume(stream, target, 0);
    }

    @Override
    public boolean execute(String action, CordovaArgs args, final CallbackContext callbackContext) {
        switch (action) {
            case "onVolumeButtonPressed":
                this.callbackId = callbackContext.getCallbackId();
                PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
                result.setKeepCallback(true);
                callbackContext.sendPluginResult(result);
                return true;

            case "setMonitoringMode":
                try {
                    this.mode = args.getString(0);
                    callbackContext.success();
                } catch (Exception e) {
                    callbackContext.error("Missing or invalid mode");
                }
                return true;

            case "setBaselineVolume":
                try {
                    float vol = (float) args.getDouble(0);
                    if (vol < 0 || vol > 1) throw new IllegalArgumentException();
                    this.baselineVolume = vol;
                    callbackContext.success();
                } catch (Exception e) {
                    callbackContext.error("Baseline volume must be between 0.0 and 1.0");
                }
                return true;
        }

        return false;
    }
}
