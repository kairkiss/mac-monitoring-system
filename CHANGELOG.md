# Changelog

## v2.5.2 (2026-05-27)

Google Drive Integration Reliability & Diagnostics — productized Google Drive connection state model, added 6 dedicated API endpoints, enhanced Storage Center with Drive detail card, improved Uploads page error descriptions with next-action hints, and added Google Drive state-aware dashboard alerts.

### Added

- **GoogleDriveConnectionState enum** — `.connected`, `.needsReconnect`, `.notAuthenticated`, `.credentialsMissing`, `.quotaExceeded`, `.error` with `isUsable` computed property
- **GoogleDriveAPIError enhancements** — 4 new cases: `credentialsMissing`, `notAuthenticated`, `rootFolderMissing`, `verificationFailed`. Added `isRetryable` and `nextAction` computed properties for user-facing guidance
- **StorageDiagnostics.connectionState** — new optional `connectionState` field returned by all storage diagnostics paths
- **6 new API endpoints**:
  - `GET /api/storage/google-drive/status` — connection state, email, credentials status, root folder, upload queue stats, quota
  - `POST /api/storage/google-drive/test` (operator+) — dedicated test with errorDescription, nextAction, isRetryable
  - `POST /api/storage/google-drive/reconnect` (operator+) — triggers OAuth flow asynchronously
  - `POST /api/storage/google-drive/sign-out` (admin-only) — clears tokens, reconfigures storage
  - `POST /api/storage/google-drive/retry-waiting` (operator+) — reactivates waitingForProvider jobs
  - `GET /api/storage/google-drive/root` — root folder name, folder ID, auth status
- **Storage Center Google Drive Detail Card** — connection state badge, account email, storage quota with progress bar, root folder, upload queue stats, action buttons (Test/Reconnect/Retry Waiting/Sign Out), next-action hints for error states
- **Uploads page error enrichment** — error descriptions now include `{desc, nextAction, retryable}` objects; new error classes: `credentialsMissing`, `notAuthenticated`, `rootFolderMissing`, `verificationFailed`; provider banner shows state-specific messages
- **Dashboard Google Drive alerts** — `updateAttentionSection()` shows credentialsMissing/needsReconnect/quotaExceeded alerts; storage status card shows connection state colors; status strip shows state-specific dot colors
- **i18n keys** — ~20 new bilingual keys (en/zh): `gdConnectionState`, `gdEmail`, `gdRootFolder`, `gdUploadStats`, `gdNextAction`, `gdSignOut`, `gdSignOutConfirm`, `gdReconnectPrompt`, `gdCredentialsMissing`, `gdQuotaWarning`, `uploadWaitingCount`, `uploadFailedCount`, `errorCredentialsMissing`, `errorNotAuthenticated`, `errorRootFolderMissing`, `errorVerificationFailed`

### Fixed

- **UploadQueueManager switch exhaustiveness** — updated error handling in `processNext()` to cover all `GoogleDriveAPIError` cases: auth/credential errors → `.failed` (no retry), quota/root → `.failed`, rate limited → retry with longer backoff, network/unknown/verification → standard retry

### Preserved

- v2.5.0/v2.5.1 Web UI componentization, role-aware controls, polling, Telegram WebView
- Google Drive OAuth PKCE/state, CloudflareTunnelManager state machine
- UploadQueue core logic, Retention verified-only, manual captures local-only
- No Telegram bot commands, inline keyboards, or native buttons

---

## v2.5.1 (2026-05-26)

Media Permission & Batch Action Hotfix — fixed media delete backend permissions, batch protect/unprotect/favorite using explicit set instead of toggle, media API role alignment, dashboard Google Drive provider compatibility, and media page i18n cleanup.

### Fixed

