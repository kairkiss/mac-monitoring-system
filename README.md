# Mac监控系统

MacMonitor 2.0 turns the app into a local camera node with a web dashboard, storage providers, upload queue, cloud archival, and automated retention.

Mac监控系统 2.0 将本地摄像头工具升级为 Mac 常驻采集节点，支持网页控制台、存储后端、上传队列、云端归档和自动保留策略。

> **v2.1.1** — Web Media Auth Hotfix. Fixes 401 errors on web media thumbnails, previews, and downloads; adds large-file protection and Retention manual cleanup. See [CHANGELOG.md](CHANGELOG.md) for details.

## Features

- **Camera Preview** — Real-time webcam preview with photo capture and video recording
- **Media Library** — Browse, view, and delete captured photos and videos with swipe navigation, pinch-to-zoom, EXIF viewer, and slideshow mode
- **Automation** — Schedule automatic captures: daily, weekly, countdown, or interval-based, with timeline visualization and execution history
- **Telegram Push** — Send captured photos to your Telegram chat via Bot API
- **Motion Detection** — Frame-diff based motion detection with configurable sensitivity; optional auto-capture and Telegram push on motion
- **Event Recording** — Motion-triggered short video clips with configurable duration
- **Health Monitor** — Camera disconnect, low disk, upload failure, and storage provider alerts
- **Activity Log** — JSONL-based logging with search, filter, and export
- **Multi-Camera** — Supports multiple cameras with preferred camera persistence and graceful fallback
- **Web Dashboard** — Browser-based control panel with live camera snapshots, media library with thumbnails, task management, and upload queue monitoring
- **REST API** — Full API for camera, media, tasks, logs, health, uploads, and storage
- **Storage Providers** — Local folder and mounted folder backends (available); Google Drive and WebDAV (planned, not fully implemented)
- **Upload Queue** — Persistent queue with retry, progress tracking, pause/resume, and local/mounted-folder verification. Bandwidth limiting is planned.
- **Retention Policy** — Automatic cleanup of local originals after verified cloud upload
- **Daily Reports** — Automated daily summary of activity, uploads, and health
- **Timelapse** — Interval-based photo capture compiled into video
- **Multi-User Access** — Role-based web access (admin/operator/viewer)
- **Menu Bar** — Runs in the background with a menu bar icon; quick capture and control panel access
- **Bilingual UI** — Chinese and English, switchable in Settings (web dashboard too)

## Screenshots

> Coming soon

## System Requirements

- macOS 14.0 (Sonoma) or later
- A built-in or external webcam
- Xcode 15+ (for building from source)

## Download

Download the latest `.zip` from [Releases](../../releases).

Unzip and drag `CameraApp.app` to your Applications folder.

> **Note:** This app is not signed or notarized. On first launch, right-click the app and select "Open" to bypass Gatekeeper. See [macOS Gatekeeper help](https://support.apple.com/en-us/HT202491) for details.

## Build from Source

```bash
git clone https://github.com/kairkiss/mac-monitoring-system.git
cd mac-monitoring-system
./build.sh
```

The script uses `xcodebuild archive` to produce a standard `CameraApp.app` and a release zip under `build/release/`.

`build.sh` is a developer build/packaging script — it is not part of the app at runtime. It is used to generate the release `.app` and `.zip` for distribution.

You can also build directly with Xcode or `xcodebuild`:

```bash
xcodebuild -project CameraApp.xcodeproj -scheme CameraApp -configuration Release build
```

## Configure Telegram Bot

1. Create a Telegram Bot via [@BotFather](https://t.me/BotFather) and get the **Bot Token**
2. Find your **Chat ID** (you can use [@userinfobot](https://t.me/userinfobot))
3. In the app, go to **Settings** and enter your Bot Token and Chat ID
4. When creating an automation task, enable "Send to Telegram" for that task

Photos will be sent to your own Telegram chat. No data goes to the developer.

## Automation Tasks

Go to the **Automation** tab to create scheduled tasks:

| Type | Description |
|------|-------------|
| Daily | Capture at a specific time every day |
| Weekly | Capture on selected weekdays |
| Countdown | Capture once after N minutes |
| Interval | Capture every N minutes for a duration |

Enable the global automation toggle in the menu bar or the Automation tab to activate tasks.

## Menu Bar

The app runs in the background with a menu bar icon. From the menu bar you can:

- Toggle automation on/off
- Quick capture a photo
- Open the main control panel
- Quit the app

Closing the main window does not quit the app — it continues running in the menu bar.

## Privacy

- Camera access is required for preview, capture, and recording
- All photos and videos are stored locally on your Mac
- Telegram push is opt-in and uses your own Bot Token
- No analytics, no tracking, no third-party SDKs

See [PRIVACY.md](PRIVACY.md) for full details.

## License

[MIT](LICENSE)
