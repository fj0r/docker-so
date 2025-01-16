export def --wrapped run [...cmds --as-str] {
    let dry_run = $env.dry_run? | default false
    if ($cmds.0 | describe -d).type == 'closure' {
        log level 1 (view source $cmds.0)
        if $dry_run { return }
        do $cmds.0
    } else {
        log level 1 ...$cmds
        if $dry_run { return }
        if $as_str {
            nu -c $cmds.0
        } else {
            ^$cmds.0 ...($cmds | range 1..)
        }
    }
}


export def render [vars: record] {
    let tmpl = $in
    let v = $tmpl
    | parse -r '(?<!{){{(?<v>[^{}]*?)}}(?!})'
    | get v
    | uniq

    $v
    | reduce -f $tmpl {|i, a|
        let k = $i | str trim
        let k = if ($k | is-empty) { '_' } else { $k }
        $a | str replace --all $"{{($i)}}" ($vars | get $k | to text)
    }
}
