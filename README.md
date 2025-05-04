# cordova-plugin-volume-buttons

**Detect volume button presses (up/down) on iOS and Android â€“ even when the phone is locked.**  
Perfect for remote-controlling Cordova-based magic apps (or other stealth interactions).

âś¨ Built by @ragcsalo (Benke Smith) to help magicians perform real magic with invisible input.

---

## âś… Features

- Detect **Volume Up / Down** button presses
- Works even when:
  - App is **in the background**
  - Phone is **locked**
- Three modes:
  - `aggressive`: blocks the system volume bar and resets volume after each press
  - `silent`: shows the system volume UI, lets volume change, still detects presses
  - `none`: disables all volume detection
- Set a custom baseline volume for resets in aggressive mode

---

## đź”§ Installation

```bash
cordova plugin add https://github.com/ragcsalo/benkesmith-volume-buttons.git
```

> Replace `ragcsalo` with your actual GitHub username if hosting privately.

---

## đź“˛ Usage

### 1. Register a callback:

```javascript
document.addEventListener('deviceready', function () {
  VolumeButtons.onVolumeButtonPressed(function (direction) {
    console.log('Volume button pressed:', direction); // "up" or "down"
  });
});
```

### 2. Set monitoring mode:

```javascript
// Options: "aggressive", "silent", or "none"
VolumeButtons.setMonitoringMode("aggressive");
```

### 3. Set a custom baseline volume (optional):

```javascript
// Set baseline volume to 0.55 (range: 0.0 to 1.0)
VolumeButtons.setBaselineVolume(0.55);
```

---

## đź“ Example: React to button presses

```javascript
VolumeButtons.onVolumeButtonPressed(function (direction) {
  if (direction === "up") {
    triggerForceField(); // or any custom magic
  } else if (direction === "down") {
    activateStealthMode();
  }
});
```

---

## đźŽ› Modes Explained

| Mode        | Volume UI | Volume Changes | Button Detection | Use Case                       |
|-------------|-----------|----------------|------------------|--------------------------------|
| `aggressive`| âťŚ Hidden | âťŚ Prevented    | âś… Yes           | Full stealth control (magic)   |
| `silent`    | âś… Shown  | âś… Allowed      | âś… Yes           | User feedback still visible    |
| `none`      | âś… Shown  | âś… Allowed      | âťŚ No            | Temporarily disable monitoring |

---

## đź“ File Structure

- `src/ios/VolumeButtons.m` â€“ iOS native code
- `src/ios/VolumeButtons.h` â€“ Objective-C header
- `src/android/VolumeButtons.java` â€“ Android native code
- `www/volume-buttons.js` â€“ JavaScript interface
- `plugin.xml` â€“ Cordova plugin manifest
- `src/ios/silence.mp3` â€“ Silent loop to keep audio session alive (iOS only)

---

## âť— Known Limitations

- **Physical buttons only** â€“ Control Center sliders do not trigger events
- Cordova must run with microphone/audio permissions (audio session keeps app active)
- On Android, volume interception is managed via `dispatchKeyEvent`; ensure your app's activity handles key events appropriately

---

## đź§™ About

This plugin was crafted by **Benke Smith** ([@ragcsalo](https://github.com/ragcsalo))  
to give magicians invisible input capabilities on iOS and Android devices using volume keys.

Feel free to fork, improve, or raise issues.

---

## đź’– Like it?

Consider â­ď¸Ź starring the repo or buying Benke a coffee.  
And go amaze your audiences.
