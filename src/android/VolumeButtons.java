package com.benkesmith.plugins;

import org.apache.cordova.*;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Build;
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

    // Silent Player: Keeps the app "alive" in background
    private AudioTrack silentTrack;

    // Receiver for volume-change broadcasts
    private final BroadcastReceiver volumeChangeReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context ctx, Intent intent) {
            if (!ACTION_VOLUME_CHANGED.equals(intent.getAction())) return;

            int streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1);
            if (streamType != AudioManager.STREAM_MUSIC) return;

            int newVol = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1);
            int oldVol = intent.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1);

            if (oldVol < 0 || newVol < 0) return;

            // In Aggressive Mode: Ignore the broadcast caused by OUR OWN reset
            if ("aggressive".equals(mode) && newVol == baselineIndex) {
                detectionIndex = baselineIndex;
                return;
            }

            // --- MAGNITUDE CALCULATION ---
            // Calculate total steps jumped
            int diff = newVol - detectionIndex;

            if ("aggressive".equals(mode)) {
                diff = newVol - baselineIndex;
            }

            if (diff != 0 && callbackId != null && !"none".equals(mode)) {
                String dir = diff > 0 ? "up" : "down";
                int steps = Math.abs(diff);

                // --- CHANGE: Pass the magnitude directly ---
                // Instead of firing 5 times, we fire ONCE with volumeChange: 5
                fireJsEvent(dir, steps);
            }

            detectionIndex = newVol;

            if ("aggressive".equals(mode)) {
                resetVolume();
            }
        }
    };

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        Context context = cordova.getActivity().getApplicationContext();
        audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);

        int curr = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
        baselineIndex = curr;
        detectionIndex = curr;

        // Foreground Handling
        View rootView = webView.getView();
        rootView.setFocusableInTouchMode(true);
        rootView.requestFocus();
        rootView.setOnKeyListener((v, keyCode, event) -> {
            if (event.getAction() != KeyEvent.ACTION_DOWN) return false;
            if (keyCode != KeyEvent.KEYCODE_VOLUME_UP && keyCode != KeyEvent.KEYCODE_VOLUME_DOWN)
                return false;

            String dir = (keyCode == KeyEvent.KEYCODE_VOLUME_UP) ? "up" : "down";

            // Foreground hardware keys always represent 1 "click" at a time
            if (callbackId != null && !"none".equals(mode)) {
                fireJsEvent(dir, 1);
            }

            if ("aggressive".equals(mode)) {
                resetVolume();
                return true;
            }
            return false;
        });

        IntentFilter filter = new IntentFilter(ACTION_VOLUME_CHANGED);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(volumeChangeReceiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            context.registerReceiver(volumeChangeReceiver, filter);
        }

        updateMode(this.mode);
    }

    private void updateMode(String newMode) {
        this.mode = newMode;
        if ("aggressive".equals(mode)) {
            startSilentPlayer();
        } else {
            stopSilentPlayer();
        }
    }

    private void startSilentPlayer() {
        if (silentTrack != null) return;

        try {
            int sampleRate = 44100;
            int bufferSize = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);

            AudioAttributes attributes = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build();

            AudioFormat format = new AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build();

            silentTrack = new AudioTrack(attributes, format, bufferSize, AudioTrack.MODE_STATIC, AudioManager.AUDIO_SESSION_ID_GENERATE);

            byte[] silence = new byte[bufferSize];
            silentTrack.write(silence, 0, silence.length);
            silentTrack.setLoopPoints(0, silence.length / 2, -1);
            silentTrack.play();

        } catch (Exception e) { e.printStackTrace(); }
    }

    private void stopSilentPlayer() {
        if (silentTrack != null) {
            try {
                silentTrack.stop();
                silentTrack.release();
            } catch (Exception ignored) {}
            silentTrack = null;
        }
    }

    @Override
    public void onDestroy() {
        stopSilentPlayer();
        try {
            cordova.getActivity().getApplicationContext().unregisterReceiver(volumeChangeReceiver);
        } catch (Exception ignored) {}
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
                String newMode = args.getString(0);
                cordova.getActivity().runOnUiThread(() -> updateMode(newMode));
                cb.success();
            } catch (Exception e) { cb.error("Invalid mode"); }
            return true;
        }
        else if ("setBaselineVolume".equals(action)) {
            try {
                float v = (float) args.getDouble(0);
                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int idx = Math.round(v * max);
                baselineIndex  = idx;
                detectionIndex = idx;
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, baselineIndex, 0);
                cb.success();
            } catch (Exception e) { cb.error("Error setting baseline"); }
            return true;
        }
        else if ("getCurrentVolume".equals(action)) {
            try {
                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int curr = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
                float currentVol = (float) curr / max;
                cb.sendPluginResult(new PluginResult(PluginResult.Status.OK, currentVol));
            } catch (Exception e) { cb.error("Failed to get volume"); }
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
            } catch (Exception e) { cb.error("Error"); }
            return true;
        }
        else if ("increaseVolume".equals(action) || "decreaseVolume".equals(action)) {
            try {
                float step = (float) args.getDouble(0);
                int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                int curr = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
                int direction = "increaseVolume".equals(action) ? 1 : -1;
                int newVol = Math.max(0, Math.min(max, (int) Math.round(curr + (direction * step * max))));
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVol, 0);
                baselineIndex = newVol;
                detectionIndex = newVol;
                cb.success();
            } catch (Exception e) { cb.error("Error"); }
            return true;
        }
        return false;
    }

    private void resetVolume() {
        try {
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, baselineIndex, 0);
        } catch (SecurityException e) {}
    }

    // --- UPDATED METHOD SIGNATURE ---
    private void fireJsEvent(String direction, int volumeChange) {
        if (callbackId == null || "none".equals(mode)) return;

        long now = System.currentTimeMillis();
        long delta = (lastEventTime < 0) ? 0 : (now - lastEventTime);
        lastEventTime = now;

        try {
            JSONObject payload = new JSONObject();
            payload.put("direction", direction);
            payload.put("delta", delta);

            // New Parameter: How much the volume actually jumped
            payload.put("volumeChange", volumeChange);

            PluginResult result = new PluginResult(PluginResult.Status.OK, payload);
            result.setKeepCallback(true);

            cordova.getActivity().runOnUiThread(() -> {
                if (webView != null) webView.sendPluginResult(result, callbackId);
            });

        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
}
