ARG BASEIMAGE=ghcr.lizzie.fun/fj0r/so:base
FROM ${BASEIMAGE}

ARG RUST_CHANNEL=stable
ENV RUST_CHANNEL=${RUST_CHANNEL}
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV PATH=${CARGO_HOME}/bin:$PATH

RUN nu /opt/build/main.nu rust