- **Media delete now admin-only** — `DELETE /api/media/:id` backend `requiredRole` changed from `.operatorRole` to `.admin`. Operators can no longer delete media via direct API calls
- **Batch Protect/Unprotect uses explicit set** — batch operations now send `{protected: true/false}` body to API instead of relying on toggle. Protect selected guarantees all become protected; Unprotect selected guarantees all become unprotected
- **Batch Favorite uses explicit set** — batch favorite now sends `{isFavorite: true}` body. Already-favorited items are not accidentally unfavorite
- **Protect/Favorite API role enforcement** — `POST /api/media/:id/protect` and `POST /api/media/:id/favorite` now require `operatorRole`. Viewer can no longer toggle protection or favorites
- **Protect/Favorite API supports body parameter** — both endpoints accept optional JSON body `{protected: bool}` / `{isFavorite: bool}` for explicit set, with fallback to toggle for single-item detail page
- **Dashboard Google Drive provider compatibility** — dashboard now recognizes `gdrive`, `googleDrive`, and `google_drive` as Google Drive provider values. Provider display name normalized to "Google Drive"
- **Media page i18n cleanup** — batch operation buttons, selection count, confirmation dialog, placeholder text, and toast messages now use i18n keys instead of hardcoded English
- **API error status propagation** — `api()` function in app.js now includes HTTP status code on thrown errors, enabling 403 permission detection in batch operations
- **Batch operation error feedback** — 403 errors now show "Insufficient permissions" toast instead of silent failure. Success/failure counts displayed per batch operation

### Added

- **Audit logging** — `POST /api/media/:id/upload`, `POST /api/media/:id/favorite`, `POST /api/media/:id/protect` now write to audit log
- **MediaIndexStore.setFavorite** — new explicit `setFavorite(_:for:)` method alongside existing `toggleFavorite`
- **i18n keys** — 12 new keys: `batchProtected`, `batchUnprotected`, `batchFavorited`, `batchQueued`, `batchDeleted`, `batchFailed`, `mediaVideo`, `mediaArchived`, `mediaLocalMissing`, `mediaLargeFile`, `mediaPhotoUnavailable`

### Preserved

- v2.5.0 Web UI componentization, role-aware controls, polling, Telegram WebView
- Google Drive OAuth, CloudflareTunnelManager, UploadQueue, Retention
- Manual captures local-only, no Telegram bot commands

---

## v2.5.0 (2026-05-26)

Web Console Productization & Telegram Mini App Foundation — componentized Web UI with reusable CSS classes, role-aware frontend controls, unified polling/state management, Telegram WebView theme/safe-area adaptation, and productized Remote/Storage/Media/Uploads/Dashboard pages. Filled audit logging gaps across all API handlers.

### Added

- **CSS componentization** — 20+ reusable utility classes extracted from inline styles: `.section-heading`, `.action-row`, `.status-panel`, `.metric-card`, `.form-grid`, `.empty-state`, `.danger-card`, `.modal-section`, `.filter-bar`, `.selection-bar`, `.select-check`, action tile color modifiers, role badge variants
- **Role-aware Web UI** — `data-role-min` attribute on HTML elements, `applyRoleVisibility()` in app.js hides/disables elements based on viewer/operator/admin hierarchy. Frontend is UX-only; backend `requiredRole` remains the security boundary
- **Unified polling** — `createPoller()` in app.js with visibility-pause (Page Visibility API), error backoff (double interval on consecutive failures, max 60s), and dedup. Replaces scattered `setInterval` calls on Dashboard
- **Global utilities** — `dot()`, `debounce()`, `setPageTitle()`, `getRole()`, `isAdmin()`, `isOperatorOrAdmin()` moved to app.js global scope, removed duplicates from individual pages
- **Telegram WebView enhancement** — detects `Telegram.WebApp.colorScheme` for dark/light theme, reads `themeParams` as CSS custom properties (`--tg-bg`, `--tg-text`, `--tg-accent`), applies `safeAreaInset` as CSS variables. No bot commands, inline keyboards, or native buttons
- **Remote page productization** — structured status panel (Mode/Status/Public URL/Local URL/PID/Last Error/Last Updated), three action groups (Safe: operator+, Recovery: admin, Config: admin), live logs capped at 50 lines with Clear button
- **Storage Center productization** — storage overview grid (provider/used/disk/queue/GDrive status), enhanced provider cards with status badges and Google Drive details, structured test connection results, retention preview with dry-run notice
- **Media selection mode** — Select toggle (operator+), checkbox overlays on media items, Select All/Deselect All, batch operations: Protect/Unprotect/Favorite/Upload (operator+), Delete (admin-only with confirmation modal)
- **Upload Queue recovery** — filter chips (All/Pending/Waiting/Uploading/Retrying/Failed/Completed) with counts, error grouping by `errorClass` when filtered to Failed, Retry All Failed and Pause/Resume Queue (operator+), Google Drive not-connected banner for waiting jobs
- **Dashboard improvements** — compact status strip (Camera/Remote/Storage/Uploads/Health with clickable indicators), Attention Needed section aggregating alerts across subsystems, role-based quick actions (viewer: Live/Media; operator: +Capture/Record; admin: +Remote/Storage/Audit)
- **Audit logging** — 16 explicit `AuditLogManager.shared.log()` calls added across 6 API handlers: user CRUD, role changes, password resets, media deletion, task CRUD/toggle, log clearing, tunnel settings, upload queue operations
- **i18n** — 41 new bilingual keys (en/zh) for role messages, Remote/Storage/Media/Uploads/Dashboard/Telegram features; 15 duplicate keys removed

