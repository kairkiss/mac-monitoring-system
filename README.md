# Mac监控系统

A lightweight macOS camera monitoring and automation app with local media storage, scheduled capture, optional Telegram push notifications, motion detection, and activity logs.

> 中文简介：一个原生 macOS 摄像头自动化工具，支持实时预览、拍照录像、自动任务、Telegram 推送、本地媒体库、活动日志、移动检测、健康检查和菜单栏后台运行。

## Features

- **Camera Preview** — Real-time webcam preview with photo capture and video recording.
- **Photo & Video Capture** — Capture photos, record videos, optionally record audio, and optionally split long recordings into smaller segments.
- **Media Library** — Browse, preview, play, export, drag, copy, delete, and manage captured photos and videos.
- **Automation** — Schedule automatic captures with daily, weekly, countdown, or interval-based tasks.
- **Reliable Automation Push** — Automation captures use a completion callback so Telegram sends the newly captured photo, not a stale previous one.
- **Telegram Push** — Send captured photos to your own Telegram chat through your own Bot Token.
- **Secure Token Storage** — Telegram Bot Token is stored in macOS Keychain; Chat ID and normal preferences are stored locally.
- **Activity Log** — Review camera events, automation events, Telegram success/failure, motion events, health warnings, and security events.
- **Motion Detection** — Optional local frame-difference based motion detection with sensitivity, cooldown, capture-on-motion, and Telegram-on-motion settings.
- **Health Monitor** — Basic monitoring for low disk space, camera disconnects, and repeated Telegram failures.
- **Local Notifications** — Optional macOS notifications for important warnings and health events.
- **Menu Bar** — Runs in the background with a menu bar icon, quick capture, automation toggle, and control panel access.
- **Storage Management** — Custom storage path, storage usage stats, and automatic cleanup of old files.
- **Multi-Camera Support** — Select between built-in and external cameras, with persistent camera selection.
- **Bilingual UI** — Chinese and English, switchable in Settings.

## Screenshots

> Coming soon

## System Requirements

- macOS 14.0 Sonoma or later
- A built-in or external webcam
- Microphone permission is optional and only needed when audio recording is enabled
- Xcode 15+ if building from source

## Download

Download the latest `.zip` from [Releases](../../releases).

Unzip it and drag `CameraApp.app` to your Applications folder.

> **Note:** This app is currently not signed or notarized. On first launch, right-click the app and select **Open** to bypass Gatekeeper. See [macOS Gatekeeper help](https://support.apple.com/en-us/HT202491) for details.

## First Launch

1. Open the app.
2. Grant camera permission when macOS asks.
3. If you want to record audio with videos, enable audio recording in Settings and grant microphone permission.
4. Configure Telegram only if you want push notifications.
5. Create automation tasks from the Automation page.
6. Close the main window if you want the app to keep running from the menu bar.

## Configure Telegram Bot

1. Create a Telegram Bot via [@BotFather](https://t.me/BotFather) and get the **Bot Token**.
2. Find your **Chat ID**, for example with [@userinfobot](https://t.me/userinfobot).
3. In the app, go to **Settings** and enter your Bot Token and Chat ID.
4. Use **Test Send** to confirm your Telegram configuration works.
5. When creating an automation task, enable **Send to Telegram** for that task.

Photos are sent to your own Telegram chat through your own Bot Token. No data is sent to the developer.

### Telegram Token Storage

- Telegram Bot Token is stored securely in macOS Keychain.
- Telegram Chat ID is stored locally in UserDefaults.
- Older versions stored the Bot Token in UserDefaults. Newer versions migrate it to Keychain automatically when possible.

## Automation Tasks

Go to the **Automation** page to create scheduled tasks:

| Type | Description |
|------|-------------|
| Daily | Capture at a specific time every day |
| Weekly | Capture on selected weekdays |
| Countdown | Capture once after N minutes |
| Interval | Capture every N minutes for a duration |

Enable the global automation toggle in the menu bar or the Automation page to activate tasks.

The app also includes initial missed-task recovery support for daily and weekly tasks after app restore or system wake.

## Activity Log

The **Activity Log** page helps you understand what the app did and when it happened.

It can record events such as:

- Camera startup, errors, reconnects, and disconnects
- Manual photo/video actions
- Automation task execution
- Telegram send success or failure
- Motion detection events
- Health monitor warnings
- Keychain token migration and security-related events

The log page supports filtering, searching, copying, exporting, and clearing logs.

## Motion Detection

Motion Detection is optional and runs locally on your Mac.

When enabled, the app analyzes low-resolution frame differences from the camera feed. Depending on your settings, motion events can:

- Only be logged
- Trigger a photo capture
- Trigger a photo capture and Telegram push

Available settings include:

- Enable Motion Detection
- Motion Sensitivity: Low / Medium / High
- Motion Cooldown
- Capture on Motion
- Telegram on Motion

No motion data is uploaded by default.

## Health Monitor

The Health Monitor is optional and can help detect common issues:

- Low disk space
- Camera disconnected
- Repeated Telegram send failures

When enabled, important warnings can be written to Activity Log and optionally shown as macOS notifications.

## Media Library

The Media Library lets you manage captured media locally:

- Browse photos and videos
- Open photo/video details
- Play videos
- Share, copy, export, or reveal files in Finder
- Batch delete
- Drag files to Finder or other apps
- View file size and creation time
- Track extra metadata through the media index

Captured files are stored locally by default:

```text
~/Library/Application Support/CameraApp/Photos/
~/Library/Application Support/CameraApp/Videos/
```

You can choose a custom storage directory in Settings.

## Menu Bar

The app runs in the background with a menu bar icon. From the menu bar you can:

- Toggle automation on/off
- Quick capture a photo
- Open the main control panel
- Quit the app

Closing the main window does not quit the app. It continues running from the menu bar.

## Build from Source

```bash
git clone https://github.com/kairkiss/mac-monitoring-system.git
cd mac-monitoring-system
xcodebuild -project CameraApp.xcodeproj -scheme CameraApp -configuration Release build
```

The built app should be available in Xcode's build products directory.

There is also a `build.sh` helper script in the repository. It is only for building/packaging the app from the command line; it is not part of the app's runtime features.

## Privacy

- Camera access is required for preview, capture, and recording.
- Microphone access is only needed when audio recording is enabled.
- All photos and videos are stored locally on your Mac by default.
- Telegram push is opt-in and uses your own Bot Token.
- Telegram Bot Token is stored in macOS Keychain.
- No analytics, no tracking, and no third-party SDKs are included.

See [PRIVACY.md](PRIVACY.md) for full details.

## Security Notes

This project is designed for personal device monitoring, scheduled capture, and local automation. It is not intended for hidden recording, stealth surveillance, bypassing macOS permissions, or monitoring people without consent.

## License

[MIT](LICENSE)
