package com.benkesmith.plugins;

import org.apache.cordova.*;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioManager;
import android.view.KeyEvent;
import android.view.View;


public class VolumeButtons extends CordovaPlugin {

    private static final String ACTION_VOLUME_CHANGED = "android.media.VOLUME_CHANGED_ACTION";

    private String callbackId;
    private String mode = "aggressive";
    private AudioManager audioManager;
    private int baselineIndex;
    private int detectionIndex;
    private long lastEventTime = -1;


    // Receiver for background volume-change broadcasts
    private final BroadcastReceiver volumeChangeReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context ctx, Intent intent) {
            if (!ACTION_VOLUME_CHANGED.equals(intent.getAction())) return;

            int streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1);
            if (streamType != AudioManager.STREAM_MUSIC) return;

            int oldVol = intent.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1);
            int newVol = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1);
            if (oldVol < 0 || newVol < 0 || oldVol == newVol) return;

            // Ignore the broadcast caused by our own reset in aggressive mode
            if ("aggressive".equals(mode) && newVol == baselineIndex) {
                detectionIndex = baselineIndex;
                return;
            }

            // Detect direction against the last truly user‐set volume
            String dir = (newVol > detectionIndex) ? "up" : "down";
            detectionIndex = newVol;

            // Fire JS callback if enabled
            if (callbackId != null && !"none".equals(mode)) {
                fireJsEvent(dir);
            }

            // Snap back if aggressive
            if ("aggressive".equals(mode)) {
                resetVolume();
            }
        }
    };

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        audioManager = (AudioManager) cordova.getActivity()
                .getSystemService(Context.AUDIO_SERVICE);

        // Initialize baseline & detection indexes
        int curr = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
        baselineIndex  = curr;
        detectionIndex = curr;

        // Foreground: catch volume keys via OnKeyListener
        View rootView = webView.getView();
        rootView.setFocusableInTouchMode(true);
        rootView.requestFocus();
        rootView.setOnKeyListener((v, keyCode, event) -> {
            if (event.getAction() != KeyEvent.ACTION_DOWN) return false;
            if (keyCode != KeyEvent.KEYCODE_VOLUME_UP && keyCode != KeyEvent.KEYCODE_VOLUME_DOWN)
                return false;

            String dir = (keyCode == KeyEvent.KEYCODE_VOLUME_UP) ? "up" : "down";
            if (callbackId != null && !"none".equals(mode)) {
                fireJsEvent(dir);
            }
            if ("aggressive".equals(mode)) {
                resetVolume();
                return true;  // consume event
            }
            return false; // allow system handling in silent/none
        });

        // Background: listen for VOLUME_CHANGED broadcasts
        IntentFilter filter = new IntentFilter(ACTION_VOLUME_CHANGED);
        cordova.getActivity().registerReceiver(volumeChangeReceiver, filter);
    }

    @Override
    public void onDestroy() {
        cordova.getActivity().unregisterReceiver(volumeChangeReceiver);
        super.onDestroy();
    }

    @Override
    public boolean execute(String action, CordovaArgs args, CallbackContext cb) {
        if ("onVolumeButtonPressed".equals(action)) {
            this.callbackId = cb.getCallbackId();
            PluginResult res = new PluginResult(PluginResult.Status.NO_RESULT);
            res.setKeepCallback(true);
            cb.sendPluginResult(res);
            return true;
        }
        else if ("setMonitoringMode".equals(action)) {
            try {
                this.mode = args.getString(0);
                cb.success();
            } catch (Exception e) {
                cb.error("Invalid mode");
            }
            return true;
        }
        else if ("setBaselineVolume".equals(action)) {
            try {
                float v = (float) args.getDouble(0);
                if (v < 0.0f || v > 1.0f) throw new Exception();

                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int idx = Math.round(v * max);

                baselineIndex  = idx;
                detectionIndex = idx;

                // ✅ Immediately apply the new volume
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, baselineIndex, 0);

                cb.success();
            } catch (Exception e) {
                cb.error("Volume must be between 0.0 and 1.0");
            }
            return true;
        }
        else if ("getCurrentVolume".equals(action)) {
            try {
                boolean update = args.getBoolean(0);
                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int curr = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
                float currentVol = (float) curr / max;

                if (update) {
                    baselineIndex = curr;
                    detectionIndex = curr;
                }

                PluginResult result = new PluginResult(PluginResult.Status.OK, currentVol);
                cb.sendPluginResult(result);
            } catch (Exception e) {
                cb.error("Failed to get volume");
            }
            return true;
        }
        else if ("setVolume".equals(action)) {
            try {
                float level = (float) args.getDouble(0);
                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int newVol = Math.max(0, Math.min((int) Math.round(level * max), max));

                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVol, 0);
                baselineIndex = newVol;
                detectionIndex = newVol;

                cb.success();
            } catch (Exception e) {
                cb.error("Invalid volume value");
            }
            return true;
        }
        else if ("increaseVolume".equals(action)) {
            try {
                float step = (float) args.getDouble(0);
                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int curr = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
                int newVol = Math.min(max, (int) Math.round(curr + (step * max)));

                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVol, 0);
                baselineIndex = newVol;
                detectionIndex = newVol;

                cb.success();
            } catch (Exception e) {
                cb.error("Invalid step value");
            }
            return true;
        }
        else if ("decreaseVolume".equals(action)) {
            try {
                float step = (float) args.getDouble(0);
                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int curr = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
                int newVol = Math.max(0, (int) Math.round(curr - (step * max)));

                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVol, 0);
                baselineIndex = newVol;
                detectionIndex = newVol;

                cb.success();
            } catch (Exception e) {
                cb.error("Invalid step value");
            }
            return true;
        }

        return false;
    }

    /** Emit a raw event { direction, delta } to JS */
    private void fireJsEvent(String direction) {
        if (callbackId == null || "none".equals(mode)) return;

        long now = System.currentTimeMillis();
        long delta = (lastEventTime < 0) ? 0 : (now - lastEventTime);
        lastEventTime = now;

        try {
            JSONObject payload = new JSONObject();
            payload.put("direction", direction);
            payload.put("delta", delta);

            PluginResult result = new PluginResult(PluginResult.Status.OK, payload);
            result.setKeepCallback(true);
            webView.sendPluginResult(result, callbackId);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }


    private void resetVolume() {
        audioManager.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                baselineIndex,
                0
        );
    }
}