### Preserved

- v2.4.13 dark glassmorphism UI, desktop sidebar, mobile tabbar, More Sheet
- Google Drive OAuth PKCE/state, CloudflareTunnelManager state machine
- UploadQueue core logic, Retention verified-only, manual captures local-only
- Multi-camera logic, Telegram photo/text notifications
- No npm/build tools introduced, no React/Vue/Svelte

---

## v2.4.13 (2026-05-25)

Web API Alignment Final Hotfix — aligned Web Remote and Storage pages with backend API field names. Added missing tunnel controls to Web. Added write-config confirmation. Improved bilingual coverage for Remote and Storage pages.

### Fixed

- **Remote: Added Restart / Force Stop / Reset Status / Refresh Status buttons** — Web Remote Access page now has full tunnel control parity with the macOS app
- **Remote: Fixed config preview** — generate-config field mapping (`content` vs `config`) now works correctly
- **Remote: Added write-config confirmation modal** — sensitive config write operation now requires user confirmation
- **Remote: Fixed status display** — now correctly shows starting/stopping/restarting/error states, not just running/stopped
- **Remote: Fixed hardcoded English** — buttons and labels now use i18n keys
- **Storage: Fixed provider field mapping** — correctly reads `isActive`/`isAvailable`/`isPlanned`/`detail` from backend
- **Storage: Fixed test connection route** — uses `/api/storage/test` (with fallback to `/api/storage/test-connection`)
- **Storage: Fixed test connection response parsing** — reads `connected`/`error`/`quotaUsedGB` instead of `success`/`message`
- **Storage: Fixed retention dry-run display** — reads `wouldDelete`/`skipped`/`files`/`reason` instead of `deletedFilesCount`/`freedBytes`/`details`
- **Storage: Fixed hardcoded English** — section headers and labels now use i18n keys

### Added

- **Backend: POST /api/remote/force-stop** — admin-only endpoint calling `CloudflareTunnelManager.shared.forceStop()`
- **Backend: POST /api/remote/reset-status** — admin-only endpoint calling `CloudflareTunnelManager.shared.reconcileStatus()`
- **Backend: POST /api/storage/test-connection** — compat alias for `/api/storage/test`
- **Backend: Compat fields** — generate-config returns both `content` and `config`; providers return `isCurrent`/`isConnected`/`email`/`needsReconnect` alongside native fields; retention dry-run returns both old and new field names
- **i18n: 20+ new keys** for Remote and Storage pages (en/zh)

### Preserved

- v2.4.12 dark glassmorphism UI, desktop sidebar, mobile tabbar, More Sheet
- Telegram WebView rendering fixes and cache busting
- Dashboard hero panel, status cards, Quick Actions
- Media thumbnail fallback, detail modal
- Tasks CRUD, uploadProvider, videoDurationSeconds
- Google Drive OAuth PKCE, CloudflareTunnelManager state machine
- Manual captures local-only, retention verified-only

---

## v2.4.12 (2026-05-25)

Web Optional API & Thumbnail Fallback Hotfix:
- Fixed Not Found toast still appearing on Web Dashboard load.
- Switched optional dashboard remote status checks to silent optional API calls.
- Prevented remote status polling from showing disruptive Not Found toasts.
- Fixed media library photo previews by falling back from /thumbnail to /file.
- Added safer placeholders for video, archived, local-missing, and large photo items.
- Preserved Telegram WebView rendering fixes and v2.4.9+ UI redesign.

## v2.4.11 (2026-05-25)

Web API Route & Media Thumbnail Hotfix:
- Fixed Not Found toast appearing when opening the Web Dashboard.
- Aligned Web Remote/Cloudflare frontend calls with available backend routes.
- Made optional dashboard/remote status requests silent and non-disruptive.
- Fixed media library thumbnails failing when /thumbnail is unavailable.
- Added photo thumbnail fallback to /file.
- Added safer video/archived/local-missing placeholders.
- Preserved Telegram WebView rendering fixes from v2.4.10.

## v2.4.10 (2026-05-25)

