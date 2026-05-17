# Changelog

## v1.2.2 (2026-05-17)

Maintenance / polish / reliability release. No new features — focuses on stabilizing v1.2.1 additions.

### Fixes & Improvements

- **Activity Log**: Storage format changed from base64-encoded JSON to standard JSONL; backward-compatible reader handles both formats
- **Motion Detection**: Added 1-second analysis interval to reduce CPU usage; replaced pixel-sum comparison with block-based diff algorithm (8x6 grid) to reduce false positives from lighting changes
- **Health Monitor**: Wired `recordFrameReceived()` into camera frame callback; added 30-second frame watchdog with Activity Log warning; added consecutive-failure cooldown to prevent notification spam
- **Notifications**: Created `NotificationManager` to centralize permission requests; notification permission is now only requested when user enables notifications in Settings (not on app launch)
- **Media Index Sync**: `deleteItem()` and `cleanOldFiles()` now sync `MediaIndexStore`; `scanLibrary()` reconciles orphan and missing index entries
- **Missed Task Recovery**: Added `expectedLastFireTime()` calculation based on task rules instead of relying solely on saved `nextFireTime`; daily tasks recover from yesterday if today's time hasn't passed; weekly tasks check correct weekday
- **Telegram Logging**: All send attempts (start, retry, success, failure) now logged to Activity Log; Bot Token redacted from all log output
- **build.sh**: Rewritten to use `xcodebuild archive` output instead of manual bundle assembly; supports optional codesign/notary variables

### Technical

- Version: 1.2.2 (build 6)
- No new files added to Xcode project
- All existing functionality preserved

## v1.2.1 (2026-05-16)

### New Features

- **Video Recording Enhancement**: MM:SS duration display during recording, auto-segmentation (splits recording at configurable duration), optional audio recording with microphone permission
- **Photo/Video Preview Optimization**: Swipe left/right navigation between items, pinch-to-zoom on photos, EXIF information panel (camera make, aperture, ISO, shutter speed, GPS), slideshow mode with configurable interval, bottom navigation bar
- **Automation Task Visualization**: 4-tab layout (Tasks / Timeline / History / Statistics), 24-hour timeline with event dots, execution history list with color-coded status, per-task and overall success rate statistics

### Technical

- MediaItem now includes optional `duration: TimeInterval?` field (backward compatible)
- ExecutionRecord struct and JSON persistence for task execution history
- NSMicrophoneUsageDescription added to Info.plist
- Version: 1.2.1 (build 5)

## v1.2.0 (2026-05-16)

### New Features

- **Activity Log**: JSONL-based logging with search, filter, export, and clear
- **Keychain Storage**: Bot Token stored securely in macOS Keychain instead of UserDefaults
- **Motion Detection**: Frame-diff based motion detection with configurable sensitivity and cooldown; optional auto-capture and Telegram push on motion
- **Health Monitor**: Camera disconnect detection, low disk space alerts, Telegram consecutive failure tracking
- **Local Notifications**: macOS notification support for errors, motion events, and health alerts
- **Media Index Store**: Per-file metadata (favorites, source, Telegram send status) in JSON index
- **Missed Task Recovery**: Configurable recovery window for tasks missed during sleep or app closure
- **Settings Reorganization**: Grouped settings into sections (Telegram, Capture, Automation, Storage, Notifications, Health, Privacy)
- **Activity Log View**: Full log viewer with category icons, search, and export to .jsonl

### Technical

- 6 new Swift files added to project
- Version: 1.2.0 (build 4)

## v1.1.1 (2025-05-16)

### Stability & Robustness

- Camera session reentrancy guard prevents concurrent configuration conflicts
- Atomic file writes (temp file + rename) prevent corruption on crash
- Disk space check before photo/video save
- Thumbnail loading guards for missing or corrupted files
- Telegram send auto-retry (up to 2 times) on network failure
- `isOperational` computed property centralizes status-availability logic

### UI Polish

- **NavigationSplitView sidebar** replaces TabView, with accent-colored selection capsule and app title
- **Hidden title bar** for cleaner window chrome
- **VisualEffectBlur** background on detail view for depth
- **Status pill badge** on camera view with colored capsule and shadow
- **Photo card hover** — scale up (1.03x) + deeper shadow on hover
- **Video card hover** — subtle scale + shadow enhancement
- **Recording pulse** — animated red dot with expanding pulse ring
- **Animated empty states** with transition effects
- **Detail view entrance** — photo fades in with spring scale animation
- **Video/detail shadow** — floating card effect with rounded corners
- **Segment switching** — crossfade transition between Photos/Videos
- **Monospaced storage values** for aligned number display
- **Settings status animations** — spring transitions for Telegram status

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
