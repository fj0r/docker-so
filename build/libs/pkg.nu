use log.nu

export def install [pkg --act: closure] {
    let p = $pkg | flatten | uniq
    log level 4 install ...$p
    do $act $p
}

export def uninstall [pkg, deps, --act: closure] {
    let p = $deps | filter { $in not-in $pkg }
    if ($p | is-not-empty) {
        log level 4 remove ...$p
        do $act $p
    }
}

export def --wrapped dry-run [...cmds] {
    if ($env.dry_run? | default false) {
        log level 1 ...$cmds
    } else {
        ^$cmds.0 ...($cmds | range 1..)
    }
}
