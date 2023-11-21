def deduplicate [getter] {
    let list = $in
    mut ex = []
    mut rt = []
    for i in $list {
        let n = do $getter $i
        if not ($n in $ex) {
            $ex ++= $n
            $rt ++= $i
        }
    }
    $rt
}

def is-record [] {
    ($in | describe -d).type == 'record'
}

def os-type [] {
    let info = cat /etc/os-release
    | lines
    | reduce -f {} {|x, acc|
        let a = $x | split row '='
        $acc | upsert $a.0 ($a.1| str replace -a '"' '')
    }
    if 'ID_LIKE' in $info {
        $info.ID_LIKE
    } else {
        $info.ID
    }
}

def calc-deps [field layers comp] {
    let dep = if ($field in $comp) and (not ($comp | get $field | is-empty)) {
        $layers
        | where name in ($comp | get $field)
        | each {|y| calc-deps $field $layers $y}
        | flatten
    } else {
        []
    }
    $comp | append $dep
}

def sort-deps [cs] {
    let x = $in
    $x
        | where name in $cs
        | each {|y| calc-deps 'require' $x $y }
        | flatten
        | deduplicate {|y| $y.name }
}

def resolve-pkgs [] {
    $in
        | reduce -f [] {|x, acc|
            if not ($x.include | is-empty) {
                $acc | append $x.include
            } else {
                $acc
            }
        }
        | deduplicate {|x| $x}
}


def difference-set [a, ...b] {
    $b | filter {|x| not ($x in $a)}
}

def merge-actions [defs] {
    let x = $in
    let dist = (os-type)
    mut rm = {}
    mut os = []
    mut other = []
    mut pip = []
    mut npm = []
    mut deps = []
    for p in $x {
        if ($p | is-record) {
            for i in ($p | transpose k v) {
                match $i.k {
                    'pip' => { $pip ++= $i.v }
                    'npm' => { $npm ++= $i.v }
                }
                if $i.k == $dist {
                    $os ++= $i.v
                }
            }
        } else if ($p in $defs) {
            $other ++= $p
        } else {
            $os ++= $p
        }
    } 
    #if not ($pip | is-empty) {
    #    $deps ++= ( difference-set $os $depm.python )
    #}
    #if not ($npm | is-empty) {
    #    $deps ++= ( difference-set $os $depm.javascript)
    #}
    #if not ($other | is-empty) {
    #    $deps ++= ( difference-set $os $depm.wget)
    #}
    {
        os: $os
        other: $other
        pip: $pip
        npm: $npm
        deps: $deps
    }
}

def setup [] {
    $in
}

def compos [context: string, offset: int] {
    let argv = $context | str substring 0..$offset | split row -r "\\s+" | range 1.. | filter {|s| not ($s | str starts-with "-")}
    match ($argv | length) {
        1 => [resolve-pkgs]
        _ => {
            let manifest = open $"($env.PWD)/manifest.yml"
            $manifest.layers | get name
        }
    }
}

export def main [...args:string@compos, -m] {
    let act = $args.0
    let layers = $args | range 1..
    let manifest = open $"($env.FILE_PWD)/manifest.yml"
    let pkgs = $manifest.layers
        | sort-deps $layers
        | resolve-pkgs
    match $act {
        resolve-pkgs => {
            $pkgs | to yaml
        }
        merge-actions => {
            $pkgs
            | merge-actions $manifest.defs
            | to yaml
        }
        setup => {
            $pkgs
            | merge-actions $manifest.defs
            | setup
            | to yaml

        }
        _ => {
            echo $manifest | to json
        }

    }
}
