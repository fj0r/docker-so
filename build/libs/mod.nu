use log.nu

export def build [
    conf: record
    target: list<string>
    --proxy: string
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
    | install-components
}

def resolve-components [conf] {
    $in
    | reduce -f {} {|i,a|
        $a | merge deep --strategy=append ($conf | get $i)
    }
}

def install-components [] {
    let o = $in
    use custom.nu *
    let sys = (sys host).name
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
            apk_uninstall $o.apt $o.apk-deps
        }
        'Arch Linux' => {
            use pacman.nu *
            pacman_update
            pacman_install $o.apt $o.apt-deps
            custom_install $o
            pacman_uninstall $o.apt $o.apt-deps
            pacman_clean
        }
        _ => {
            log level 5 $"Not supported on ($sys)"
        }
    }
}

