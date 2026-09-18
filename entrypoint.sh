#!/bin/sh
# Entrypoint wrapper for the Cloudflared Railway template.
#
# - TUNNEL_TOKEN unset  -> print setup instructions and serve a healthy
#   /ready on the metrics port ("configure-me" state; no crash-loop).
# - TUNNEL_TOKEN set    -> exec cloudflared in token mode with a TCP-compatible
#   transport (http2) and a metrics endpoint exposing /ready for healthchecks.
set -eu

METRICS_PORT="${METRICS_PORT:-20241}"

log() {
    printf '%s [cloudflared-template] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

if [ -z "${TUNNEL_TOKEN:-}" ]; then
    log "TUNNEL_TOKEN is not set - entering configure-me state (container stays healthy, tunnel is NOT connected yet)."
    cat <<'EOF'

======================================================================
 Cloudflared Railway template - one step to connect your tunnel
======================================================================
 1. Sign in to the Cloudflare Zero Trust dashboard:
      https://one.dash.cloudflare.com/
 2. Go to Networks > Tunnels > Create a tunnel > select "Cloudflared"
    and give the tunnel a name.
 3. Copy the tunnel token - the long string the install command shows
    after "--token" (it starts with "eyJ").
 4. In Railway: open this service > Variables > add
      TUNNEL_TOKEN = <the token>
    The service redeploys and connects to Cloudflare automatically.
 5. Back in the Cloudflare dashboard, open the tunnel's public
    hostnames and route them to your Railway origins, e.g.
      app.example.com  ->  http://my-service.railway.internal:3000
======================================================================

EOF
    log "Serving placeholder /ready on port ${METRICS_PORT} so the healthcheck stays green while you configure the token."
    exec busybox httpd -f -p "${METRICS_PORT}" -h /usr/share/cloudflared-ready
fi

log "TUNNEL_TOKEN found - starting cloudflared (protocol http2, metrics on 0.0.0.0:${METRICS_PORT})."
exec cloudflared tunnel --no-autoupdate --protocol http2 --metrics "0.0.0.0:${METRICS_PORT}" run
