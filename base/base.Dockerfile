ARG BASEIMAGE=ghcr.lizzie.fun/fj0r/so:builder
FROM ${BASEIMAGE}

ENV DEBUGE=
ENV PREBOOT=
ENV POSTBOOT=
ENV CRONFILE=
COPY entrypoint /entrypoint

ENV git_pull=
#ENV ed25519_xxx=

ENTRYPOINT [ "/entrypoint/init.sh" ]

RUN nu /opt/build/main.nu base neovim-full nushell-config dev
