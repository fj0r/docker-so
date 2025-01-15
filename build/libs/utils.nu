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


export def render [scope: record] {
    let tmpl = $in
    $scope
    | transpose k v
    | reduce -f $tmpl {|i,a|
        let k = if $i.k == '_' { '' } else { $i.k }
        $a | str replace --all $"{{($k)}}" ($i.v | to text)
    }
}
