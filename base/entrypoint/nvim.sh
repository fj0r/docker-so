if [[ -n "$NVIM_WORKDIR" ]]; then
    for p in $(find /opt $LS_ROOT -maxdepth 2 -mindepth 2 -type d -name bin); do
        export PATH=$p:$PATH
    done

    if command -v stack &> /dev/null; then
        for l in $(find $(stack ghc -- --print-libdir) -maxdepth 1 -mindepth 1 -type d); do
            export LD_LIBRARY_PATH=$l:$LD_LIBRARY_PATH
        done
    fi

    export TERM=screen-256color
    export SHELL=nu

    nvim --listen 0.0.0.0:${NVIM_PORT:-9999} --headless +"set title titlestring=[${NVIM_TITLE:-$NVIM_WORKDIR}]" ${NVIM_WORKDIR} 2>&1 &
    # nvim --remote-ui --server $addr

    echo -n "$! " >> /var/run/services
fi
