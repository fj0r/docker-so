def list-layers [] {
    open build/manifest.yaml | get layers | columns
}

export def run [...layer:string@list-layers] {
    nu build/main.nu ...$layer
}

export def `build builder` [] {
    (
        ^$env.CONTCTL build
        -f base/builder.Dockerfile
        -t so:builder
        .
    )
}

export def `build base` [] {
    build builder
    (
        ^$env.CONTCTL build
        -f base/base-proxy.Dockerfile
        -t so:base
        --build-arg BASEIMAGE=so:builder
        base
    )
}
