# Changelog

## v2.4.0 (2026-05-24)

Productization & Secure Cloud Upload — adds OAuth security hardening, task-level upload control, Cloudflare tunnel management, web responsive design, and settings navigation redesign.

### Security

- **Google OAuth PKCE** — auth flow now uses Proof Key for Code Exchange (S256) to prevent authorization code interception
- **OAuth state parameter** — CSRF protection via random state validation on callback
- **Listener connection validation** — NWListener now validates HTTP requests before accepting; rejects favicon/probe/invalid connections without consuming the OAuth continuation
- **Per-key form encoding** — token exchange body uses per-key/value percent encoding instead of whole-string encoding
- **Better error mapping** — token endpoint errors (access_denied, invalid_client, etc.) are parsed and mapped to specific error types

### New Features

- **Task-level upload control** — automation tasks now have an `uploadToCloud` toggle; only tasks with this enabled auto-upload after capture
- **Manual captures default local-only** — manual photo/video capture never auto-enqueues for upload; only explicit "Upload Now" or task config triggers upload
- **Auto-upload motion captures** — new global setting `autoUploadMotionCaptures` (default off) for motion-triggered photos
- **Cloudflare Tunnel management** — new `CloudflareTunnelManager` with start/stop/status; API routes `/api/remote/status`, `/api/remote/start`, `/api/remote/stop`; auto-start on app launch when configured
- **Web task CRUD** — `POST /api/tasks` (create), `PUT /api/tasks/:id` (update) with all fields including uploadToCloud
- **Web task create/edit forms** — tasks.html now has a modal form for creating and editing tasks with all fields
- **Dashboard Google Drive card** — shows connection status and email
- **Dashboard Last Capture/Upload cards** — shows most recent capture and upload
- **SettingsView NavigationSplitView** — settings now has a sidebar for section navigation
- **Web responsive design** — @media queries for mobile (<768px), hamburger menu, sidebar collapse, touch-friendly 44px buttons
- **UploadDate on verify** — `markUploadVerified` now correctly sets `uploadDate`

### Bug Fixes

- **Upload queue process loop guard** — prevents concurrent `processNext()` calls that could cause duplicate uploads

### Web

- All HTML pages now have hamburger menu for mobile navigation
- tasks.html: task type badges, uploadToCloud badges, edit/delete buttons
- settings.html: Cloudflare tunnel start/stop/status UI
- i18n: all new keys have Chinese and English translations

---

## v2.3.3 (2026-05-24)

Cloud Storage Reliability & Remote Access Polish — enhances Google Drive diagnostics, upload queue intelligence, media cloud badges, retention safety, and Cloudflare guidance.

### New Features

- **Google Drive error classification** — upload failures are classified into categories: auth expired, quota exceeded, rate limited, network unavailable, permission denied. Auth/quota errors fail immediately; rate limits use longer backoff
- **Storage diagnostics** — new `GET /api/storage/diagnostics` endpoint reports connection status, email, quota, upload stats, and error details (no secrets/tokens exposed)
- **Connection test enrichment** — `POST /api/storage/test` now returns email, quota used/total, and error class
- **Upload queue waiting status** — new `waitingForProvider` status preserves jobs when storage provider disconnects; jobs automatically reattach when provider reconnects
- **Media cloud badges** — media library shows cloud and verified badges on grid items and detail view
- **"Open in Google Drive" button** — detail modal links directly to remote file when available
- **Download disabled for archived items** — download button is grayed out when local original is deleted
- **Retention dry run** — new `POST /api/storage/retention/dry-run` endpoint previews what cleanup would delete
- **Retention provider gate** — cleanup skips deletion when cloud provider is disconnected
- **cloudflared detection** — web dashboard detects if cloudflared binary is installed
- **Dashboard waiting count** — upload queue stats show waiting job count
- **Upload verification logging** — successful uploads log remote size and file ID

### Web Dashboard

