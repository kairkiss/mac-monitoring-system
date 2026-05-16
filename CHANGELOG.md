# Changelog

## v1.1.0 (2025-05-16)

### New Features

- **Photo/Video Export**: Share, Copy, and Export buttons in detail view and context menus
- **Drag-and-Drop**: Drag photos and videos from library grid to Finder or other apps
- **Multi-Camera Support**: Camera picker when multiple cameras are connected, with persistent selection
- **Timestamp Watermark**: Optional timestamp overlay on captured photos (toggle in Settings)
- **Storage Management**: Storage usage stats, auto-clean old files, custom storage path
- **Session Recovery**: Automatic reconnection when camera is disconnected or system wakes from sleep, with exponential backoff
- **Memory Optimization**: Thumbnail caching (50MB limit) with downsampled image loading in detail view

### Improvements

- Settings UI reorganized with new sections for watermark, storage, and custom path
- Telegram test status auto-dismisses after 5 seconds
- Camera list refreshes on app activate and camera connect/disconnect events
- Exponential backoff (0.5s → 16s) for camera session recovery instead of fixed polling

## v1.0.1 (2025-05-04)

### Bug Fixes

- Fix menu bar "Open Control Panel" button not working reliably
- Window is now hidden (not destroyed) when closed, allowing reliable reopening
- Window reference is refreshed on each open attempt to handle stale references

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
