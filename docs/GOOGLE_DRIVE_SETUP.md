# Google Drive Setup Guide for Mac监控系统

This guide walks you through setting up Google Drive as a storage provider for Mac监控系统.

## Prerequisites

- A Google account with Google Drive access
- Mac监控系统 v2.3.2+ installed and running
- A web browser

## Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **Select a project** > **New Project**
3. Name it (e.g., "MacMonitor") and click **Create**

## Step 2: Enable Google Drive API

1. In the Google Cloud Console, go to **APIs & Services** > **Library**
2. Search for "Google Drive API"
3. Click it and click **Enable**

## Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services** > **OAuth consent screen**
2. Select **External** user type (or Internal if using Google Workspace)
3. Fill in:
   - App name: "MacMonitor" (or your preferred name)
   - User support email: your email
   - Developer contact: your email
4. Click **Save and Continue**
5. On **Scopes** page, click **Add or Remove Scopes**, add:
   - `https://www.googleapis.com/auth/drive.file` (only files created by this app)
6. Click **Save and Continue**
7. On **Test users** page, add your own email address
8. Click **Save and Continue**

> **Note:** While the app is in "Testing" mode, only test users can authorize. To use without restrictions, publish the app (this only requests `drive.file` scope, so it's safe).

## Step 4: Create OAuth Credentials

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Application type: **Desktop app**
4. Name: "MacMonitor Desktop"
5. Click **Create**
6. **Copy the Client ID and Client Secret** — you'll need these

## Step 5: Configure Authorized Redirect URI

This is important — without this step, the sign-in flow won't work.

1. In the Credentials page, click on your newly created OAuth client
2. Under **Authorized redirect URIs**, add:
   ```
   http://127.0.0.1
   ```
3. Click **Save**

> **Why `http://127.0.0.1`?** The app starts a temporary local HTTP server to receive the OAuth callback. This is Google's recommended approach for desktop applications. The port is random for security, but the redirect URI base must be registered.

## Step 6: Configure Mac监控系统

1. Open Mac监控系统
2. Go to **Settings** > **Storage Providers**
3. Select **Google Drive**
4. Enter your **Client ID** (from Step 4)
5. Enter your **Client Secret** (from Step 4) — stored securely in macOS Keychain
6. Click **Sign In to Google Drive**
7. A browser window opens — sign in with your Google account and authorize
8. You'll see a success page — return to the app

## Step 7: Test Connection

1. Click **Test Connection** in Settings
2. You should see "Connected" with your Google email

## Default Folder Structure

Files are uploaded to Google Drive in this structure:

```
My Drive/
  MacMonitor/
    photos/
      IMG_001_1716500000.jpg    (unique name, never overwrites)
      IMG_002_1716500100.jpg
    videos/
      VID_001_1716500200.mp4
```

- **Root folder name** is configurable (default: "MacMonitor")
- **No date subfolders** — files are organized by type only, making them easy to find
- **Unique filenames** — if a same-name file exists, a timestamp suffix is added automatically
- **No overwriting** — existing remote files are never replaced

## Security

| Item | Storage Location |
|------|-----------------|
| Client ID | UserDefaults (not sensitive) |
| Client Secret | macOS Keychain |
| Access Token | macOS Keychain |
| Refresh Token | macOS Keychain |
| Token Expiry | macOS Keychain |
| User Email | macOS Keychain |

- Tokens are **never** exposed to the Web UI, API responses, or activity logs
- Only the `drive.file` scope is requested (files created by this app only)
- The app cannot access files in your Drive that it didn't create

## Retention Policy

If **Delete local original after verified upload** is enabled:

1. File is uploaded to Google Drive
2. Upload is verified (file exists, size matches)
3. After the grace period (default 24 hours), local original is deleted
4. Thumbnail and index entry are preserved
5. Remote file ID, URL, and provider type are preserved in the index
6. Favorites and protected files are never auto-deleted

## Troubleshooting

### App crashes when selecting Google Drive
- **Fixed in v2.3.2** — update to the latest version
- If still crashing, check that your macOS version is 14.0+

### App crashes when clicking Sign In
- **Fixed in v2.3.2** — the OAuth flow now runs safely on the main thread
- Make sure you've entered both Client ID and Client Secret before clicking Sign In

### "Google Drive is not configured"
- Enter your Client ID and Client Secret in Settings > Storage Providers > Google Drive
- Both fields are required before signing in

### "Sign-in was cancelled"
- You closed the browser window before completing authorization
- Click Sign In again and complete the full flow

### "Google Drive needs reconnect"
- Your refresh token expired or was revoked
- Click Sign Out, then Sign In again with fresh credentials

### "OAuth failed" or "No authorization code received"
- Verify **Client ID** and **Client Secret** are correct
- Verify `http://127.0.0.1` is added as an authorized redirect URI (Step 5)
- Try signing out and signing in again

### "Token refresh failed" or "Needs Reconnect"
- Your refresh token may have expired or been revoked
- Click **Sign Out**, then **Sign In** again
- If this happens frequently, check that your Google Cloud project isn't restricted

### "Permission denied or storage quota exceeded"
- Check your Google Drive storage quota
- Ensure the app has `drive.file` scope authorized

### "Rate limited"
- Google Drive API has rate limits; the app will retry automatically
- If persistent, wait a few minutes and try again

### Sign-in window doesn't appear
- Check that Mac监控系统 has network access
- Try quitting and reopening the app
- Check macOS firewall settings

## Notes

- The app only requests `drive.file` scope — it can only manage files it creates
- Files uploaded by the app appear in your Google Drive and count against your storage quota
- WebDAV support is planned but not yet implemented
