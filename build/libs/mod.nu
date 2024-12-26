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
    $in
    | reduce -f {} {|i,a|
        $a | merge deep --strategy=append ($conf | get $i)
    }
}

def install-components [
    --dry-run
    --sys:string
] {
    let o = $in
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
            apt_install $o.apt $o.apt-deps
            custom_install $o
            apt_uninstall $o.apt $o.apt-deps
            apt_clean
        }
        'Alpine Linux' => {
            use apk.nu *
            apk_update
            apk_install $o.apk $o.apk-deps
            custom_install $o
            apk_uninstall $o.apk $o.apk-deps
        }
        'Arch Linux' => {
            use pacman.nu *
            pacman_update
            pacman_install $o.pacman $o.pacman-deps
            custom_install $o
            pacman_uninstall $o.pacman $o.pacman-deps
            pacman_clean
        }
        _ => {
            log level 5 $"Not supported on ($sys)"
        }
    }
}

