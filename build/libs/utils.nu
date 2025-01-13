export def --wrapped run [...cmds --as-str] {
    log level 1 ...$cmds
    if ($env.dry_run? | default false) {
        return
    } else if $as_str {
        nu -c $cmds.0
    } else {
        if ($cmds.0 | describe -d).type == 'closure' {
            do $cmds.0
        } else {
            ^$cmds.0 ...($cmds | range 1..)
        }
    }
}

