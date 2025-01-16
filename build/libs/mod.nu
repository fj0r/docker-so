use log.nu

export def build [
    conf: record
    target: list<string>
    --proxy: string
    --os: string
    --dry-run
    --cache
    --versions: record
    --custom-list: list<string>
] {
    if ($proxy | is-not-empty) {
        log level 1 use proxy $proxy
        $env.http_proxy = $proxy
        $env.https_proxy = $proxy
    }

    if ($custom_list | is-not-empty) {
        $env.custom_list = $custom_list
    } else {
        $env.custom_list = [http git cmd shell flow rustup pip npm cargo stack]
    }

    $target
    | reduce -f [] {|t,a|
        if ($t in $conf.layers) {
            let n = $conf.layers | get $t
            $a | append $n | uniq
        } else {
            error make {msg: $"layer ($t) not exists" }
        }
    }
    | resolve-components $conf.components
    | install-components --cache=$cache --dry-run=$dry_run --os $os --versions $versions
}

def enrich [o name]  {
    let x = $o | get $name
    let ks = $x | columns
    $ks | reduce -f $x {|i,a|
        if $i in $env.custom_list {
            $a | update $i ($a | get $i | upsert group [$name])
        } else {
            $a
        }
    }
}

def resolve-deps [conf deps -k:string='deps'] {
    mut deps = $deps
    for d in $deps {
        let x = $conf | get $d
        if $k in $x {
            let d1 = $x | get $k
            $deps ++= $d1
            let d2 = resolve-deps $conf $d1 -k $k
            $deps ++= $d2
        }
    }
    $deps | uniq
}

def resolve-components [conf] {
    let r = $in | reduce -f {} {|i,a|
        $a | merge deep --strategy=append (enrich $conf $i)
    }

    let deps = resolve-deps $conf $r.deps? -k 'deps' | reduce -f {} {|y, b|
        $b | merge deep --strategy=append (enrich $conf $y)
    }

    let build_deps = resolve-deps $conf $r.build-deps? -k 'build-deps' | reduce -f {} {|y, b|
        $b | merge deep --strategy=append (enrich $conf $y)
    }

    let r = $r
    | merge deep --strategy=append {deps:[], build-deps:[]}
    | reject deps build-deps
    | merge deep --strategy=append $deps

    let b = $r | columns
    | reduce -f {} {|i,a| $a | insert $i [] }
    | merge deep --strategy=append $build_deps

    $r | merge deep --strategy=append {build_deps: $b}
}

def install-components [
    --cache
    --dry-run
    --os:string
    --versions: record
] {
    let pkg = $in
    let build_deps = $pkg.build_deps
    use custom.nu *

    let os = if ($os | is-empty) {
        (sys host).name
    } else {
        $os
    }

    if $dry_run {
        log level 5 DRY RUN
        $env.dry_run = true
    }

    match $os {
        'Debian GNU/Linux' | 'Ubuntu' => {
            use apt.nu *
            apt_update
            apt_install $pkg.apt $build_deps.apt
            custom_install $pkg -v $versions --cache=$cache
            if not $cache { custom_clean }
            apt_uninstall $pkg.apt $build_deps.apt
            apt_clean
        }
        'Alpine Linux' => {
            use apk.nu *
            apk_update
            apk_install $pkg.apk $build_deps.apk
            custom_install $pkg -v $versions --cache=$cache
            if not $cache { custom_clean }
            apk_uninstall $pkg.apk $build_deps.apk
        }
        'Arch Linux' => {
            use pacman.nu *
            pacman_update
            pacman_install $pkg.pacman $build_deps.pacman
            custom_install $pkg -v $versions --cache=$cache
            if not $cache { custom_clean }
            pacman_uninstall $pkg.pacman $build_deps.pacman
            pacman_clean
        }
        _ => {
            log level 5 $"Not supported on ($os)"
        }
    }
}

