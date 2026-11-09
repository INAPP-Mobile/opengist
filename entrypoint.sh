#!/bin/sh
# Opengist Railway wrapper entrypoint (Alpine sh; the upstream image
# is alpine:3.24 with curl, git, and shadow).
#
# What it does, in order:
# - PORT: Railway injects PORT at runtime. Opengist reads its HTTP
#   port from OG_HTTP_PORT only (config key http.port, default 6157;
#   verified in thomiceli/opengist v1.15.3 internal/config/config.go
#   — env vars are loaded after the YAML config, so env wins).
#   Export OG_HTTP_PORT=$PORT on every boot. Fail loud if the remap
#   did not land — a server listening on the wrong port is a silent
#   dead deploy.
# - EXTERNAL URL: derive at boot from the live RAILWAY_PUBLIC_DOMAIN.
#   A template-expression default (https://${{RAILWAY_PUBLIC_DOMAIN}})
#   resolves to a bare "https://" on first deploy (no domain exists
#   yet); Opengist tolerates an unset value, but the boot-derived
#   value is what makes the login cookie Secure and passkeys work
#   behind the proxy. Only set it when a real domain is present.
# - HANDOFF: exec the upstream entrypoint exactly as the image does
#   (it chowns /opengist to the opengist user, drops privileges with
#   su, and runs `opengist --config /config.yml`).

set -eu

PORT_VALUE="${PORT:-6157}"
export OG_HTTP_PORT="$PORT_VALUE"

if [ "$OG_HTTP_PORT" != "$PORT_VALUE" ]; then
  echo "Opengist: ERROR HTTP port remap failed; refusing to start."
  exit 1
fi

# EXTERNAL_URL: derive at boot from the live RAILWAY_PUBLIC_DOMAIN.
# Only set it when a real domain is present; otherwise leave it
# unset and Opengist falls back to the request URL.
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export OG_EXTERNAL_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

echo "Opengist: HTTP on :${PORT_VALUE}, data in /opengist"
exec /app/opengist/docker/entrypoint.sh
