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

export def download_info [o, version] {
    let url = $o.url | str replace -a '{{version}}' $version
    let file = if ($o.filename? | is-empty) {
        $url | path basename
    } else {
        $o.filename | str replace -a '{{version}}' $version
    }
    let dir = ([$env.FILE_PWD assets] | path join)
    {
        dir: $dir
        file: $file
        url: $url
    }
}