Telegram WebView Cache Busting Hotfix:
- Fixed Telegram WebView loading stale CSS/JS/i18n assets after Web UI redesign.
- Added version query parameters (?v=2.4.10) to all Web CSS and JS resource references.
- Prevented raw i18n keys such as systemNormal/openLive from appearing in Telegram WebView.
- Added Web UI version diagnostics for Telegram WebView troubleshooting.
- Preserved v2.4.9 Telegram Mini App UI redesign.

## v2.4.9 (2026-05-25)

Telegram Mini App UX Redesign:
- Redesigned Web Console around Telegram Mini App / mobile-first usage.
- Added dedicated Remote Access page.
- Added dedicated Storage Center page.
- Simplified Settings page.
- Improved mobile Dashboard/Home experience.
- Improved Live, Media, Tasks, Uploads mobile layouts.
- Added Remote and Storage entries to mobile More sheet.
- Expanded bilingual i18n coverage.
- Reduced inline styles and unified UI components.
- Preserved existing backend APIs and business logic.

## v2.4.8 (2026-05-25)

- Added Dark theme and Glassmorphism styling.
- Introduced Mobile Bottom Tab Navigation and More Sheet.
- Partial cardification of UI elements.

## v2.4.7 (2026-05-25)

Cloudflare State Machine Hotfix — fixed status getting permanently stuck in "starting" or "stopping" after tunnel start/stop. The Restart button is no longer permanently disabled. Added Force Stop and Reset Status emergency buttons.

### Fixed

- **Fixed status stuck in starting** — `terminationHandler` now handles `.stopping` state and intent flags (`isUserStopping`, `isRestartingFlow`) to distinguish user action from unexpected process exit
- **Fixed status stuck in stopping** — stop timeout (8s) auto-calls `forceStop()` if the process doesn't exit cleanly
- **Expanded running detection** — recognizes 7 log signals (was 2): "Registered connection", "Connection registered", "connIndex", "Starting tunnel", "Tunnel started", "INF Connection registered", plus quick tunnel URLs on both stdout and stderr
- **Startup timeout fallback** — if process is alive after 10s but no running signal detected, assumes running
- **Fixed Restart permanently disabled** — Restart is now only disabled when `.restarting`, not when `.starting` or `.stopping`
- **Added Force Stop button** — appears when status is busy or error; kills process and resets to stopped
- **Added Reset Status button** — calls `reconcileStatus()` to check real process state and correct the UI
- **Prevent duplicate processes** — `startTunnel()` kills any existing process before launching a new one
- **`reconcileStatus()` method** — checks actual process state vs UI status; fixes stale status on refresh
- **`forceStop()` method** — kills process with terminate→interrupt escalation, clears all state
- **Intent flags** — `isUserStopping` and `isRestartingFlow` flags prevent terminationHandler from misinterpreting a user-initiated stop as a crash
- **Timeout cancellation** — startup/stop timeouts are cancelled when terminationHandler fires, preventing stale timeout actions

### Added

- Force Stop and Reset Status emergency buttons in CloudflareControlPanelView (appear when status is busy or error)
- `reconcileStatus()` called automatically on every `refreshStatus()` call

---

## v2.4.6 (2026-05-25)

Web Settings Crash Hotfix — fixed crash when opening Settings → Web & Remote Access. Extracted Cloudflare panel into standalone view with all force unwraps removed and async-safe status refresh.

### Fixed

- **Fixed crash on Web & Remote Access** — removed unsafe force unwraps (`URL(string:)!`, `tunnel.pid!`, `result.backupPath!`) that caused the crash
- **Extracted CloudflareControlPanelView** — Cloudflare panel is now a standalone view, reducing SettingsView complexity and isolating crash scope
- **Async-safe status refresh** — `refreshStatus()` now runs `detectCloudflared()` and `setupStatus()` on a background thread via `Task.detached`, preventing main-thread blocking
- **Safe URL rendering** — Public URL uses `if let safeURL = URL(string: url)` instead of force unwrap; invalid hostnames show as text instead of crashing
- **Safe PID display** — Uses `if let pid = tunnel.pid` instead of `tunnel.pid!`
- **Safe backup path** — Write Config result uses `if let backup = result.backupPath` instead of force unwrap
- **Hostname normalization** — Handles hostnames with `https://` prefix gracefully

### Preserved

- All visible Cloudflare buttons: Start Quick/Named, Stop, Restart, Refresh
- Copy Public URL, Generate/Copy/Write Config
- Config fields in collapsible DisclosureGroup
- Google Drive, automation, upload queue, retention

