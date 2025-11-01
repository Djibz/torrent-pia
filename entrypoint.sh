#!/usr/bin/env bash
set -euo pipefail

# Ensure TUN exists
if [ ! -e /dev/net/tun ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200 || true
fi

# PIA credentials
CREDS_FILE="/tmp/pia_creds"
if [ -n "${PIA_USER:-}" ] && [ -n "${PIA_PASS:-}" ]; then
  mkdir -p /run
  printf '%s\n%s\n' "$PIA_USER" "$PIA_PASS" > "$CREDS_FILE"
  chmod 600 "$CREDS_FILE"
else
  exit 2
fi

# Start PIA daemon headlessly
/opt/piavpn/bin/piactl background enable
echo "daemon enabled"
/opt/piavpn/bin/piactl login "$CREDS_FILE"

/opt/piavpn/bin/piactl set allowlan true
/opt/piavpn/bin/piactl set protocol "${PIA_PROTOCOL:-openvpn}" || true
/opt/piavpn/bin/piactl set region "${PIA_REGION:-auto}" || true
/opt/piavpn/bin/piactl set requestportforward "${PIA_REQUEST_PORT_FORWARD:-true}" || true
/opt/piavpn/bin/piactl connect

echo "Waiting for VPN connection..."
for i in {1..600}; do
  state="$(/opt/piavpn/bin/piactl get connectionstate || echo Disconnected)"
  if [ "$state" = "Connected" ]; then break; fi
  sleep 1
done
echo "VPN connected: $(/opt/piavpn/bin/piactl get vpnip || true)"

# Launch qBittorrent headless
exec gosu "${QBT_USER}:${QBT_USER}" qbittorrent-nox -d \
  --profile="${QBT_CONFIG}" \
  --webui-port="${QBT_WEBUI_PORT}"
  # --torrenting-port="$(/opt/piavpn/bin/piactl get portforward)"

exec "$@"
