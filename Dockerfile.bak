ARG BASEIMAGE=fj0rd/scratch:nushell
FROM ${BASEIMAGE}

COPY npup /opt/npup

RUN nu /opt/npup/run.nu setup --clean \
    base \
    nvim \
    http \
    python-utils \
    find \
    exec
