# syntax=docker/dockerfile:1
# Cloudflared (Cloudflare Tunnel connector) for Railway.
#
# The official cloudflare/cloudflared image is distroless (no shell), so we
# lift the pinned binary into a slim Debian image that can run the
# entrypoint wrapper (token-gated boot + configure-me health endpoint).

ARG CLOUDFLARED_VERSION=2026.9.1

FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} AS cloudflared

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates busybox \
    && rm -rf /var/lib/apt/lists/*

COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /var/lib/cloudflared /usr/share/cloudflared-ready \
    && printf '{"status":"ready","state":"configure-me","detail":"set TUNNEL_TOKEN to connect the tunnel"}\n' \
        > /usr/share/cloudflared-ready/ready \
    && useradd --system --uid 65532 --no-create-home --shell /usr/sbin/nologin cloudflared \
    && chown -R 65532:65532 /var/lib/cloudflared /usr/share/cloudflared-ready

# Non-root, mirroring the upstream image's 65532 nonroot UID.
USER 65532:65532

# Metrics/health port (served by cloudflared when running; by the
# placeholder server in configure-me state).
EXPOSE 20241

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
