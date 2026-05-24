# Storage Providers

Mac监控系统 supports multiple storage backends for uploading captured photos and videos.

## Available Providers

### Local Folder
- **Status:** Available
- **Configuration:** Select a local directory in Settings > Storage Providers > Local Folder
- **Behavior:** Files are copied to `MacMonitor/YYYY/MM/DD/photos|videos/` with post-upload size verification

### Mounted Folder
- **Status:** Available
- **Configuration:** Select a mounted volume or network share in Settings > Storage Providers > Mounted Folder
- **Behavior:** Same as Local Folder; useful for NAS or external drives

### Google Drive
- **Status:** Available (v2.3.1+)
- **Configuration:** See [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md) for detailed step-by-step instructions
  1. Create OAuth 2.0 credentials (Desktop app type) in [Google Cloud Console](https://console.cloud.google.com/)
  2. Add `http://127.0.0.1` as authorized redirect URI
  3. In the app: Settings > Storage Providers > Google Drive
  4. Enter your Client ID and Client Secret (stored in Keychain)
  5. Click "Sign In to Google Drive" and authorize in the browser
  6. Set a root folder name (default: MacMonitor)
- **Behavior:**
  - Resumable chunked upload (8MB chunks)
  - Automatic folder creation: `RootFolder/photos/` or `RootFolder/videos/`
  - No-remote-overwrite: unique filenames generated automatically
  - Post-upload file verification (size match)
  - OAuth tokens stored securely in macOS Keychain
  - Automatic token refresh when expired
- **Security:**
  - Client Secret, access token, and refresh token are stored in macOS Keychain
  - Tokens are never exposed to the Web UI or activity logs
  - Only the `drive.file` scope is requested (files created by the app)

## Planned Providers

### WebDAV
- **Status:** Planned — not yet implemented
- Will support HTTPS-only by default (configurable to allow HTTP)
- Password will be stored in Keychain

## Upload Queue

All providers use the Upload Queue for reliable upload with retry:
- Exponential backoff: 10s, 20s, 40s... up to 300s max
- Manual retry bypasses backoff delay
- Progress tracking and pause/resume support
- Configurable max concurrent uploads and retry count

## Retention Policy

After verified upload, the Retention Manager can automatically delete local originals:
- Configurable grace period (default 24 hours)
- Protects favorites and recently captured files
- Only deletes local files — index entries are preserved
