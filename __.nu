export def run [...layer] {
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
        -f base/base.Dockerfile
        -t so:base
        --build-arg BASEIMAGE=so:builder
        base
    )
}
