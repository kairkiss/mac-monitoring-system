# Changelog

## v1.0.0 (2025-05-04)

Initial release.

### Features

- Real-time camera preview with photo capture and video recording
- Media library with photo grid and video list, batch delete
- Automation scheduler: daily, weekly, countdown, and interval tasks
- Per-task Telegram Bot push (photos sent to your own Telegram chat)
- Menu bar background running with quick capture and control panel
- Chinese / English bilingual UI
- Apple-style design with glass effects and spring animations
- Standalone app, no external dependencies

### Technical

- macOS 14.0+, Swift 5.0, SwiftUI + AVFoundation
- Intel and Apple Silicon Macs
- App Sandbox disabled (required for camera and file access)
- Photos and videos saved to `~/Library/Application Support/CameraApp/`