- **settings.html**: Storage diagnostics card, connection test button, retention dry run preview, cloudflared detection status
- **uploads.html**: `waitingForProvider` status color (orange), error class badge on failed jobs, waiting count in stats bar
- **media.html**: Cloud/verified badges on grid items, "Open in Google Drive" button in detail modal, disabled download for archived items
- **index.html**: Upload queue shows waiting count

### Technical

- Version: 2.3.3
- Build: 18
- `GoogleDriveAPIError` enum with 6 error cases and `classifyGoogleDriveError()` function
- `StorageDiagnostics` struct with 13 fields
- `testConnectionDetailed()` protocol method on `StorageProvider`
- `RetentionDryRunResult` struct and `dryRun()` method
- `UploadJobStatus.waitingForProvider` and `UploadEntryStatus.waitingForProvider` cases
- `UploadJob.errorClass` field for storing error classification
- `UploadQueueManager.reattachWaitingJobs()` for provider reconnection
- `APIStatusHandler` now returns `waiting` count in upload queue stats
- No data migration required
- No existing user data is deleted

## v2.3.2 (2026-05-24)

Google Drive Crash Hotfix — fixes crashes when selecting, configuring, or signing into Google Drive storage provider. Hardens OAuth flow, provider activation, and upload queue against all failure modes.

### Fixes

- **Fixed crash when selecting Google Drive provider** — StorageManager now safely validates credentials and authentication state before creating GoogleDriveProvider
- **Fixed crash during OAuth sign-in** — ASWebAuthenticationSession is now created and started on the main thread; NWListener callback and session callback use thread-safe single-resume guard to prevent double continuation resume
- **Fixed crash on OAuth cancellation** — all cancellation paths now safely resume continuation with user-readable error
- **Fixed crash when credentials are missing** — GoogleDriveProvider returns clear errors instead of force-unwrapping URLs
- **Fixed crash when local file is missing** — UploadQueueManager verifies file existence before upload attempt
- **Added import AppKit** — explicit import for NSApplication/ASPresentationAnchor access
- **Hardened GoogleDriveProvider** — removed all force unwraps, added credential guards, safe FileHandle operations
- **Hardened StorageManager** — validates credentials and authentication before creating provider; shows clear status messages
- **Hardened UploadQueueManager** — passes providerType and remotePath to MediaIndex after verified upload; logs warning when queue has jobs but no provider
- **Wrote providerType and remotePath to MediaIndex** — markUploadVerified now persists providerType and actual remotePath
- **Updated stale WebDAV copy** — removed version reference from planned provider message
- **Sign-in button disabled while authenticating** — prevents double-click crashes

### Technical

- Version: 2.3.2
- Build: 17
- No data migration required
- No existing user data is deleted
- New ContinuationGuard class with NSLock for thread-safe OAuth callbacks
- MediaIndexStore.markUploadVerified gains `remotePath` parameter
- StorageManager gains `lastError` property
- GoogleDriveError gains `.notConfigured`, `.notAuthenticated`, `.fileNotFound` cases
- GoogleDriveAuthError gains `.listenerFailed` case

## v2.3.1 (2026-05-24)

Google Drive OAuth & Safety Hotfix — fixes OAuth callback, secures credentials, prevents remote file overwrites, improves folder/path tracking.

### Fixes

