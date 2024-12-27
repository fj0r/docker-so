export def --wrapped run [...cmds] {
    if ($env.dry_run? | default false) {
        log level 1 ...$cmds
    } else {
        ^$cmds.0 ...($cmds | range 1..)
    }
}
