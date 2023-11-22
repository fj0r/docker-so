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
    let r = $x
        | where name in $cs
        | each {|y| calc-deps 'require' $x $y }
        | flatten
        | deduplicate {|y| $y.name }
    let u = $x
        | where name in $cs
        | each {|y| calc-deps 'use' $x $y }
        | flatten
        | deduplicate {|y| $y.name }
    {
        require: $r
        use: $u
    }
}

def resolve-pkgs [] {
    let x = $in
        | reduce -f {require: [], use: []} {|x, acc|
            mut acc = $acc
            if not ($x.require.include | is-empty) {
                $acc.require = ($acc.require | append $x.require.include)
            }
            if not ($x.use.include | is-empty) {
                $acc.use = ($acc.use | append $x.use.include)
            }
            $acc
        }
    let r = $x.require | deduplicate {|x| $x}
    let u = $x.use | deduplicate {|x| $x}
    {
        require: $r
        use: ($u | filter {|x| not ($x in $r)})
    }
}

def resolve-def [defs require --os-type:string] {
    mut os = []
    mut other = []
    mut pip = []
    mut npm = []
    for p in $require {
        if ($p | is-record) {
            for i in ($p | transpose k v) {
                match $i.k {
                    'pip' => { $pip ++= $i.v }
                    'npm' => { $npm ++= $i.v }
                }
                if $i.k == $os_type {
                    $os ++= $i.v
                }
            }
        } else if ($p in $defs) {
            $other ++= $p
        } else {
            $os ++= $p
        }
    }
    {
        os: $os
        other: $other
        pip: $pip
        npm: $npm
    }
}

def merge-actions [defs --os-type:string] {
    let d = $in
    {
        require: (resolve-def $defs $d.require --os-type $os_type)
        use: (resolve-def $defs $d.use --os-type $os_type)
    }
}

def unindent [] {
    let txt = $in | lines | range 1..-2
    let indent = $txt.0 | parse --regex '^(?P<indent>\s*)' | get indent.0 | str length
    $txt
    | each {|s| $s | str substring $indent.. }
    | str join (char newline)
}

def _p [] {
    print $in
}

def acts [] {
    {
        debian: {
            setup: [
                {||
                    '
                    apt update
                    apt upgrade
                    ' | unindent | _p
                }
                {||
                    apt update
                    apt upgrade
                }
            ]
            install: [
                {|p| $'apt install -y --no-install-recommends ($p)' | _p }
                {|p| apt install -y --no-install-recommends $p }
            ]
            pip: [
                {|p| $'pip3 install --break-system-packages --no-cache-dir ($p)' | _p }
                {|p| pip3 install --break-system-packages --no-cache-dir $p }
            ]
            npm: [
                {|p| $'npm install --location=global ($p)' | _p} 
                {|p| npm install --location=global $p } 
            ]
            teardown: [
                {|p|
                    $'
                    apt remove -y ($p)
                    apt-get autoremove -y
                    apt-get clean -y
                    rm -rf /var/lib/apt/lists/*
                    ' | unindent | _p
                }
                {|p|
                    apt remove -y ($p)
                    apt-get autoremove -y
                    apt-get clean -y
                    rm -rf /var/lib/apt/lists/*
                }
            ]
        }
        arch: {
            setup: [
                {|| 'pacman -Syu' | _p }
                {|| pacman -Syu }
            ]
            install: [
                {|p| $'pacman -S ($p)' | _p }
                {|p| pacman -S $p }
            ]
            pip: [
                {|p| $'pip3 install --no-cache-dir ($p)' | _p }
                {|p| pip3 install --no-cache-dir $p }
            ]
            npm: [
               {|p| $'npm install --location=global ($p)' | _p } 
               {|p| npm install --location=global $p } 
            ]
            teardown: [
                {|p| $'pacman -R ($p)' | _p }
                {|p| pacman -R $p}
            ]
        }
    }
}

def run [os ix can_ignore act arg?] {
    let t = (acts)
    let a = {||
        if $ix == 1 {
            let sep = '################################################################################'
            print $sep
            do ($t | get $os | get $act | get 0) $arg
            print $sep
        }
        do ($t | get $os | get $act | get $ix) $arg
    }
    if $can_ignore {
        if not ($arg | is-empty) {
            do $a
        }
    } else {
        do $a
    }
}

def setup [--os-type: string --dry-run] {
    let x = $in
    let ix = if $dry_run { 0 } else { 1 }
    run $os_type $ix false setup
    run $os_type $ix true  install ($x.require.os? | append $x.use.os?)
    run $os_type $ix true  pip $x.require.pip?
    run $os_type $ix true  npm $x.require.npm?
    run $os_type $ix true  teardown $x.use.os?
}

def compos [context: string, offset: int] {
    let argv = $context | str substring 0..$offset | split row -r "\\s+" | range 1.. | filter {|s| not ($s | str starts-with "-")}
    match ($argv | length) {
        1 => [resolve-pkgs merge-actions show-actions setup test-debian]
        _ => {
            let manifest = open $"($env.PWD)/manifest.yml"
            $manifest.layers | get name
        }
    }
}

export def main [...args:string@compos] {
    let act = $args.0
    let layers = $args | range 1..
    let manifest = open $"($env.FILE_PWD)/manifest.yml"
    let ostype = (os-type)
    let pkgs = $manifest.layers
        | sort-deps $layers
        | resolve-pkgs
    match $act {
        resolve-pkgs => {
            $pkgs | to yaml
        }
        merge-actions => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | to yaml
        }
        show-actions => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup --os-type $ostype --dry-run
        }
        setup => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup --os-type $ostype
        }
        test-debian => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup --os-type 'debian' --dry-run
        }
        _ => {
            echo $manifest | to json
        }

    }
}
