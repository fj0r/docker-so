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
    let o = $in
    let r = $o
        | where name in $cs
        | each {|y| calc-deps 'require' $o $y }
        | flatten
        | deduplicate {|y| $y.name }
    let u = $o
        | where name in $cs
        | each {|y| calc-deps 'use' $o $y }
        | flatten
        | deduplicate {|y| $y.name }
    {
        require: $r
        use: $u
    }
}

def resolve-pkgs [] {
    let o = $in
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
    let r = $o.require | deduplicate {|x| $x}
    let u = $o.use | deduplicate {|x| $x}
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

def run-other [lv defs arg] {
    print $"---($arg)"
    if $lv == 1 {
        print $"===($arg)"
    }
}


def extra [input act arg?] {
    match $act {
        from-json => {
            $input | from json
        }
        prefix => {
            $"($arg)($input)"
        }
        field => {
            if not ($arg | is-empty) {
                if $arg in $input {
                    $input | get $arg
                } else {
                    null
                }
            } else {
                $input
            }
        }
        trim => {
            $input | str trim
        }
        only-nums => {
            $input | parse -r '(?P<v>[0-9\.]+)' | get 0.v
        }
        github => {
            let ex = [
                {field: 'tag_name'}
                {trim: null }
                {only-nums: null} ]
            run-extrators ($input | from json) $ex
        }
        unzip => {
            print 'no impl!!!!!!!!!!!'
        }
    }
}

def run-extrators [input extract] {
    $extract
    | reduce -f $input {|x, acc|
        let r = $x
            | transpose k v
            | each {|y| extra $acc $y.k $y.v }
            | get 0
        $r
    }
}

def update-version [manifest] {
    mut data = {}
    for item in ($manifest | transpose k v) {
        let i = $item.v?
        print $'-------------------($item.k)'
        let url = $i.version?.url?
        let ext = $i.version?.extract
        if not ($url | is-empty) {
            let ver = (run-extrators (curl -sSL $url) $ext)
            print $ver
            $data = ($data | upsert $item.k $ver)
        }
    }
    $data
}

#####################
###      run      ###
#####################
def run-with-other [os act lv arg defs t] {
    if $act == 'other' {
        run-other $lv $defs $arg
    } else {
        do ($t | get $os | get $act | get $lv) $arg
    }
}

def run-with-level [os act lv arg defs t] {
    if $lv == 1 {
        let sep = '################################################################################'
        print $sep
        run-with-other $os $act 0 $arg $defs $t
        print $sep
    }
    run-with-other $os $act $lv $arg $defs $t
}

def run [os lv defs data can_ignore act arg?] {
    let t = (acts)
    if $can_ignore {
        if not ($arg | is-empty) {
            run-with-level $os $act $lv $arg $defs $t
        }
    } else {
        run-with-level $os $act $lv $arg $defs $t
    }
}

def setup [defs data --os-type: string --dry-run] {
    let o = $in
    let lv = if $dry_run { 0 } else { 1 }
    run $os_type $lv null  null  false setup
    run $os_type $lv null  null  true  install ($o.require.os? | append $o.use.os?)
    run $os_type $lv null  null  true  pip $o.require.pip?
    run $os_type $lv null  null  true  npm $o.require.npm?
    run $os_type $lv $defs $data true  other $o.require.other?
    run $os_type $lv null  null  true  teardown $o.use.os?
}

def compos [context: string, offset: int] {
    let argv = $context | str substring 0..$offset | split row -r "\\s+" | range 1.. | filter {|s| not ($s | str starts-with "-")}
    match ($argv | length) {
        1 => [
            resolve-pkgs
            merge-actions
            show-actions
            setup
            test-debian
            update-version
        ]
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
    let data = open $"($env.FILE_PWD)/data.yml"
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
            | setup $manifest.defs $data --os-type $ostype --dry-run
        }
        setup => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup $manifest.defs $data --os-type $ostype
        }
        test-debian => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup $manifest.defs $data --os-type 'debian' --dry-run
        }
        update-version => {
            let x = (update-version $manifest.defs)
            $data
            | upsert versions ($data.versions | merge $x)
            | to yaml
            | save -f $"($env.FILE_PWD)/data.yml"
        }
        _ => {
            echo $manifest | to json
        }

    }
}
