#####################
###     utils     ###
#####################
def is-blank [txt] {
    ($txt | str replace -ra '\s' '') == ''
}

def unindent [] {
    let txt = $in | lines
    let ib = if (is-blank $txt.0) { 1 } else { 0 }
    let ie = if (is-blank ($txt | last)) { -2 } else { -1 }
    let txt = $txt | range $ib..$ie
    let indent = $txt.0 | parse --regex '^(?P<indent>\s*)' | get indent.0 | str length
    $txt
    | each {|s| $s | str substring $indent.. }
    | str join (char newline)
}

def cmd-with-args [tmpl] {
    {|args| do $tmpl ($args | str join ' ') | unindent }
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

def log [title] {
    let o = $in
    print $"<<<<<< ($title) >>>>>>"
    print ($o | to yaml)
    print $">>>>>> ($title) <<<<<<"
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
        if not ($info.ID_LIKE | parse -r '(rhel|fedora|redhat)' | is-empty) {
            'redhat'
        } else {
            $info.ID_LIKE
        }
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
    mut cargo = []
    mut stack = []
    mut go = []
    for p in $require {
        if ($p | is-record) {
            for i in ($p | transpose k v) {
                match $i.k {
                    'pip' => { $pip ++= $i.v }
                    'npm' => { $npm ++= $i.v }
                    'cargo' => { $cargo ++= $i.v }
                    'stack' => { $stack ++= $i.v }
                    'go' => { $go ++= $i.v }
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
        cargo: $cargo
        stack: $stack
        go: $go
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
            setup:    {|p| $'apt update; apt upgrade'}
            install:  {|p| $'apt install -y --no-install-recommends ($p)'}
            cargo:    {|p| $'cargo install ($p)'}
            stack:    {|p| $'stack install ($p)'}
            go:       {|p| $'go install ($p)'}
            pip:      {|p| $'pip3 install --break-system-packages --no-cache-dir ($p)'}
            npm:      {|p| $'npm install --location=global ($p)'}
            clean:    {|p| $'apt remove -y ($p)'}
            teardown: {|p| $'
                apt-get autoremove -y
                apt-get clean -y
                rm -rf /var/lib/apt/lists/*
            '}

        }
        arch: {
            setup:    {|p| $'pacman -Syu'}
            install:  {|p| $'pacman -S ($p)'}
            cargo:    {|p| $'cargo install ($p)'}
            stack:    {|p| $'stack install ($p)'}
            go:       {|p| $'go install ($p)'}
            pip:      {|p| $'pip3 install --no-cache-dir ($p)'}
            npm:      {|p| $'npm install --location=global ($p)'}
            clean:    {|p| $'pacman -R ($p)'}
            teardown: {|p| $'rm -rf /var/cache/pacman/pkg'}
        }
        alpine: {
            setup:    {|p| $'echo start'}
            install:  {|p| $'apk add ($p)'}
            cargo:    {|p| $'cargo install ($p)'}
            stack:    {|p| $'stack install ($p)'}
            go:       {|p| $'go install ($p)'}
            pip:      {|p| $'pip3 install --no-cache-dir ($p)'}
            npm:      {|p| $'npm install --location=global ($p)'}
            clean:    {|p| $'apk del ($p)'}
            teardown: {|p| $'echo stop'}
        }
        redhat: {
            setup:    {|p| $'yum update; yum upgrade'}
            install:  {|p| $'yum install ($p)'}
            cargo:    {|p| $'cargo install ($p)'}
            stack:    {|p| $'stack install ($p)'}
            go:       {|p| $'go install ($p)'}
            pip:      {|p| $'pip3 install --no-cache-dir ($p)'}
            npm:      {|p| $'npm install --location=global ($p)'}
            clean:    {|p| $'yum remove ($p)'}
            teardown: {|p| $'yum clean all'}
        }
    }
}

def resolve-other [defs versions name] {
    let o = $defs | get $name
    let d = $o.download?
    # :TODO:
    let c = $o.config?
    let v = if $name in $versions { $versions | get $name } else { "" }
    if ($d.url? | is-empty) {
        { name: $name }
    } else {
        let url = $d.url? | str replace -a '{}' $v
        let file = if ('cache' in $d) { $d.cache } else {  $url | split row '/' | last }
        let file = $file | str replace -a '{}' $v
        let extra = $d.extract?
        { name: $name, file: $file, url: $url, extra: $extra }
    }
}

def filter-other [defs versions args] {
    $args | each {|i| resolve-other $defs $versions $i}
}

def run-other [ctx] {
    let cache = $ctx.cache?
    let target = $ctx.target
    filter-other $ctx.defs $ctx.data.versions $ctx.arg
    | each {|i|
        if ($i.url? | is-empty) {
            $"# ($i.name) [not found]"
        } else {
            #let f = $"wget -O ($i.file) -c ($i.url)"
            let f = if ($cache | is-empty) {
                [$"curl -sSL ($i.url)" $"curl -sSLo ($i.file) ($i.url)"]
            } else {
                let f = [$cache $i.file] | path join
                if ($cache | find -r '^https?://' | is-empty) {
                    [$"cat ($f)" $"cp ($f) ($i.file)"]
                } else {
                    [$"curl -sSL ($f)" $"curl -sSLo ($i.file) ($f)"]
                }
            }
            let cx = $i | merge {cache: $cache, target: $target}
            $"# ($i.name)(char newline)(run-extrators [$f $cx] $i.extra)"
        }
    }
    | str join (char newline)
}

def download-other [ctx] {

}

def unzip-gen-filter [filter target] {
    let nl = (char newline)
    if ($filter | is-empty) { '' } else {
        $filter
        | each {|x|
            if ($x | describe -d | get type) == 'record' {
                $"mv ${temp_dir}/($x.file) ($target)/($x.rename)"
            } else {
                $"mv ${temp_dir}/($x) ($target)/($x)"
            }
        }
        | str join $nl
    }
}

def run-unzip [getter ctx arg] {
    let gtt = $getter.0
    let gtd = $getter.1
    let opt = if ($arg | is-empty ) { {} } else { $arg }
    let trg = [$ctx.target $opt.wrap?]
        | filter {|x| not ($x | is-empty)}
        | path join
    let fmt = if not ($opt.format? | is-empty) { $opt.format } else {
        let fn = $ctx.file | split row '.'
        let zf = $fn | last
        if ($fn | range (-2..-2) | get 0) == 'tar' {
            $"tar.($zf)"
        } else {
            $zf
        }
    }
    let decmp = match $fmt {
        'tar.gz'  => $"tar zxf"
        'tar.zst' => $"zstd -d -T0 | tar xf"
        'tar.bz2' => $"tar jxf"
        'tar.xz'  => $"tar Jxf"
        'gz'      => $"gzip -d"
        'zst'     => $"zstd -d"
        'bz2'     => $"bzip2 -d"
        'xz'      => $"xz -d"
        'zip'     => $"unzip"
        _ => "(!unknown format)"
    }
    let nl = (char newline)
    if ($fmt | str starts-with 'tar.') {
        let s = if ($opt.strip? | is-empty) { '' } else {
            $"--strip-components=($opt.strip)"
        }
        let f = (unzip-gen-filter $opt.filter? $trg)
        if $f == '' {
            $"($gtt) | ($decmp) - ($s) -C ($trg)"
        } else {
            $"temp_dir=$\(mktemp -d)($nl)($gtt) | ($decmp) - ($s) -C ${temp_dir} ($nl)($f)($nl)rm -rf ${temp_dir}"
        }
    } else if $fmt == 'zip' {
        let f = (unzip-gen-filter $opt.filter? $trg)
        [ 'opwd=$PWD'
          'temp_dir=$(mktemp -d)'
          'cd ${temp_dir}'
          $'($gtd)'
          $'($decmp) ($ctx.file)'
          (if $f == '' {
            $'mv ${temp_dir}/* ($ctx.target)'
          } else {
            $f
          })
          'cd ${opwd}'
          'rm -rf ${temp_dir}'
        ] | str join $nl
    } else {
        let n = if ($opt.filter? | is-empty) { $ctx.name } else { $opt.filter | first }
        let t = [$trg $n] | path join
        $"($gtt) | ($decmp) > ($t)"
    }
}

def extra [input act arg?] {
    match $act {
        unzip => {
            run-unzip $input.0 $input.1? $arg
        }
        from-json => {
            $input | from json
        }
        prefix => {
            $"($arg)($input)"
        }
        index => {
            $input | get $arg
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
        regexp => {
            $input | parse -r $arg | get 0?.capture0?
        }
        only-nums => {
            $input | parse -r '(?P<v>[0-9\.]+)' | get 0?.v?
        }
        github => {
            let ex = [
                {field: 'tag_name'}
                {trim: null }
                {only-nums: null} ]
            run-extrators ($input | from json) $ex
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
        do (cmd-with-args ($ctx.actions | get $ctx.os | get $ctx.act)) $ctx.arg
    }
}

def run-with-level [ctx] {
    let cmd = (run-with-other $ctx)
    if $ctx.dry_run {
        print $cmd
    } else {
        let sep = '#' | str repeat 80
        print $sep
        print $cmd
        print $sep
        sh -c $"set -eux; ($cmd)"
    }
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
    --os-type:  string
    --target:   string
    --cache:    string
    --dry-run:  bool
    --clean:    bool
] {
    let o = $in
    let argt = {
        os: $os_type
        dry_run: $dry_run
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
    run ($argt | upsert act other    | upsert arg $o.require.other?)
    run ($argt | upsert act pip      | upsert arg $o.require.pip?)
    run ($argt | upsert act npm      | upsert arg $o.require.npm?)
    run ($argt | upsert act cargo    | upsert arg $o.require.cargo?)
    run ($argt | upsert act stack    | upsert arg $o.require.stack?)
    run ($argt | upsert act go       | upsert arg $o.require.go?)
    if $clean {
        run ($argt | upsert act clean    | upsert arg $o.use.os?)
        run ($argt | upsert act teardown | upsert can_ignore false)
    }
}

export def main [
    --dry-run
    --clean
    --cache: string
    --target: string = '/usr/local'
    ...args:string@compos
] {
    let debug = if ($env.DEBUG? | is-empty) { 0 } else { $env.DEBUG | into int }
    print $"#===> $env.DEBUG = ($env.DEBUG?)"
    let act = $args.0
    let needs = $args | range 1.. | prepend default
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
            | setup $manifest.defs $data --os-type $ostype --target $target --dry-run $dry_run --clean $clean
        }
        gensh => {
            let ostype = if ($args.1? | is-empty) { $ostype } else { $args.1 }
            $pkgs
            | merge-actions $manifest.defs --os-type $ostype
            | setup $manifest.defs $data --os-type $ostype --target $target --dry-run true --clean $clean --cache $cache
        }
        update => {
            let x = (update-version $manifest.defs)
            $data
            | upsert versions ($data.versions | merge $x)
            | to yaml
            | save -f $"($env.FILE_PWD)/data.yml"
        }
        download => {
            print 'download assets'
        }
        _ => {
            echo $manifest | to json
        }

    }
}

def compos [context: string, offset: int] {
    let pkgs = open $"($env.PWD)/manifest.yml" | get pkgs | get name
    [$context $offset] | completion-generator positional [
        { value: gensh, description: 'gen sh -c', next: (
            [debian arch alpine redhat] | each {|x| { value: $x, next: $pkgs } }
        ) }
        { value: build, description: 'Dockerfile' }
        { value: update, description: 'versions' }
        { value: download, description: 'assets' }
    ]
}
