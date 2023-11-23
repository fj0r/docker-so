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

def 'str repeat' [n] {
    let o = $in
    mut a = ''
    if $n < 1 { return '' }
    for _ in 1..$n {
        $a = $"($a)($o)"
    }
    $a
}

def _p [] {
    print $in
}

def log [title] {
    let o = $in
    print $"======($title)======"
    print ($o | to yaml)
    print $"======($title)======"
    print $"(char newline)"
}

def 'bits check' [bit] {
    ( $in | bits and  (1 | bits shl $bit) ) > 0
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
def calc-deps [field pkgs comp] {
    let dep = if ($field in $comp) and (not ($comp | get $field | is-empty)) {
        $pkgs
        | where name in ($comp | get $field)
        | each {|y| calc-deps $field $pkgs $y}
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
            clean: [
                {|p|
                    $'
                    apt remove -y ($p)
                    ' | unindent | _p
                }
                {|p|
                    apt remove -y ($p)
                }
            ]
            teardown: [
                {||
                    $'
                    apt-get autoremove -y
                    apt-get clean -y
                    rm -rf /var/lib/apt/lists/*
                    ' | unindent | _p
                }
                {||
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
            clean: [
                {|p| $'pacman -R ($p)' | _p }
                {|p| pacman -R $p}
            ]
            teardown: [
                {|| $'rm -rf /var/cache/pacman/pkg' | _p }
                {||
                    rm -rf /var/cache/pacman/pkg
                }
            ]
        }
    }
}

def run-other [ctx] {
    print $"---($ctx.arg)"
    if $ctx.level == 1 {
        print $"===($ctx.arg)"
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
        print $'==> ($item.k)'
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
def run-with-other [ctx] {
    if $ctx.act == 'other' {
        run-other $ctx
    } else {
        do ($ctx.actions | get $ctx.os | get $ctx.act | get $ctx.level) $ctx.arg
    }
}

def run-with-level [ctx] {
    if $ctx.level == 1 {
        print ($"(char newline)" | str repeat 10)
        let sep = '#' | str repeat 80
        print $sep
        run-with-other ($ctx | upsert level 0)
        print $sep
    }
    run-with-other $ctx
}

def run [ctx] {
    let t = (acts)
    if $ctx.can_ignore {
        if not ($ctx.arg | is-empty) {
            run-with-level ($ctx | upsert actions $t)
        }
    } else {
        run-with-level ($ctx | upsert actions $t)
    }
}

def setup [
    defs
    data
    --os-type:string
    --target:string
    --cache:bool
    --dry-run:bool
] {
    let o = $in
    let lv = if $dry_run { 0 } else { 1 }
    let argt = {
        os: $os_type
        level: $lv
        defs: $defs
        data: $data
        target: $target
        cache: $cache
        can_ignore: true
        act: null
        arg: null
    }
    run ($argt | upsert act setup    | upsert can_ignore false)
    run ($argt | upsert act install  | upsert arg ($o.require.os? | append $o.use.os?))
    run ($argt | upsert act pip      | upsert arg $o.require.pip?)
    run ($argt | upsert act npm      | upsert arg $o.require.npm?)
    run ($argt | upsert act other    | upsert arg $o.require.other?)
    run ($argt | upsert act clean    | upsert arg $o.use.os?)
    run ($argt | upsert act teardown | upsert can_ignore false)
}

def compos [context: string, offset: int] {
    let argv = $context | str substring 0..$offset | split row -r "\\s+" | range 1.. | filter {|s| not ($s | str starts-with "-")}
    match ($argv | length) {
        1 => [
            setup
            test-debian
            update-version
        ]
        _ => {
            let manifest = open $"($env.PWD)/manifest.yml"
            $manifest.pkgs | get name
        }
    }
}

export def main [
    --cache
    --dry-run
    --target: string
    ...args:string@compos
] {
    let debug = if ($env.DEBUG? | is-empty) { 0 } else { $env.DEBUG | into int }
    print $"===> $env.DEBUG = ($env.DEBUG?)"
    let act = $args.0
    let needs = $args | range 1..
    let manifest = open $"($env.FILE_PWD)/manifest.yml"
    let data = open $"($env.FILE_PWD)/data.yml"
    let ostype = (os-type)
    let pkgs = $manifest.pkgs | sort-deps $needs
    if ($debug | bits check 0) { $pkgs | log 'sort-deps' }
    let pkgs = $pkgs | resolve-pkgs
    if ($debug | bits check 1) { $pkgs | log 'resolve-pkgs' }
    let acts = $pkgs | merge-actions $manifest.defs --os-type $ostype
    if ($debug | bits check 2) { $acts | log 'merge-actions' }
    match $act {
        setup => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup $manifest.defs $data --os-type $ostype --target /usr/local --dry-run $dry_run
        }
        test-debian => {
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup $manifest.defs $data --os-type 'debian' --dry-run true
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
