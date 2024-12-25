ARG BASEIMAGE=debian:bookworm-slim

FROM ${BASEIMAGE} as dropbear

RUN set -eux \
  ; apt-get update \
  ; DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        git gnupg build-essential curl jq ca-certificates \
        automake autoconf \
        # libz libcrypto
        libssl-dev zlib1g-dev \
  ; mkdir /build /target

WORKDIR /build

RUN set -eux \
  ; mkdir dropbear \
  ; dropbear_url=$(curl --retry 3 -sSL https://api.github.com/repos/mkj/dropbear/releases -H 'Accept: application/vnd.github.v3+json' | jq -r '.[0].tarball_url') \
  ; curl --retry 3 -sSL ${dropbear_url} | tar zxf - -C dropbear --strip-components=1 \
  ; cd dropbear \
  ; autoconf && autoheader && ./configure --enable-static \
  ; make PROGRAMS="dropbear dbclient scp dropbearkey dropbearconvert" \
  ; mkdir -p /target/bin \
  ; mv dbclient dropbear scp dropbearkey dropbearconvert /target/bin \
  ;

RUN set -eux \
  ; git clone --depth=1 https://github.com/openssh/openssh-portable.git \
  ; cd openssh-portable \
  ; autoreconf \
  ; ./configure \
  ; make sftp-server \
  ; mkdir -p /target/libexec \
  ; mv sftp-server /target/libexec \
  ;


FROM ${BASEIMAGE}
COPY --from=dropbear /target /usr

EXPOSE 22
VOLUME /world

ENV XDG_CONFIG_HOME=/etc \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TIMEZONE=Asia/Shanghai \
    BUILD_DEPS="jq"

RUN set -eux \
  ; apt-get update \
  ; apt-get upgrade -y \
  ; DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        sudo tzdata curl ca-certificates ${BUILD_DEPS:-} \
  \
  ; nu_ver=$(curl --retry 3 -sSL https://api.github.com/repos/nushell/nushell/releases/latest | jq -r '.tag_name') \
  ; nu_url="https://github.com/nushell/nushell/releases/download/${nu_ver}/nu-${nu_ver}-x86_64-unknown-linux-musl.tar.gz" \
  ; curl --retry 3 -sSL ${nu_url} | tar zxf - -C /usr/local/bin --strip-components=1 --wildcards '*/nu' '*/nu_plugin_query' \
  \
  ; echo '/usr/local/bin/nu' >> /etc/shells \
  \
  ; ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
  ; echo "$TIMEZONE" > /etc/timezone \
  #; sed -i /etc/locale.gen \
  #      -e 's/# \(en_US.UTF-8 UTF-8\)/\1/' \
  #      -e 's/# \(zh_CN.UTF-8 UTF-8\)/\1/' \
  #; locale-gen \
  ; sed -i 's/^.*\(%sudo.*\)ALL$/\1NOPASSWD:ALL/g' /etc/sudoers \
  \
  ; apt-get purge -y --auto-remove ${BUILD_DEPS:-} \
  ; apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* \
  ;


WORKDIR /world

