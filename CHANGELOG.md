# Changelog

All notable changes to **Mac监控系统** will be documented in this file.

## v1.2.1 (2026-05-17)

### New Features

- **Activity Log**: Added a dedicated Activity Log page for reviewing app events, task execution, Telegram status, camera events, motion events, health warnings, and security-related actions.
- **Keychain Token Storage**: Telegram Bot Token is now stored in macOS Keychain instead of UserDefaults.
- **Token Migration**: Existing Telegram Bot Tokens from older versions are automatically migrated from UserDefaults to Keychain.
- **Reliable Capture Callback**: Photo capture now supports completion callbacks that return the newly saved photo URL, allowing automation tasks to send the correct photo to Telegram.
- **Motion Detection**: Added local frame-difference based motion detection with sensitivity, cooldown, capture-on-motion, and Telegram-on-motion settings.
- **Health Monitor**: Added basic health monitoring for low disk space, camera disconnects, and repeated Telegram failures.
- **Local Notifications**: Added local notification support for important warnings and health events.
- **Audio Recording**: Added optional microphone input for video recording.
- **Video Segmentation**: Added optional automatic video segmentation to avoid extremely large recording files.
- **Media Index**: Added a lightweight media metadata index for source tracking, Telegram send status, favorites, and tags.
- **Automation History**: Added execution history tracking for automation tasks.
- **Missed Task Recovery**: Added initial support for recovering missed daily and weekly tasks after app restore or system wake.

### Improvements

- Updated Bundle Identifier from `com.example.MacMonitor` to `com.kairkiss.MacMonitor`.
- Added microphone usage description to `Info.plist` for audio recording.
- Added Activity Log entry points for security, automation, motion, health, and notification categories.
- Added Settings sections for motion detection, health monitor, notifications, missed task recovery, privacy/security, audio recording, and video segmentation.
- Telegram send success can now mark the related media item as sent in the media index.
- Motion-triggered captures are marked with motion source metadata.
- Automation-triggered captures are marked with automation source metadata.

### Fixes

- Fixed a reliability issue where an automation task could send a previous photo to Telegram by reading `lastSavedPhotoPath` too early.
- Improved photo capture error reporting with `CameraCaptureError`.
- Improved Telegram failure tracking through app-level notifications.
- Improved task execution visibility through Activity Log and execution history.

### Known Follow-up Work

- Improve Activity Log internal storage format to standard JSONL.
- Improve motion detection to avoid high-frequency frame processing and reduce false positives.
- Connect frame watchdog health checks to actual video frame receipt.
- Improve missed task recovery by calculating the expected last fire time from task rules.
- Synchronize Media Index cleanup when files are deleted or auto-cleaned.
- Modernize `build.sh` to use the standard Xcode-produced app bundle instead of manually assembling the app bundle.

## v1.1.1 (2026-05-16)

### Stability & Robustness

- Camera session reentrancy guard prevents concurrent configuration conflicts.
- Atomic file writes (temp file + rename) prevent corruption on crash.
- Disk space check before photo/video save.
- Thumbnail loading guards for missing or corrupted files.
- Telegram send auto-retry (up to 2 times) on network failure.
- `isOperational` computed property centralizes status-availability logic.

### UI Polish

- **NavigationSplitView sidebar** replaces TabView, with accent-colored selection capsule and app title.
- **Hidden title bar** for cleaner window chrome.
- **VisualEffectBlur** background on detail view for depth.
- **Status pill badge** on camera view with colored capsule and shadow.
- **Photo card hover** — scale up (1.03x) + deeper shadow on hover.
- **Video card hover** — subtle scale + shadow enhancement.
- **Recording pulse** — animated red dot with expanding pulse ring.
- **Animated empty states** with transition effects.
- **Detail view entrance** — photo fades in with spring scale animation.
- **Video/detail shadow** — floating card effect with rounded corners.
- **Segment switching** — crossfade transition between Photos/Videos.
- **Monospaced storage values** for aligned number display.
- **Settings status animations** — spring transitions for Telegram status.

## v1.1.0 (2026-05-16)

### New Features

- **Photo/Video Export**: Share, Copy, and Export buttons in detail view and context menus.
- **Drag-and-Drop**: Drag photos and videos from library grid to Finder or other apps.
- **Multi-Camera Support**: Camera picker when multiple cameras are connected, with persistent selection.
- **Timestamp Watermark**: Optional timestamp overlay on captured photos, toggleable in Settings.
- **Storage Management**: Storage usage stats, auto-clean old files, and custom storage path.
- **Session Recovery**: Automatic reconnection when camera is disconnected or system wakes from sleep, with exponential backoff.
- **Memory Optimization**: Thumbnail caching with a 50 MB limit and downsampled image loading in detail view.

### Improvements

- Settings UI reorganized with new sections for watermark, storage, and custom path.
- Telegram test status auto-dismisses after 5 seconds.
- Camera list refreshes on app activate and camera connect/disconnect events.
- Exponential backoff (0.5s → 16s) for camera session recovery instead of fixed polling.

## v1.0.1 (2026-05-04)

### Bug Fixes

- Fixed menu bar "Open Control Panel" button not working reliably.
- Window is now hidden instead of destroyed when closed, allowing reliable reopening.
- Window reference is refreshed on each open attempt to handle stale references.

## v1.0.0 (2026-05-04)

Initial release.

### Features

- Real-time camera preview with photo capture and video recording.
- Media library with photo grid and video list, plus batch delete.
- Automation scheduler: daily, weekly, countdown, and interval tasks.
- Per-task Telegram Bot push for sending photos to your own Telegram chat.
- Menu bar background running with quick capture and control panel access.
- Chinese / English bilingual UI.
- Apple-style design with glass effects and spring animations.
- Standalone app with no external dependencies.

### Technical

- macOS 14.0+, Swift 5, SwiftUI + AVFoundation.
- Intel and Apple Silicon Macs.
- App Sandbox disabled for camera and file access.
- Photos and videos saved to `~/Library/Application Support/CameraApp/` by default.
