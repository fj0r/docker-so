FROM ghcr.io/fj0r/io

ARG message

ARG STACK_INFO_URL="https://www.stackage.org/lts"
RUN set -eux \
  ; ghc_ver=$(nu -c "'${message}' \
            | parse -r '\\+ghc_ver=(?<v>[0-9\\.]+)' | get -i v.0 \
            | default (http get -H [Accept application/json] ${STACK_INFO_URL} \
            | get snapshot.ghc \
            )") \
  ; echo "++${ghc_ver}++"

