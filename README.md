# cordova-plugin-volume-buttons

**Detect volume button presses (up/down) on iOS – even when the phone is locked.**  
Perfect for remote-controlling Cordova-based magic apps (or other stealth interactions).

✨ Built by @ragcsalo (Benke Smith) to help magicians perform real magic with invisible input.

---

## ✅ Features

- Detect **Volume Up / Down** button presses
- Works even when:
  - App is **in the background**
  - Phone is **locked**
- Three modes:
  - `aggressive`: blocks the system volume bar and resets volume after each press
  - `silent`: shows the system volume UI, lets volume change, still detects presses
  - `none`: disables all volume detection

---

## 🔧 Installation

```bash
cordova plugin add https://github.com/YOUR_USERNAME/cordova-plugin-volume-buttons.git