- **Fixed Google OAuth callback** — replaced placeholder URL scheme with loopback HTTP listener (http://127.0.0.1:randomPort); OAuth flow now works with real Google API credentials
- **Moved Client Secret to Keychain** — no longer stored in UserDefaults; read/written only via KeychainService
- **No-remote-overwrite** — Google Drive uploads now generate unique filenames (timestamp suffix) when a same-name file already exists; never PATCHes/overwrites existing remote files
- **Fixed date-dependent remote paths** — folder structure is now `RootFolder/category/filename` (no year/month/day), so files are findable across days
- **Added providerType to MediaIndex** — upload records now include explicit provider type for future lookups
- **Root Folder Name UX** — users now set a folder name (e.g. "MacMonitor") instead of a cryptic folder ID; ID is cached internally
- **Needs Reconnect state** — when Google Drive token refresh fails, UI shows "Needs Reconnect" instead of silent failure
- **Better error messages** — OAuth errors, API errors (401, 403, 429) now produce human-readable explanations
- **Secure API responses** — /api/storage/status no longer exposes tokens or secrets; shows googleDriveConnected, email, needsReconnect, rootFolderName
- **Cloudflare wizard improvements** — added security notes, local URL display, "do not expose port" warning

### Technical

- Version: 2.3.1
- Build: 16
- No data migration required
- No existing user data is deleted
- Client Secret moved from UserDefaults to Keychain (account: googleDriveClientSecret)
- New Keychain account: googleDriveClientSecret
- New SettingsStore property: googleDriveRootFolderName (replaces googleDriveFolderID for user-facing config)
- MediaIndexEntry gained `providerType: String?` field

## v2.3.0 (2026-05-22)

Google Drive Cloud Storage + Cloudflare Public Access Wizard.

### New Features

- **Google Drive Provider** — Real Google Drive API integration with OAuth 2.0 login (ASWebAuthenticationSession), resumable chunked upload (8MB chunks), automatic folder creation (MacMonitor/YYYY/MM/DD/category/), post-upload file verification, and file management (delete, exists)
- **Google Drive OAuth** — Access token + refresh token stored securely in macOS Keychain; automatic token refresh when expired; user email display
- **Cloudflare Tunnel Wizard** — 5-step interactive setup guide in macOS Settings with copy-to-clipboard commands; covers cloudflared install, login, tunnel creation, DNS routing, and start
- **Web Remote Access Section** — Cloudflare Tunnel setup wizard on web Settings page with step-by-step commands and double-protection info (Cloudflare Access + App Login)
- **Google Drive Settings UI** — Sign in/out, Client ID/Secret configuration, root folder ID, folder structure preview, connection test in macOS Settings
- **Web Storage Providers** — Storage provider list now shows Google Drive as available when authenticated, with user email detail; WebDAV remains planned

### Technical

- Version: 2.3.0
- Build: 15
- New files: `GoogleDriveAuthManager.swift`, `GoogleDriveProvider.swift`
- Modified: `KeychainService.swift` (5 new accounts), `SettingsStore.swift` (2 new properties), `StorageManager.swift`, `APIStorageHandler.swift`, `SettingsView.swift`, `settings.html`, `i18n.js`, `style.css`, `Strings.swift`
- Google Drive tokens stored in Keychain (never exposed to Web UI or logs)
- No data migration required
- No existing user data is deleted

## v2.2.1 (2026-05-22)

Range & Polish Hotfix — fixes HTTP Range parsing, enhances upload queue display, improves Settings feedback.

### Fixes

- **Fixed HTTP Range parsing** — `bytes=0-` and `bytes=-500` now correctly parsed using `split(separator: "-", omittingEmptySubsequences: false)`
- Added `parseRange()` helper with full validation: open ranges, suffix ranges, explicit ranges, invalid range rejection
- Added 413 Payload Too Large status text to HTTPResponse
- Upload Queue API now returns `nextRetryAt`, `retryDelaySeconds`, `lastAttemptAt`, `progress`, `completedAt`, `fileSize`, `maxRetries`
- Upload Queue API returns additional counts: `retryingCount`, `uploadingCount`, `completedCount`
- Upload Queue Web UI shows progress bar, retry countdown, attempts/max display
- macOS Settings now shows success/failure feedback for Web username and password changes (not just print)
- Added missing i18n keys: progress, retrying, completed, cancelled, retryDelay, file, save, and more

### Technical

- Version: 2.2.1
- Build: 14
- No data migration required
- No existing user data is deleted

## v2.2.0 (2026-05-22)

Web Console Maturity Release — bilingual Web UI, customizable credentials, Range support, upload backoff.

### New Features

- **Web UI bilingual support** — Chinese / English with language switcher in Web Settings; auto-detects browser language
- **Customizable Web admin username and password** — change via macOS Settings or Web Settings page; all sessions invalidated on change
- **HTTP Range support** — `GET /api/media/:id/file` supports `bytes=start-end`, `bytes=start-`, `bytes=-suffix` for large media downloads
- **UploadQueue retry backoff** — exponential delay (10s, 20s, 40s... max 300s) between retries; respects `nextRetryAt`; manual retry bypasses delay
- **Web Settings page** — change password, change username (admin), language switcher
- **Web login improvements** — i18n support, clearer error messages, token expiry redirect

### Fixes

- Included web server static resource path fix for nested Resources/Web bundle (from v2.1.1 hotfix on main)
- Fixed HTTPConnection lifecycle retention and initial read race (from v2.1.1 hotfix on main)
- Improved Web Server connectivity and login usability
- Improved docs accuracy around planned Google Drive/WebDAV providers

### Technical

- Version: 2.2.0
- Build: 13
- No data migration required except optional web user credential update
- No existing media/task/upload data is deleted
- New files: `Resources/Web/js/i18n.js`
- Modified: `WebAuthManager.swift`, `APIAuthHandler.swift`, `HTTPRequest.swift`, `HTTPResponse.swift`, `APIMediaHandler.swift`, `UploadJob.swift`, `UploadQueueManager.swift`, `UploadQueueStore.swift`, `SettingsView.swift`, all 9 HTML pages, `js/app.js`

## v2.1.1 (2026-05-22)

Web Media Auth Hotfix — fixes 401 errors on thumbnails, previews, and downloads; fixes critical web server connectivity issues.

### Fixes

- **Fixed web server not serving static files** — Resources folder was nested as `Resources/Resources/Web/` in app bundle; server now checks both paths
- **Fixed HTTPConnection race condition** — `readData()` now called directly after `connection.start()` to handle connections that reach `.ready` before `stateUpdateHandler` fires
- **Fixed HTTPConnection premature deallocation** — Added `selfRef` self-reference to prevent ARC from releasing connection objects before async handlers complete
- Fixed Web Media Library thumbnails failing with 401 (now uses fetch + Authorization header)
- Fixed media detail preview failing with 401 (now uses fetch + Authorization header)
- Fixed media download to use authenticated fetch instead of insecure token query string
- Added large-file guard for web media file endpoint (> 200MB returns 413)
- Improved Content-Type detection for media file downloads
- Added Retention "Run Cleanup Now" button in Settings
- Retention cleanup now also protects `protected` items
- Fixed login page hardcoded version string
- Added web admin password display and reset UI in Settings
- Corrected README wording: upload bandwidth limiting is planned, not implemented

### Technical

- Version: 2.1.1
- Build: 12
- No data migration required
- No existing user data is deleted

## v2.1.0 (2026-05-21)

Web Usability Release — makes web features truly usable with real camera snapshots, complete media library, and improved upload chain.

### New Features

- **Live View Snapshot**: Real JPEG camera snapshot displayed in web Live View, auto-refreshing every 2 seconds (slows to 5s on blur or errors)
- **Full Web Media Library**: Thumbnail grid with search, filters (type/source/upload status/favorites), pagination, detail modal with download, delete, upload, favorite, protect actions; archived entries shown with badge
- **Date-Based Upload Organization**: Local/Mounted Folder uploads now organize files into `MacMonitor/YYYY/MM/DD/photos|videos/` directory structure
- **Post-Upload Verification**: Upload verification checks file existence and size match after copy; fails upload if verification fails
- **Enhanced Dashboard**: Camera status with recording indicator, storage provider, upload queue stats (pending/active/failed), health alerts, version/build display
- **Thumbnail Generator**: On-demand thumbnail generation from photos and video first frames, cached in Thumbnails directory
- **Health Alerts in API**: `/api/health` endpoint now includes unresolved alerts inline

### Improvements

- UploadQueueManager stores file size in completed jobs
- APIStatusHandler returns recording status and detailed upload queue stats
- LocalFolderProvider and MountedFolderProvider now use distinct types
- UploadJob includes optional fileSize field

### Technical

- Version: 2.1.0
- Build: 11
- No data migration required
- No existing user data is deleted

## v2.0.2 (2026-05-21)

Micro Hotfix for v2.0.1 residual issues.

### Fixes

- Fixed non-optional `activeCameraName` nil-coalescing compile risk across API handlers
- Fixed `/api/status` version/build hardcoding — now reads from Info.plist at runtime
- Fixed RetentionManager to only call `markLocalDeleted` after successful local file deletion
- Fixed UploadQueueManager to respect `isPaused` state before processing jobs
- Added basic Storage Provider settings UI with provider picker, folder selection, and test connection
- Clarified Google Drive and WebDAV as planned providers (not fully implemented)
- Updated Live View to honestly state live snapshot is not available in v2.0.2
- Updated README and CHANGELOG for accuracy

### Technical

- Version: 2.0.2
- Build: 10
- No data migration required
- No existing user data is deleted

## v2.0.1 (2026-05-21)

Hotfix for v2.0.0 critical issues.

Major release. Transforms the local camera tool into a Mac-resident camera node with web dashboard, storage providers, upload queue, cloud archival, and automated retention.

### New Features

- **Local Web Server**: NWListener-based HTTP server on 127.0.0.1:8765 (disabled by default); token authentication with role-based access (admin/operator/viewer); audit logging for all web operations
- **Web Dashboard**: Responsive HTML/CSS/JS dashboard with live camera view, media library, automation management, upload queue, health monitoring, and settings
- **REST API**: Full API for camera control, media management, task CRUD, activity logs, health status, and upload queue operations
- **StorageProvider Abstraction**: Protocol-based storage backend system; supports Local Folder, Mounted Folder, Google Drive (OAuth + resumable upload), and WebDAV
- **Upload Queue**: Persistent upload queue with retry, exponential backoff, progress tracking, and bandwidth limiting
- **Retention Manager**: Automatic deletion of local originals after verified upload; configurable grace period; protects favorites and recent files
- **Event Recording**: Motion-triggered short video clips with configurable duration
- **Daily Report**: Automated daily summary of captures, uploads, alerts, and storage usage
- **Timelapse**: Interval-based photo capture with AVAssetWriter video compilation
- **Multi-User Web Access**: Three roles (admin, operator, viewer) with granular permissions
- **Cloudflare Tunnel Guide**: Documentation for secure remote access via Cloudflare Tunnel + Cloudflare Access

### Technical

- Version: 2.0.0 (build 8)
- ~40 new Swift files across WebServer/, Storage/, Upload/, Features/, Settings/ directories
- Embedded web assets in Resources/Web/
- Added NSLocalNetworkUsageDescription to Info.plist
- Extended MediaIndexEntry with upload tracking fields (backward compatible)
- Extended KeychainService with web auth, WebDAV, and Google Drive token storage
- Extended LogCategory and HealthAlertType with new cases
- All v1.2.3 data formats backward compatible

## v1.2.3 (2026-05-19)

Final v1.2 stability release. Resolves residual issues from v1.2.2, refactors multi-camera selection to respect user preference, and improves motion detection and automation reliability.

### Fixes & Improvements

- **Notification Permission**: Removed automatic permission request on app launch; permission is now only requested when user enables notifications in Settings
- **Health Monitor Toggle**: Enabling/disabling Health Monitor in Settings now immediately starts/stops monitoring without requiring app restart
- **Telegram Logging**: "No response" failure branch now properly logged to Activity Log
- **Multi-Camera Selection**: Refactored camera switching logic — user-selected camera is now preserved as "preferred"; when disconnected, app uses fallback camera but restores preferred camera when it becomes available again; new camera connections no longer auto-switch away from user's choice
- **Motion Detection**: Cooldown timer no longer blocks brightness baseline updates; motion analysis continues during cooldown to prevent stale reference frames
- **Missed Task Recovery**: Added `lastAttemptAt` tracking to scheduled tasks for better recovery diagnostics
- **CHANGELOG**: Fixed inaccurate "No new files" note in v1.2.2 entry

### Technical

- Version: 1.2.3 (build 7)
- No new files added to Xcode project
- All existing functionality preserved

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
- 1 new file added: `NotificationManager.swift`
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
