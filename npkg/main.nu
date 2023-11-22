#####################
###     utils     ###
#####################
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

######################
###      deps      ###
######################
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


######################
###      acts      ###
######################
def other-acts [] {
    [
        {|d, p| print $"---($p)" }
        {|d, p| print $"===($p)" }
    ]
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

#####################
###      run      ###
#####################
def run-with-other [os act lv arg defs o t] {
    if $act == 'other' {
        do ($o | get $lv) $defs $arg
    } else {
        do ($t | get $os | get $act | get $lv) $arg
    }
}

def run-with-level [os act lv arg defs o t] {
    if $lv == 1 {
        let sep = '################################################################################'
        print $sep
        run-with-other $os $act 0 $arg $defs $o $t
        print $sep
    }
    run-with-other $os $act $lv $arg $defs $o $t
}

def run [os lv defs can_ignore act arg?] {
    let t = (acts)
    let o = (other-acts)
    if $can_ignore {
        if not ($arg | is-empty) {
            run-with-level $os $act $lv $arg $defs $o $t
        }
    } else {
        run-with-level $os $act $lv $arg $defs $o $t
    }
}

def setup [defs --os-type: string --dry-run] {
    let x = $in
    let lv = if $dry_run { 0 } else { 1 }
    run $os_type $lv null  false setup
    run $os_type $lv null  true  install ($x.require.os? | append $x.use.os?)
    run $os_type $lv null  true  pip $x.require.pip?
    run $os_type $lv null  true  npm $x.require.npm?
    run $os_type $lv $defs true  other $x.require.other?
    run $os_type $lv null  true  teardown $x.use.os?
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
            | setup $manifest.defs --os-type $ostype --dry-run
        }
        setup => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup $manifest.defs --os-type $ostype
        }
        test-debian => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup $manifest.defs --os-type 'debian' --dry-run
        }
        _ => {
            echo $manifest | to json
        }

    }
}
