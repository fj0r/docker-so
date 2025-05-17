def list-layers [] {
    open build/manifest.yaml | get layers | columns
    | { completions: $in, options: { sort: false } }
}

export def run [...layer:string@list-layers --cache] {
    nu build/main.nu ...$layer --dry-run --os Ubuntu $"--cache=($cache)"
}

export def `build builder` [] {
    (
        ^$env.CNTRCTL build
        -f base/builder.Dockerfile
        -t so:builder
        .
    )
}

export def `build base` [] {
    build builder
    (
        ^$env.CNTRCTL build
        -f base/base-proxy.Dockerfile
        -t so:base
        --build-arg BASEIMAGE=so:builder
        base
    )
}


export def git-hooks [act ctx] {
    if $act == 'prepare-commit-msg' {
        {} | to yaml | save -f build/versions.yaml
    }
}
