ARG BASEIMAGE=ghcr.lizzie.fun/fj0r/so:nu
FROM ${BASEIMAGE}

COPY build /opt/build