---

## v2.4.5 (2026-05-25)

Visible Cloudflare Buttons Hotfix — restructured Cloudflare Control Panel so all buttons are immediately visible at the top of the section, not buried under config fields.

### Fixed

- **Buttons now visible at top** — Cloudflare Control Panel restructured: Start Quick/Named, Stop, Restart, Refresh buttons appear right after the status badge
- **Restart Tunnel works when stopped** — Restart button is now enabled when tunnel is stopped (was incorrectly disabled)
- **Config fields collapsed** — Tunnel name, hostname, credentials, config actions moved into a collapsible "Configuration" DisclosureGroup so they don't push buttons below the fold
- **Start buttons show both modes** — Both Quick and Named start buttons are always visible (previously only showed the selected mode's button)
- **Prominent button styling** — Start Quick (blue), Start Named (purple), Restart (orange) with `.borderedProminent` style for high visibility
- **Public URL hint** — Shows "Start Quick Tunnel to get a public URL" when in quick mode and tunnel is stopped

### What v2.4.4 had (preserved)

- CloudflareTunnelManager with startTunnel/stopTunnel/restartTunnel
- State-driven setup hints
- Config generation, preview, copy, write with backup
- Web API /api/remote/* endpoints
- Bilingual UI (Chinese/English)

---

## v2.4.4 (2026-05-25)

App Cloudflare Control Panel Hotfix — macOS App now has full Cloudflare Tunnel control with Start/Stop/Restart buttons, state-driven setup hints, and config management.

### New Features

- **macOS App Cloudflare Control Panel** — Settings → Web & Remote → full tunnel control: status badge, mode picker, Start Quick/Named, Stop, Restart, Refresh Status
- **Restart Tunnel button** — `restartTunnel()` with proper stop-wait-start sequencing, `restarting` status, duplicate-click prevention
- **Public URL copy** — Quick mode copies `quickTunnelURL`, Named mode copies `https://hostname`
- **Config management in App** — Generate Config Preview, Copy Config, Write Config (with confirmation alert and automatic backup)
- **Open Config Folder** — one-click open `~/.cloudflared` in Finder
- **State-driven setup hints** — shows exactly what's missing (install, login, tunnel name, hostname, config, credentials, port mismatch)
- **`/api/remote/restart`** — new admin-only Web API endpoint with AuditLog

### Fixed

- Removed misleading `cloudflared tunnel run --url ... <name>` command from setup wizard
- Cloudflare UI now uses `@ObservedObject` on `CloudflareTunnelManager.shared` for live status updates
- `TunnelStatus.restarting` added to prevent duplicate restart clicks

---

## v2.4.3 (2026-05-24)

Cloudflare Setup Wizard & Task API Fix — state-driven Cloudflare first-time setup, task API correctness, lossy task loading, upload provider unification.

### New Features

- **Cloudflare Setup Wizard** — state-driven setup status (12 states from `notInstalled` to `running`); shows exactly what's missing with copy-paste commands; one-click config.yml generation, preview, and write-with-backup
- **Cloudflare config.yml parser** — line-by-line parser for tunnel, credentials-file, ingress hostname/service; validates service port matches web server port
- **Cloudflare config generation** — app generates config.yml from tunnel name, hostname, credentials path, and web port; preview before writing
- **Config write with backup** — existing config.yml backed up before overwrite; backup path returned to UI
- **`/api/remote/setup-status`** — new endpoint returning full setup state, parsed config, diagnostics
- **`/api/remote/settings`** — new endpoint for saving tunnel settings from web UI
- **`/api/remote/generate-config`** — preview generated config.yml content
- **`/api/remote/write-config`** — write config with automatic backup
- **`intervalRunDurationMinutes`** — new independent field for interval auto-stop window; `durationMinutes` preserved for backward compat
- **`cloudflareConfigPath`** — new SettingsStore field for custom config.yml path
- **Audit logging for tunnel actions** — start, stop, write-config now logged with user and detail

### Bug Fixes

- **Task API videoDurationSeconds** — POST/PUT `/api/tasks` now persists `videoDurationSeconds`; GET returns it
- **Task API intervalRunDurationMinutes** — POST/PUT `/api/tasks` now persists `intervalRunDurationMinutes`; GET returns it
- **uploadProvider value unification** — web sends `googleDrive`/`localFolder`/`mountedFolder` matching `StorageProviderType` rawValues; API normalizes legacy values (`google_drive` → `googleDrive`, `local` → `localFolder`, `mounted` → `mountedFolder`)
- **Lossy task loading** — `loadTasks()` now decodes each task individually; one bad entry is skipped with a warning instead of clearing the entire task list
- **AuditLogManager detail field** — `AuditLogEntry` and `log()` now accept optional `detail` parameter

### UI

- **Web Settings: state-driven Cloudflare wizard** — replaces static 5-step copy-paste wizard with dynamic status banner, step checklist with checkmarks, config preview, one-click write
- **Named tunnel config fields** — tunnel name and hostname editable directly in web settings; save triggers `/api/remote/settings`

---

## v2.4.2 (2026-05-24)

Automation & Cloudflare Correctness Hotfix — fixes 10 correctness bugs in ScheduledTask migration, video duration, execution history, SettingsView, Cloudflare tunnel, mobile CSS, and data safety.

### Bug Fixes

- **ScheduledTask backward-compatible Codable** — custom `init(from:)` with `decodeIfPresent` defaults; old tasks.json without `actionType` no longer decodes to empty array
- **Video duration field split** — new `videoDurationSeconds` field (default 30s) for video recording; `durationMinutes` now only controls interval auto-stop window
- **Execution history accuracy** — `logExecution` moved from `handleTimerFired` (premature) to capture completion callbacks; video tasks log success only after recording actually stops
- **SettingsView defaults to Overview** — new `.overview` case in `SettingsSection` enum with storage, camera, automation, and upload queue summary cards
- **Automation task list in Settings** — native task list with enable/disable toggles, create/edit sheet, swipe-to-delete
- **Web uploadProvider picker** — tasks.html modal now includes provider selector (Default/Local/Mounted/Google Drive) shown when uploadToCloud is enabled
- **Cloudflare named tunnel fix** — removed erroneous `--url` injection in named mode; named tunnels now use `cloudflared tunnel run <name>` only
- **Cloudflare config detection** — `detectCloudflaredConfig()` checks `~/.cloudflared/config.yml` and credential files; named tunnel start fails with clear error if no credentials found
- **Remote API audit logging** — `/api/remote/start` and `/api/remote/stop` now write explicit ActivityLog entries with mode and user
- **Mobile CSS table fix** — removed global `table { display: none; }` on mobile; tables now scroll horizontally; only pages with `.has-cards` class hide tables in favor of card layouts

### Stability

- **Atomic task persistence** — `persistTasks()` now writes to `.tmp` file then uses `replaceItem` for crash-safe atomic writes

---

## v2.4.1 (2026-05-24)

Productization Completion Hotfix — real task action types, admin-only API enforcement, audit logging, stability hardening.

### New Features

- **TaskActionType** — tasks now have `actionType` (.photo or .video); video tasks start recording for `durationMinutes` then stop and save
- **Telegram video sending** — `sendVideo()` method using `/sendVideo` API with 120s timeout and retry
- **Admin-only API enforcement** — 20+ mutating routes now require `operatorRole` or `admin`; tunnel/retention routes require `admin`
- **Audit log with user tracking** — `AuditLogManager` now records the authenticated username on every request; new `/api/audit` endpoint (admin-only)
- **Audit log web page** — new `audit.html` with table + mobile card view, auto-refresh, clear button
- **Cloudflare quick tunnel** — `TunnelMode` enum (.quick vs .named); quick tunnel parses `*.trycloudflare.com` URL from output; mode selector in web settings
- **SettingsView real sidebar split** — `switch selectedSection` controlling detail pane with modular section views
- **Web mobile-first card layouts** — `.task-cards` for tasks and uploads on mobile; tables hidden on small screens

### Stability

- **MediaIndexStore thread safety** — serial `DispatchQueue` protects all reads/writes of `entries` dictionary; eliminates data races from concurrent upload + retention + UI access
- **Camera photo capture re-entry guard** — `isCapturingPhoto` flag prevents concurrent captures; `latestSampleBuffer` reads now go through `sampleBufferQueue`
- **Retention upload safety** — cleanup now skips files with `uploadStatus == .uploading` or `.queued`, preventing deletion of in-flight uploads
- **Web permission denied logging** — router logs `ActivityLogManager.warning(.security, ...)` when a user's role is insufficient for a route

### Bug Fixes

- Audit log now records authenticated user instead of `nil`
- `markUploadVerified` sets `uploadDate` (carried from v2.4.0)

---

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
