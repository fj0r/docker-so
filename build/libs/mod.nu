use log.nu

export def build [
    conf: record
    target: list<string>
    --proxy: string
    --sys: string
    --dry-run
] {
    if ($proxy | is-not-empty) {
        log level 1 use proxy $proxy
        $env.http_proxy = $proxy
        $env.https_proxy = $proxy
    }
    $target
    | reduce -f [] {|t,a|
        if ($t in $conf.layers) {
            let n = $conf.layers | get $t
            $a | append $n | uniq
        }
    }
    | resolve-components $conf.components
    | install-components --dry-run=$dry_run --sys $sys
}

def resolve-components [conf] {
    let r = $in | reduce -f {} {|i,a|
        $a | merge deep --strategy=append ($conf | get $i)
    }

    let deps = $r.deps? | uniq | reduce -f {} {|y, b|
        $b | merge deep --strategy=append ($conf | get $y)
    }

    let build_deps = $r.build-deps? | uniq | reduce -f {} {|y, b|
        $b | merge deep --strategy=append ($conf | get $y)
    }

    let r = $r
    | merge deep --strategy=append {deps:[], build-deps:[]}
    | reject deps build-deps
    | merge deep --strategy=append $deps

    let b = $r | columns
    | reduce -f {} {|i,a| $a | insert $i [] }
    | merge deep --strategy=append $build_deps

    {pkg: $r, build_deps: $b}
}

def install-components [
    --dry-run
    --sys:string
] {
    let o = $in
    let pkg = $o.pkg
    let build_deps = $o.build_deps
    use custom.nu *

    let sys = if ($sys | is-empty) {
        (sys host).name
    } else {
        $sys
    }

    if $dry_run {
        log level 5 DRY RUN
        $env.dry_run = true
    }

    match $sys {
        'Debian GNU/Linux' | 'Ubuntu' => {
            use apt.nu *
            apt_update
            apt_install $pkg.apt $build_deps.apt
            custom_install $o
            apt_uninstall $pkg.apt $build_deps.apt
            apt_clean
        }
        'Alpine Linux' => {
            use apk.nu *
            apk_update
            apk_install $pkg.apk $build_deps.apk
            custom_install $o
            apk_uninstall $pkg.apk $build_deps.apk
        }
        'Arch Linux' => {
            use pacman.nu *
            pacman_update
            pacman_install $pkg.pacman $build_deps.pacman
            custom_install $o
            pacman_uninstall $pkg.pacman $build_deps.pacman
            pacman_clean
        }
        _ => {
            log level 5 $"Not supported on ($sys)"
        }
    }
}

