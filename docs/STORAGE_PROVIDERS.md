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
- **Status:** Available (v2.3.0+)
- **Configuration:**
  1. Create OAuth 2.0 credentials in [Google Cloud Console](https://console.cloud.google.com/)
  2. In the app: Settings > Storage Providers > Google Drive
  3. Enter your Client ID and Client Secret
  4. Click "Sign In to Google Drive" and authorize in the browser
  5. Optionally set a root folder ID (leave empty for My Drive root)
- **Behavior:**
  - Resumable chunked upload (8MB chunks)
  - Automatic folder creation: `MacMonitor/YYYY/MM/DD/photos|videos/`
  - Post-upload file verification (size match)
  - OAuth tokens stored securely in macOS Keychain
  - Automatic token refresh when expired
- **Security:**
  - Access and refresh tokens are stored in macOS Keychain
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
