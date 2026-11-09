# Opengist on Railway — wrapper around the pinned upstream image.
#
# Why a wrapper at all (house style: bake constants, keep the deploy
# form minimal, and survive Railway's root-owned volumes):
# - PORT: Opengist reads its HTTP port from OG_HTTP_PORT (config key
#   http.port, default 6157) and ignores Railway's generic PORT
#   (verified in thomiceli/opengist v1.15.3 internal/config/config.go:
#   defaults are loaded, then the YAML config, then env vars — env
#   wins). entrypoint.sh exports OG_HTTP_PORT=$PORT on every boot.
#   Fail loud if the remap did not land — a server listening on the
#   wrong port is a silent dead deploy.
# - USER root: the stock image has no USER directive; its entrypoint
#   runs as root, chowns /opengist to the opengist user (UID/GID
#   1000 by default), then drops privileges with su. Railway mounts
#   persistent volumes root-owned, so the stock entrypoint handles
#   them with no change. The wrapper states USER root explicitly so
#   a future upstream non-root switch cannot silently break it.
# - DATA: one Railway volume at /opengist. OG_OPENGIST_HOME (baked
#   below) puts the SQLite database (opengist.db), every gist's Git
#   repository, the Bleve search index, and the log file on the
#   volume, so gists, users, and settings survive restarts and
#   redeploys.
# - FIRST RUN: no setup wizard and no email step. Open the public
#   URL and register — the first account created becomes the admin.
#   Signup stays open after that, so the README documents disabling
#   it (Admin → Configuration) once the team is in.
# - SECRET KEY: OG_SECRET_KEY signs sessions and encrypts MFA data.
#   Upstream defaults to a fresh random 32 bytes, which would
#   invalidate every session on redeploy, so it is a generated
#   deploy-form variable (${{secret(32)}}) that stays stable.
# - SSH GIT: Opengist also runs a built-in SSH server on port 2222
#   for git over SSH. Railway's public edge is HTTP-only, so port
#   2222 is NOT publicly reachable — the SSH clone URLs the UI would
#   show cannot work. The wrapper disables the SSH server
#   (OG_SSH_GIT_ENABLED=false); git over HTTP works through the
#   proxy and is the only clone path this template offers.
# - EXTERNAL URL: derived at boot from the live RAILWAY_PUBLIC_DOMAIN
#   by entrypoint.sh — never a template-expression variable. A
#   https://${{RAILWAY_PUBLIC_DOMAIN}} default resolves to a bare
#   "https://" on first deploy (no domain exists yet); Opengist
#   tolerates an unset value (it falls back to the request URL), but
#   the boot-derived value is what makes the login cookie Secure and
#   passkeys work behind the proxy. (Same shape as the 2026-10-29
#   Spliit BASE_URL and 2026-11-08 LLDAP HTTP_URL lessons.)
# - No Docker HEALTHCHECK: rely on Railway's external
#   healthcheckPath. The upstream in-image HEALTHCHECK curls
#   http://localhost:6157/healthcheck — that same path is the
#   platform probe (unauthenticated, 200).
#
# Upstream: Opengist v1.15.3 (AGPL-3.0), image pinned by manifest
# digest, verified 2026-11-09 via the GHCR registry API (multi-arch
# manifest-list digest below; amd64 image digest
# sha256:3752fb2a467b4fc5e19a6ba4985f5a84e005b62c3fbb63536aea1f8f2d3a6222).
# NOTE: the FROM uses the digest WITHOUT a tag — Railpack 0.43.0
# fails to detect a Dockerfile whose FROM carries both a tag and a
# digest (redeploys die in the plan phase with "could not determine
# how to build the app"); the digest-only form builds under both
# the Dockerfile builder and Railpack (verified 2026-11-05 —
# TimeTagger's digest-only FROM is the precedent).

# thomiceli/opengist:v1.15.3
FROM ghcr.io/thomiceli/opengist@sha256:f5dd39cc9409b4006f8b090e5f9ed042cdb736d28a06b4f985c674dacafc94d5

USER root

COPY entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# Baked constants (see header): data home on the volume, SSH git
# disabled (port 2222 is not publicly reachable on Railway). The HTTP
# port is mapped from Railway's PORT by the entrypoint on every boot.
ENV OG_OPENGIST_HOME=/opengist \
    OG_SSH_GIT_ENABLED=false

# Documentation only: Railway routes to $PORT at runtime (see
# entrypoint.sh); 6157 is the upstream default the image would use
# without the wrapper's remap.
EXPOSE 6157

ENTRYPOINT ["/railway-entrypoint.sh"]
