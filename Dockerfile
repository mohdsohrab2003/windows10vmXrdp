FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# Install QEMU + noVNC + networking utilities
# ============================================================

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      qemu-system-x86 \
      qemu-utils \
      ovmf \
      seabios \
      novnc \
      websockify \
      python3 \
      curl \
      wget \
      ca-certificates \
      procps \
      iproute2 \
      net-tools \
      openssl \
      file \
 && rm -rf /var/lib/apt/lists/*

# ============================================================
# Create required directories
# ============================================================

RUN mkdir -p \
      /data \
      /iso \
      /run/qemu \
      /var/log/qemu

# ============================================================
# Copy startup scripts
# ============================================================

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/qemu-install.sh /usr/local/bin/qemu-install.sh
COPY scripts/qemu-runtime.sh /usr/local/bin/qemu-runtime.sh

# ============================================================
# Make scripts executable
# ============================================================

RUN chmod +x \
      /usr/local/bin/entrypoint.sh \
      /usr/local/bin/qemu-install.sh \
      /usr/local/bin/qemu-runtime.sh

# ============================================================
# Ports
# ============================================================

# 6080 = noVNC browser console
# 3389 = Windows RDP
EXPOSE 6080
EXPOSE 3389

# ============================================================
# Start
# ============================================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]