FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      qemu-system-x86 \
      qemu-utils \
      ovmf \
      seabios \
      novnc \
      websockify \
      curl \
      ca-certificates \
      procps \
      iproute2 \
      net-tools \
      openssl \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /run/qemu /var/log/qemu

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/qemu-install.sh /usr/local/bin/qemu-install.sh
COPY scripts/qemu-runtime.sh /usr/local/bin/qemu-runtime.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
              /usr/local/bin/qemu-install.sh \
              /usr/local/bin/qemu-runtime.sh

EXPOSE 6080 3389

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
