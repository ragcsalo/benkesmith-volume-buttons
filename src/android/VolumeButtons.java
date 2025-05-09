package com.benkesmith.plugins;

import org.apache.cordova.*;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioManager;
import android.view.KeyEvent;
import android.view.View;
import android.util.Log;


enum PressType {
    UP, DOWN
}

public class VolumeButtons extends CordovaPlugin {

    private static final String ACTION_VOLUME_CHANGED = "android.media.VOLUME_CHANGED_ACTION";

    private String callbackId;
    private String mode = "aggressive";
    private AudioManager audioManager;
    private int baselineIndex;
    private int detectionIndex;
    private int longPressDetectedCount = 0;


    // Receiver for background volume-change broadcasts
    private BroadcastReceiver volumeChangeReceiver = new BroadcastReceiver() {
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

        return false;
    }


    private static final int DOUBLE_PRESS_MIN = 50;
    private static final int DOUBLE_PRESS_MAX = 400;
    private static final int LONG_PRESS_MAX_GAP = 80;
    private static final int SINGLE_PRESS_DELAY = 420;
    private static final int LONG_PRESS_IDLE = 120;

    private long lastPressTime = 0;
    private int pressCount = 0;
    private PressType lastDirection = null;
    private android.os.Handler handler = new android.os.Handler();
    private Runnable pressTimeoutRunnable = null;

    private void fireJsEvent(String direction) {
        boolean longPressDetected;
        PressType current = direction.equals("up") ? PressType.UP : PressType.DOWN;
        long now = System.currentTimeMillis();
        long delta = now - lastPressTime;

        boolean isRapidRepeat = delta < 100;

        if (isRapidRepeat) {
            longPressDetectedCount++;
        } else {
            longPressDetectedCount = 0;
        }

        boolean lastPressWasRapidRepeat = delta < 100;

        Log.d("VolumeButtons", "fireJsEvent: direction=" + direction +
                ", pressCount=" + pressCount +
                ", delta=" + delta + "ms");

        if (lastDirection == null || lastDirection != current || delta > DOUBLE_PRESS_MAX) {

            pressCount = 0;
            Log.d("VolumeButtons", "Reset pressCount due to direction change or idle timeout.");
        }

        pressCount++;
        lastPressTime = now;
        lastDirection = current;

        if (pressTimeoutRunnable != null) {
            handler.removeCallbacks(pressTimeoutRunnable);
            Log.d("VolumeButtons", "Cleared previous timeout.");
        }

        pressTimeoutRunnable = () -> {
            String type;
            int count;

            if (longPressDetectedCount >= 2) {
                type = "long";
                count = 1;
            } else if (pressCount == 1) {
                type = "single";
                count = 1;
            } else {
                type = "multiple";
                count = pressCount;
            }

            sendEventToJs(direction, type, count);
            Log.d("VolumeButtons", "Confirmed press type: " + type + ", count: " + count + ", direction: " + direction);

            pressCount = 0;
            lastDirection = null;
        };

        // Always reset the timer to wait for a final 400ms pause before confirming
        handler.postDelayed(pressTimeoutRunnable, DOUBLE_PRESS_MAX);  // 400ms
        Log.d("VolumeButtons", "Scheduled classification after pause.");
    }


    private void sendEventToJs(String direction, String type, int count) {
        if (callbackId == null || "none".equals(mode)) return;

        try {
            org.json.JSONObject payload = new org.json.JSONObject();
            payload.put("direction", direction); // "up" or "down"
            payload.put("type", type);           // "single", "multiple", or "long"
            payload.put("count", count);         // 1 for single/long, >=2 for multiple

            PluginResult result = new PluginResult(PluginResult.Status.OK, payload);
            result.setKeepCallback(true);
            webView.sendPluginResult(result, callbackId);
        } catch (Exception e) {
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

