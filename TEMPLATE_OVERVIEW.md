# Cloudflared — Cloudflare Tunnel Connector for Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/cloudflared-template)

Publish your internal Railway services through Cloudflare **without exposing a single inbound
port**. This template runs `cloudflared`, the official Cloudflare Tunnel connector, as a
stateless, outbound-only sidecar for your Railway project — and unlike other cloudflared
templates, **it deploys green before you've even added a token**.

Pinned to the official `cloudflare/cloudflared:2026.9.1` image.

## What you get

- **Token-gated boot, no crash-loops.** Deploy first, paste your tunnel token later. Without a
  token the container stays healthy in a "configure-me" state and prints step-by-step setup
  instructions in its logs. With a token it runs the tunnel immediately.
- **A real healthcheck.** Railway probes `GET /ready` on the metrics port (`PORT=20241`,
  preconfigured). In token mode the endpoint only turns green when the tunnel is actually
  connected — a red deploy means a real connectivity problem, not a blind guess.
- **TCP-compatible transport.** `--protocol http2` is forced because Railway egress is
  TCP-only (QUIC/UDP unavailable), skipping the QUIC timeout-and-fallback delay on every boot.
- **Stateless by design.** No volume, no database, no public domain required. Restart or
  redeploy any time — the connector dials back out to Cloudflare's edge automatically.

## Setup (3 steps)

1. **Deploy** — when the deploy form asks for the `PORT` variable, enter `20241` (the metrics
   and healthcheck port; no other ports or variables are prompted).
2. **Create a tunnel** in the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/):
   Networks → Tunnels → Create a tunnel → Cloudflared, and copy the tunnel token (the `eyJ...`
   string after `--token` in the install command).
3. **Paste the token** into the deployed service: Variables → `TUNNEL_TOKEN` (a Railway secret
   variable — never commit it). The service redeploys and the tunnel shows **Connected** in the
   Cloudflare dashboard. Then map public hostnames to your Railway origins, e.g.
   `app.example.com → http://my-service.railway.internal:3000`.

### Security note

A tunnel exposes whatever origin you point it at: every public hostname → service mapping you
configure becomes reachable from the internet through Cloudflare. Double-check each route, and
use Cloudflare Access policies to protect admin panels or internal tools. The tunnel token is
the credential for your entire tunnel — keep it in Railway secret variables only.

### Troubleshooting

| Symptom | Fix |
|---|---|
| Setup banner in logs, healthcheck green, tunnel not connected | Expected before you add `TUNNEL_TOKEN` — see setup step 2. |
| `Provided Tunnel token is not valid` | Re-copy the full token from the Zero Trust dashboard (starts with `eyJ`). |
| Timeouts or protocol errors in logs | Keep `--protocol http2` (already forced by this template) — Railway egress is TCP-only, QUIC/UDP will not work. |
| Healthcheck red after a token is set | Check `/ready` on the metrics port (`PORT`, default 20241) and the tunnel's status in the Cloudflare dashboard. |

### Cost

Cloudflare Tunnels are free on the Cloudflare Zero Trust free tier (Cloudflare account
required). You pay only the small Railway usage of this connector container (typically a few
dollars per month) plus your origin services.

# Deploy and Host

## About Hosting

Deploying this template provisions one lightweight service, `cloudflared`, built from the
pinned official `cloudflare/cloudflared` image (2026.9.1) with a small entrypoint wrapper.
The service is stateless and outbound-only: it opens no inbound ports and needs no volume.
Railway healthchecks it over HTTP on the metrics port (`PORT=20241`, path `/ready`). The only
variable you ever configure is `TUNNEL_TOKEN`, a Railway secret variable you add after the
first deploy; without it the service stays healthy in a configure-me state with setup
instructions in the logs.

## Why Deploy

The cloudflared template previously on the marketplace failed 100% of deploys: it crash-looped
when `TUNNEL_TOKEN` was missing and exposed no healthcheck endpoint, so the deployment never
reported success. This template fixes all three failure modes: a token-gated entrypoint that
boots healthy without a token, an HTTP `/ready` healthcheck Railway can actually probe, and a
forced `http2` transport that works over Railway's TCP-only egress. You also get a pinned
image version, so the connector only changes when you choose to redeploy.

## Common Use Cases

- Exposing a self-hosted app (Adminer, n8n, Uptime Kuma, Gitea) running on Railway through
  your own Cloudflare domain, with Cloudflare's caching and WAF in front.
- Giving internal Railway services a public HTTPS endpoint without a Railway public domain,
  keeping the service itself private-network only.
- Connecting homelab or on-prem origins to Cloudflare while using Railway purely as the
  connector host.
- Fronting staging environments with Cloudflare Access policies for team-only access.

## Dependencies for

### Deployment Dependencies

- A free [Cloudflare](https://www.cloudflare.com/) account with the Zero Trust dashboard
  enabled — the tunnel is created there, and its token is pasted into Railway after deploy.
- No other Railway plugins, databases, volumes, or public domains are required. The template
  provisions exactly one service (`cloudflared`). The only deploy-form input is `PORT`
  (enter `20241`, the metrics/healthcheck port); `TUNNEL_TOKEN` is added by you as a secret
  variable after deploy.
