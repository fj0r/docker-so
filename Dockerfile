ARG BASEIMAGE=fj0rd/scratch:nushell
FROM ${BASEIMAGE}

COPY npkg /opt/npkg

ENV NPKG=true

RUN nu /opt/npkg/run.nu setup --clean \
    base \
    nvim \
    http \
    python-utils \
    find \
    exec
