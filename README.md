# Cloudflared on Railway — Cloudflare Tunnel connector

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/cloudflared-template)

Deploy a **Cloudflare Tunnel connector** (`cloudflared`) on Railway and publish your
internal Railway services through Cloudflare **without exposing a single inbound port**.

Tunnels are outbound-only: the connector dials out to Cloudflare's edge, visitors hit
your Cloudflare hostname, and requests flow back down the tunnel to your service.
No public domain on Railway, no load balancer, no open ports.

**Version pinned to the official [`cloudflare/cloudflared`](https://github.com/cloudflare/cloudflared) image `2026.9.1`.**

---

## Why this template works on first deploy

The connector is token-gated:

- **No `TUNNEL_TOKEN` yet?** The container boots into a healthy **configure-me** state:
  it prints step-by-step setup instructions in the deploy logs and serves a green
  `/ready` healthcheck. No crash-looping, no red deploys.
- **`TUNNEL_TOKEN` set?** It runs the tunnel with:
  - `--protocol http2` — a TCP-compatible transport (Railway egress is TCP-only;
    QUIC/UDP is unavailable, and forcing `http2` skips the QUIC timeout-and-fallback delay)
  - `--metrics 0.0.0.0:20241` — exposes the `/ready` endpoint used as the Railway healthcheck
  - `--no-autoupdate` — the container is immutable; updates come from redeploying

The service is **stateless**: no volume needed. Restart it and it reconnects automatically.

---

## Setup (3 steps)

### 1. Create a tunnel in Cloudflare

1. Sign in to the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/).
2. Go to **Networks → Tunnels → Create a tunnel**, select **Cloudflared**, give it a name.
3. Copy the **tunnel token** — the long string the install command shows after
   `--token` (it starts with `eyJ`).

### 2. Paste the token into Railway

1. In your Railway project, open the **cloudflared** service → **Variables**.
2. Add `TUNNEL_TOKEN` and paste the token. (It is a secret variable — never commit it.)
3. The service redeploys and connects. `GET /ready` on the metrics port returns `200`
   once the tunnel is connected, and the tunnel shows **Connected** in the Cloudflare dashboard.

### 3. Map public hostnames to your services

In the tunnel's **Public Hostname** settings, route hostnames to your Railway origins:

| Public hostname | Service |
|---|---|
| `app.example.com` | `http://my-app.railway.internal:3000` |
| `api.example.com` | `http://my-api.railway.internal:8080` |

Use the **internal hostname** (`<service-name>.railway.internal`) and the port your
service listens on inside Railway — traffic never leaves Railway's private network
until it reaches Cloudflare's edge.

---

## Security notes

- **A tunnel exposes whatever origin you point it at.** Double-check every public
  hostname → service mapping; anything you route becomes reachable from the internet
  through Cloudflare. Use Cloudflare Access policies to lock down admin apps.
- **`TUNNEL_TOKEN` is the credential for your whole tunnel.** Anyone who has it can run
  a connector for your tunnel. Keep it in Railway secret variables only; never commit
  it to git or paste it into logs.
- The connector itself listens only on an internal metrics port (`20241`) and makes
  outbound connections. It opens no inbound ports on Railway.

## Networking notes (Railway specifics)

- **Healthcheck port:** the template sets `PORT=20241` on the service — Railway probes
  its HTTP healthcheck against that port, so don't change it unless you also change the
  metrics port. No public domain is needed: the connector is outbound-only, and Railway
  reaches it over the private network.
- **Protocol:** `http2` is forced because Railway's egress is TCP-only; the default
  QUIC transport needs UDP and would fall back after a timeout on every restart.
- **Healthcheck:** Railway performs an HTTP healthcheck against `/ready` on the
  metrics port. In token mode, `/ready` returns `200` only when the tunnel is actually
  connected — so a red healthcheck means a real connectivity problem.
- **Metrics:** `GET /ready` (connectivity) and `/metrics` (Prometheus) are available on
  port `20241` from inside your Railway project's private network.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Logs show the setup banner, healthcheck green, tunnel not connected | Expected in the configure-me state — add `TUNNEL_TOKEN` (step 2). |
| `Provided Tunnel token is not valid` | Re-copy the token from the Cloudflare dashboard; make sure you copied the whole `eyJ...` string. |
| Healthcheck red with a token set, logs show QUIC/timeouts | This template already forces `http2`; if you overrode the protocol back to `quic`, set it back — Railway egress is TCP-only. |
| Tunnel connected but hostname returns errors | Check the public hostname's service URL (scheme `http://`, internal hostname, correct port). |
| Want to verify the connector | From any Railway service: `wget -qO- http://cloudflared.railway.internal:20241/ready` |

## Cost

Cloudflare Tunnels are free (Cloudflare account required; Zero Trust free tier covers
personal use). You pay only Railway usage for this small container (~$0–3/month) plus
whatever your origin services cost.

## License

MIT. Not affiliated with Cloudflare, Inc. — `cloudflared` is a trademark of Cloudflare, Inc.
