ARG BASEIMAGE=fj0rd/scratch:nushell
FROM ${BASEIMAGE}

COPY setup /opt/setup

RUN nu /opt/setup/init.nu dry-run
