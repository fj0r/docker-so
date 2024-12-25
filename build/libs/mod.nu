export def build [conf: record target: list<string>] {
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
    use http.nu *
    match (sys host).name {
        'Debian GNU/Linux' | 'Ubuntu' => {
            use apt.nu *
            apt_update
            apt_install $o.apt $o.apt-deps
            http_install $o.http
            apt_uninstall $o.apt-deps
            apt_clean
        }
        'Alpine Linux' => {
            use apk.nu *
            apk_update
            apk_install $o.apk $o.apk-deps
            http_install $o.http
            apk_uninstall $o.apk-deps
        }
        'Arch Linux' => {
            use pacman.nu *
            pacman_update
            pacman_install $o.apt $o.apt-deps
            http_install $o.http
            pacman_uninstall $o.apt-deps
            pacman_clean
        }
    }
}

