ARG BASEIMAGE=debian:bookworm-slim
FROM ghcr.io/fj0r/io:__dropbear__ as dropbear

FROM ${BASEIMAGE}

EXPOSE 22
VOLUME /world

ENV XDG_CONFIG_HOME=/etc \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TIMEZONE=Asia/Shanghai

COPY --from=dropbear / /
