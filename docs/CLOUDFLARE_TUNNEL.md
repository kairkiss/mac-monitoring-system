# Cloudflare Tunnel Setup for Mac监控系统

This guide helps you securely access your Mac监控系统 web dashboard from anywhere using Cloudflare Tunnel.

## Why Cloudflare Tunnel?

- **No port forwarding** — your Mac's IP is never exposed
- **Free** — Cloudflare Tunnel has no bandwidth limits on the free tier
- **Encrypted** — all traffic is TLS encrypted end-to-end
- **Double protection** — Cloudflare Access + App Login = two layers of security

> **Security:** Never bind the web server to `0.0.0.0` or expose port 8765 directly to the internet. Always use Cloudflare Tunnel.

## Prerequisites

- A Cloudflare account (free tier works) — [Sign up](https://dash.cloudflare.com/sign-up)
- A domain added to Cloudflare (free plan is fine)
- Mac监控系统 v2.3.1+ with Web Server enabled

## Quick Start

The app includes a built-in setup wizard in **Settings > Remote Access** with copy-to-clipboard commands. This guide provides the same steps with more detail.

## Step 1: Install cloudflared

```bash
brew install cloudflare/cloudflare/cloudflared
```

Or download from [Cloudflare Downloads](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).

Verify installation:
```bash
cloudflared --version
```

## Step 2: Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser. Select the domain you want to use.

## Step 3: Create a Tunnel

```bash
cloudflared tunnel create mac-monitor
```

Note the tunnel ID that is returned (looks like `a1b2c3d4-...`).

## Step 4: Configure DNS

Replace `monitor.yourdomain.com` with your actual subdomain:

```bash
cloudflared tunnel route dns mac-monitor monitor.yourdomain.com
```

## Step 5: Create Configuration File

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <YOUR-TUNNEL-ID>
credentials-file: /Users/<YOUR-USERNAME>/.cloudflared/<YOUR-TUNNEL-ID>.json

ingress:
  - hostname: monitor.yourdomain.com
    service: http://127.0.0.1:8765
  - service: http_status:404
```

Replace:
- `<YOUR-TUNNEL-ID>` with the tunnel ID from Step 3
- `<YOUR-USERNAME>` with your macOS username
- `monitor.yourdomain.com` with your actual subdomain
- `8765` with your web server port if you changed it

## Step 6: Start the Tunnel

```bash
cloudflared tunnel run mac-monitor
```

To run as a background service (survives reboot):
```bash
sudo cloudflared service install
```

## Step 7: Verify

Visit `https://monitor.yourdomain.com` — you should see the login page.

## Step 8: Enable Cloudflare Access (Recommended)

This adds a second authentication layer before anyone reaches your app:

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
2. **Access** > **Applications** > **Add an application**
3. Select **Self-hosted**
4. Configure:
   - Application name: "MacMonitor"
   - Session duration: 24 hours
   - Application domain: monitor.yourdomain.com
5. Add a policy:
   - Policy name: "Allow"
   - Action: Allow
   - Include: Email (enter your email) or One-time PIN
6. Save

Now visitors must pass Cloudflare Access **before** they see the app login page.

## Double Protection

```
Internet → Cloudflare Access (email/OTP) → Tunnel → App Login (username/password)
```

- **Layer 1:** Cloudflare Access — verifies identity via email OTP, GitHub OAuth, etc.
- **Layer 2:** App Login — your custom username and password (configurable in Settings)

Both layers must be passed. This is the recommended security configuration.

## Troubleshooting

### 502 Bad Gateway
- Check that Mac监控系统 web server is running (Settings > Web Server > enabled)
- Verify the port in `config.yml` matches your web server port

### Connection refused
- Ensure `cloudflared` is running: `cloudflared tunnel info mac-monitor`
- Check that the web server is bound to `127.0.0.1` (not `0.0.0.0`)

### DNS not resolving
- Wait a few minutes for DNS propagation
- Check that the CNAME record was created in Cloudflare DNS settings

### Slow loading
- Cloudflare Tunnel adds ~10-50ms latency
- If images are slow, the app serves thumbnails; use Download for full files

### cloudflared not found
- Ensure Homebrew is installed and `brew` is in your PATH
- Or try the full path: `/opt/homebrew/bin/cloudflared`

## Notes

- The free tier supports unlimited bandwidth
- Your Mac's IP is never exposed — only Cloudflare's edge IPs are public
- If your Mac sleeps, the tunnel disconnects; consider using `caffeinate` or disabling sleep
- The tunnel encrypts all traffic with TLS
