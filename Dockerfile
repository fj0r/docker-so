ARG BASEIMAGE=fj0rd/scratch:nushell
FROM ${BASEIMAGE}

COPY npkg /opt/npkg

RUN nu /opt/npkg/main.nu setup \
    nu \
    nvim \
    python-utils \
    search
