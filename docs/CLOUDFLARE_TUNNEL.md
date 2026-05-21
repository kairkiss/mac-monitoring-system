# Cloudflare Tunnel Setup for Mac监控系统

This guide explains how to securely expose your Mac监控系统 web dashboard to the internet using Cloudflare Tunnel (formerly Argo Tunnel).

## Prerequisites

- A Cloudflare account (free tier works)
- A domain managed by Cloudflare
- Mac监控系统 v2.0.1+ installed and running with Web Server enabled

## Step 1: Install cloudflared

```bash
# macOS (Homebrew)
brew install cloudflare/cloudflare/cloudflared

# Or download from https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
```

## Step 2: Authenticate

```bash
cloudflared tunnel login
```

This opens a browser where you select your domain.

## Step 3: Create a Tunnel

```bash
cloudflared tunnel create mac-monitor
```

Note the tunnel ID returned.

## Step 4: Configure the Tunnel

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <TUNNEL-ID>
credentials-file: /Users/<username>/.cloudflared/<TUNNEL-ID>.json

ingress:
  - hostname: camera.yourdomain.com
    service: http://127.0.0.1:8765
    originRequest:
      noTLSVerify: false
  - service: http_status:404
```

## Step 5: Add DNS Record

```bash
cloudflared tunnel route dns mac-monitor camera.yourdomain.com
```

## Step 6: Run the Tunnel

```bash
cloudflared tunnel run mac-monitor
```

To run as a service (survives reboot):

```bash
sudo cloudflared service install
```

## Step 7: Verify

Visit `https://camera.yourdomain.com` — you should see the login page.

## Security Recommendations

### Cloudflare Access (Recommended)

Enable Cloudflare Access to add an authentication layer before the tunnel:

1. Go to Cloudflare Zero Trust Dashboard
2. Access > Applications > Add an application
3. Configure policies (e.g., email OTP, GitHub OAuth)
4. This adds a second authentication barrier beyond the app's built-in auth

### Additional Security

- **Keep the web server bound to 127.0.0.1** (default) — never bind to 0.0.0.0
- **Use strong passwords** for web admin accounts (v2.0.1 uses salted SHA256)
- **Enable Cloudflare's WAF** rules for your domain
- **Monitor access logs** in the app's Activity Log and Cloudflare's analytics
- **Rotate passwords** periodically
- **Use the app's role system** — give viewers read-only access, reserve admin for yourself

## Troubleshooting

### Tunnel shows 502 Bad Gateway
- Verify the Mac监控系统 web server is running (Settings > Web Server > enabled)
- Check the port matches (default 8765)

### Connection refused
- Ensure `cloudflared` is running: `cloudflared tunnel info mac-monitor`
- Check firewall rules aren't blocking localhost:8765

### Slow loading
- Cloudflare Tunnel adds minimal latency (~10-50ms)
- If images are slow, consider reducing thumbnail quality in settings

## Notes

- The free Cloudflare Tunnel tier supports unlimited bandwidth
- The tunnel encrypts all traffic end-to-end (TLS)
- Your Mac's IP is never exposed — only Cloudflare's edge IPs are public
- If your Mac sleeps, the tunnel disconnects; consider disabling sleep or using `caffeinate`
