# syntax=docker/dockerfile:1
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    QBT_USER=qbittorrent \
    QBT_UID=1000 \
    QBT_GID=1000 \
    QBT_WEBUI_PORT=8080 \
    QBT_CONFIG=/config \
    PIA_REGION=auto \
    PIA_PROTOCOL=wireguard \
    PIA_REQUEST_PORT_FORWARD=false

# --- base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
      qbittorrent-nox \
      ca-certificates curl gnupg xz-utils \
      iproute2 iptables iputils-ping \
      openvpn wireguard-tools \
      procps tini bash gosu sudo \
      systemd systemd-sysv dbus udev \
    && rm -rf /var/lib/apt/lists/*

# --- unprivileged user
RUN groupadd -g "${QBT_GID}" "${QBT_USER}" \
 && useradd  -u "${QBT_UID}" -g "${QBT_GID}" -m -s /usr/sbin/nologin "${QBT_USER}" \
 && install -d -o "${QBT_UID}" -g "${QBT_GID}" /config /downloads

 # --- allow passwordless sudo without tty
RUN apt-get update && apt-get install -y sudo \
 && echo "${QBT_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${QBT_USER} \
 && echo "Defaults:${QBT_USER} !requiretty" >> /etc/sudoers.d/${QBT_USER} \
 && chmod 0440 /etc/sudoers.d/${QBT_USER}

# --- PIA installer (.run) – provided at build
ADD pia-linux-arm64-3.7-08412.run /tmp/pia-installer.run
RUN chown ${QBT_USER}:${QBT_USER} /tmp/pia-installer.run && chmod +x /tmp/pia-installer.run

# --- run installer as non-root user (required by PIA)
USER ${QBT_USER}
RUN sh /tmp/pia-installer.run
USER root
# RUN rm -f /tmp/pia-installer.run

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
# USER ${QBT_USER}
VOLUME ["/config", "/torrents", "/mediatheque"]


# HEALTHCHECK --interval=30s --timeout=35s --start-period=40s --retries=5 \
#   CMD piactl get connectionstate | grep -q Connected

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/lib/systemd/systemd"]
