ARG BASEIMAGE=fj0rd/scratch:nushell
FROM ${BASEIMAGE}

COPY npkg /opt/npkg

RUN nu /opt/npkg/run.nu setup \
    nu \
    nvim \
    http \
    python-utils \
    search
