# Sleepy's Backscreen — iOS App

Companion iOS application for the **Smart Music Backpack Display** (ESP32 via Bluetooth Low Energy).

---

## What the iOS App Does
1. **Interactive Backpack Control:** Built-in offline WebKit simulator with real-time audio visualization, custom text marquee banners, theme switching, and speed controls.
2. **CoreBluetooth LE (ESP32):** Automatically discovers and pairs with `SMART_BACKPACK_DISPLAY` (UUID: `19B10000-E8F2-537E-4F6C-D104768A1214`).
3. **Apple Music Integration:** Reads your currently playing track details, progress, and 80x80 album artwork via `MPMusicPlayerController` and transmits it in RGB565 binary packets to the backpack screen.
4. **Custom 3D Glass Equalizer Icon:** Includes Apple-inspired 3D glass icon set across all iPhone and iPad resolutions.

---

## How to Run on iPhone

### Method A: With a Mac (Xcode)
1. Copy the `ios-app` folder to your Mac (or clone your GitHub repository).
2. Open `SleepysBackscreen.xcodeproj` in **Xcode**.
3. Plug in your iPhone with a USB cable.
4. In Xcode, select your connected iPhone from the top target device dropdown.
5. In **Signing & Capabilities**, select your free Personal Apple ID Team.
6. Click **Run (Cmd + R)**.
7. On your iPhone, go to **Settings > General > VPN & Device Management** and trust your Developer App certificate.

---

### Method B: Without a Mac (GitHub Actions + Sideloadly / AltStore)
1. Push this folder to a GitHub repository.
2. GitHub Actions will automatically run the `.github/workflows/build-ios.yml` workflow on macOS.
3. Once finished, download the **`SleepysBackscreen-iOS-IPA`** artifact.
4. Install it on your iPhone using:
   - **Sideloadly** (Windows & Mac, free): Connect iPhone via USB, drag `SleepysBackscreen.ipa`, enter your Apple ID, click Start.
   - **AltStore** (free): Put the IPA on your iPhone and install via AltStore.
   - **TrollStore** (if jailbroken/supported iOS version).

---

## Project Structure
```
ios-app/
├── SleepysBackscreen.xcodeproj/   # Xcode project definition
├── SleepysBackscreen/
│   ├── App/                       # App entry point (SwiftUI)
│   ├── Views/                     # UI Views & WKWebView Bridge
│   ├── Bluetooth/                 # CoreBluetooth BLE Manager
│   ├── Music/                     # MPMusicPlayerController system observer
│   ├── Utils/                     # RGB565 converter & chunk packager
│   ├── Assets.xcassets/           # AppIcon set & Color catalog
│   ├── Web/                       # Bundled offline React Web UI
│   └── Info.plist                 # Permissions (Bluetooth & Music)
└── .github/workflows/             # Automated IPA CI build
```
