ARG BASEIMAGE=fj0rd/scratch:nushell
FROM ${BASEIMAGE}

COPY npkg /opt/npkg

RUN echo 'NPKG=true' >> /etc/environment

RUN nu /opt/npkg/run.nu setup --clean \
    base \
    nvim \
    http \
    python-utils \
    find \
    exec
