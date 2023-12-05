#####################
###     utils     ###
#####################

let no = {|x| not $x }

def flip [x, ...a] { do $x $in $a }

def tap [pred act] {
    let o = $in
    if (do $pred $o) {
        do $act $o
    } else {
        $o
    }
}

def not-empty [] {
    not ($in | is-empty)
}

def not-in [m] {
    not ($m in $in)
}

def record-to-struct [$k $v] {
    $in | transpose $k $v | get 0
}

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

def mkact [action context body] {
    { action: $action, context: $context } | merge $body
}

def log [title=''] {
    let o = $in
    print $"<<<<<< ($title) >>>>>>"
    print ($o | to yaml)
    print $">>>>>> ($title) <<<<<<"
    print $"(char newline)"
    $o
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
        if ($n in $ex | flip $no) {
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
        if ($info.ID_LIKE | parse -r '(rhel|fedora|redhat)' | is-empty | flip $no) {
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
def calc-dep-require [pkgs comp] {
    let dep = if ($comp.require? | is-empty) { [] } else {
        $pkgs
        | where name in $comp.require
        | each {|y| calc-dep-require $pkgs $y}
        | flatten
    }
    $comp | append $dep
}

def calc-dep-use [pkgs comp] {
    let r = if ($comp.require? | not-empty) { $comp.require } else { [] }
    let r = $r | append (if ($comp.use? | not-empty) { $comp.use } else { [] })
    $comp
    | append (
        if ($r | is-empty) { [] } else {
            $pkgs
            | where name in $r
            | each {|y| calc-dep-use $pkgs $y}
            | flatten
        }
    )
}

def sort-deps [cs] {
    let o = $in
    let r = $o
        | where name in $cs
        | each {|y| calc-dep-require $o $y }
        | flatten
        | deduplicate {|y| $y.name }
    let u = $o
        | where name in $cs
        | each {|y| calc-dep-use $o $y }
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
            for i in $x.require? {
                if ($i.include? | not-empty) {
                    $acc.require = ($acc.require | append $i.include)
                }
            }
            for i in $x.use? {
                if ($i.include? | not-empty) {
                    $acc.use = ($acc.use | append $i.include)
                }
            }
            $acc
        }
    let r = $o.require | deduplicate {|x| $x}
    let u = $o.use | deduplicate {|x| $x}
    {
        require: $r
        use: ($u | filter {|x| $x in $r | flip $no })
    }
}

def resolve-def [defs require --os-type:string] {
    mut os = []
    mut recipe = []
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
            $recipe ++= $p
        } else {
            $os ++= $p
        }
    }
    {
        os: $os
        recipe: $recipe
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


#####################
###      gen      ###
#####################
def resolve-filename [name version] {
    $in
    | str replace -a '%v' $version
    | str replace -a '%n' $name
    | str replace -a '%t' (date now | format date '%Y%m%d')
}

def resolve-tar-filter [workdir filter target name version] {
    if ($filter | is-empty) { [] } else {
        $filter
        | each {|x|
            if ($x | describe -d | get type) == 'record' {
                let tf = $x.file | resolve-filename $name $version
                let fn = $tf | split row '/' | last
                let nf = $x.rename | resolve-filename $name $version
                let trg = if ($workdir | is-empty) { $target } else { $workdir }
                [$tf $'($trg)/($fn)' $'($trg)/($nf)']
            } else {
                let r = $x | resolve-filename $name $version
                [$r]
            }
        }
    }
}

def resolve-zip-filter [workdir filter target name version strip] {
    let nl = (char newline)
    let strip = if ($strip | is-empty) { 0 } else { $strip }
    if ($filter | is-empty) {
        [mkact mv null { from: $"${temp_dir}/*" to: $target }]
    } else {
        $filter
        | each {|x|
            if ($x | describe -d | get type) == 'record' {
                mkact mv null {from: $"${temp_dir}/($x.file)" to: $"($target)/($x.rename)"}

            } else {
                let f = $x | resolve-filename $name $version
                let t = $f | split row '/' | range $strip.. | str join '/'
                mkact mv null {from: $"($workdir)/($f)" to: $"($target)/($t)" }
            }
        }
    }
}

def resolve-unzip [getter ctx] {
    let trg = [$ctx.target $ctx.wrap?]
        | filter {|x| $x | not-empty }
        | path join
    let fmt = if ($ctx.format? | not-empty ) { $ctx.format } else {
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
    let md = if ($ctx.workdir? | is-empty) {
        mkact 'mkdir' $ctx.name { target: $trg temp: false }
    } else {
        mkact 'mkdir' $ctx.name { target: $ctx.workdir temp: true }
    }
    if ($fmt | str starts-with 'tar.') {
        let f = (resolve-tar-filter $ctx.workdir $ctx.filter? $trg $ctx.name $ctx.version?)
            | reduce -f {fs: [], mv: []} {|x, acc|
                let acc = if ($x.0? | is-empty) { $acc } else {
                    $acc | update fs ($acc.fs | append $x.0?)
                }
                let acc = if ($x.1? | is-empty) { $acc } else {
                    $acc | update mv ($acc.mv | append (mkact mv null {from: $x.1 to: $x.2}))
                }
                $acc
            }
        let u = $getter | merge {
            decompress: $decmp
            target: $trg
            strip: $ctx.strip?
            filter: $f.fs
        }
        [$md $u ] | append $f.mv
    } else if $fmt == 'zip' {
        if ($ctx.workdir? | is-empty) {
            mkact log $ctx.workdir { event: "workdir should not empty" }
        }
        let f = (resolve-zip-filter $ctx.workdir $ctx.filter? $trg $ctx.name $ctx.version? $ctx.strip?)
        let u = $getter | merge {
            decompress: $decmp
            target: $ctx.file
            workdir: $ctx.workdir
        }
        #let r = mkact 'rm' null { target: $"/tmp/($ctx.name)" }
        [$md $u] | append $f
    } else {
        let n = if ($ctx.filter? | is-empty) { $ctx.name } else { $ctx.filter | first }
        let t = [$trg $n] | path join
        let u = $getter | merge {
            decompress: $decmp
            target: $t
            redirect: true
        }
        [$md $u]
    }
}

def resolve-download-filename [ctx] {
    let ver = $ctx.version
    let name = $ctx.name
    let fn = $ctx.filename?
    let url = $ctx.url | resolve-filename $name $ver
    let file = if ($fn | is-empty) {  $url | split row '/' | last } else { $fn }
    let file = $file | resolve-filename $name $ver
    let workdir = if ($ctx.workdir? | is-empty) { null } else {
        $ctx.workdir | resolve-filename $name $ver
    }
    { url: $url, file: $file, workdir: $workdir }
}

def gen-download [ctx] {
    let cache = $ctx.cache?
    let target = $ctx.target?
    if ($ctx.url? | is-empty) {
        mkact log $ctx.name { event: "not found" }
    } else {
        let x = resolve-download-filename $ctx
        let f = if ($cache | is-empty) {
            mkact 'download' $ctx.name { url: $x.url target: $x.file}
        } else {
            let f = [$cache $x.file] | path join
            let a = mkact 'download' $ctx.name {
                    url: $f
                    target: $x.file
                }
            if ($cache | find -r '^https?://' | is-empty) {
                $a | upsert cache true
            } else { $a }
        }
        let cx = $ctx | merge {
            file: $x.file
            cache: $cache
            target: $target
            workdir: $x.workdir
        }
        resolve-unzip $f $cx
    }
}

def gen-git [$ctx] {
    mkact git $ctx.name {
        url: $ctx.url
        target: $ctx.target
        depth: 2
        log: true
    }
}

def gen-shell [it type] {
    let args = match $type {
            'shell' => $it.cmd
            'exec' => [($it.cmd | str join ' ')]
        }
    mkact 'shell' null {
        context: $it.name
        workdir: $it.workdir?
        runner: $it.runner?
        args: $args
    }
}

def resolve-recipe [ctx name] {
    let vs = $ctx.data.versions
    let version = if $name in $vs { $vs | get $name } else { "" }
    let df = $ctx.defs | get $name
    let workdir = $df.workdir?
    let install = $df.install?
    let install = if ($install | is-empty) { [] } else { $install }
    $install
    | each {|x|
        let r = $x | record-to-struct type data
        let d = if ($r.data? | is-empty) { {} } else { $r.data }
        {
            cache: $ctx.cache?
            target: $ctx.target?
            workdir: $workdir
        }
        | merge $d
        | merge {
            type: $r.type
            name: $name
            version: $version
        }
    }
}

def gen-recipe-env [ctx] {
    $ctx.args
    | reduce -f [] {|i, acc|
        let e = ($ctx.defs | get $i).env?
        if ($e | is-empty) { $acc } else {
            let es = $e
            | transpose k v
            | each {|x|
                if ($x.k | str starts-with '+') {
                    let n = $x.k | str substring 1..
                    mkact 'env-pre' $i { key: $n value: $x.v }
                } else {
                    mkact 'env' $i { key: $x.k value: $x.v }
                }
            }
            $acc | append $es
        }
    }
}

def gen-recipe [ctx] {
    $ctx.args
    | each {|i| resolve-recipe $ctx $i }
    | flatten
    | each {|i|
        match $i.type {
            download => {
                gen-download $i
            }
            git => {
                gen-git $i
            }
            shell => {
                gen-shell $i 'shell'
            }
            exec => {
                gen-shell $i 'exec'
            }
        }
    }
    | flatten
}

def gen-cmd [ctx] {
    if $ctx.can_ignore and ($ctx.args | is-empty) {
        null
    } else if $ctx.act == 'recipe' {
        [
            (gen-recipe-env $ctx)
            (gen-recipe $ctx)
        ] | flatten
    } else {
        mkact 'common' $ctx.act { os: $ctx.os args: $ctx.args }
    }
}

def gen-stage [o clean default] {
    let setup = gen-cmd ($default | upsert act setup   | upsert can_ignore false)
    let instl = gen-cmd ($default | upsert act install | upsert args ($o.require.os? | append $o.use.os?))
    let recip = gen-cmd ($default | upsert act recipe  | upsert args $o.require.recipe?)
    let other = [pip npm cargo stack go]
    | each {|x| gen-cmd ($default | upsert act $x | upsert args ($o.require | get $x))}
    let final = if $clean {[
        (gen-cmd ($default | upsert act clean    | upsert args $o.use.os?))
        (gen-cmd ($default | upsert act teardown | upsert can_ignore false))
    ]} else {[]}
    [$setup $instl] | append $recip | append $other | append $final
}

def optm-stage [] {
    let x = $in
    mut o = []
    mut mkdir = []
    mut tempdir = []
    for i in $x {
        match $i.action {
            mkdir => {
                if ($i.temp? | default false) {
                    if not ($i.target in $tempdir) {
                        $tempdir ++= [$i.target]
                        $o ++= [$i]
                    } else {
                        let a = mkact log $i.context {
                            level: 'warn'
                            event: 'temp already exists'
                            target: $i.target
                        }
                        $o ++= [$a]
                    }

                } else {
                    if not ($i.target in $mkdir) {
                        $mkdir ++= [$i.target]
                        $o ++= [$i]
                    }
                }
            }
            _ => {
                $o ++= [$i]
            }
        }
    }
    for i in $tempdir {
        let a = mkact rm null {target: $i}
        $o ++= [$a]
    }
    $o
}
#####################
###      run      ###
#####################
def interpret-common [os act] {
    let default = {
        setup:    {|p| $'echo start'}
        teardown: {|p| $'echo stop'}
        cargo:    {|p| $'cargo install ($p)'}
        stack:    {|p| $'stack install ($p)'}
        go:       {|p| $'go install ($p)'}
        pip:      {|x| $'pip3 install --break-system-packages --no-cache-dir ($x)'}
        npm:      {|p| $'npm install --location=global ($p)'}
    }
    let diff = {
        debian: {
            setup:    {|x| $'apt update; apt upgrade -y'}
            install:  {|x| $'DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends ($x)'}
            clean:    {|x| $'apt remove -y ($x)'}
            teardown: {|x| $'
                apt-get autoremove -y
                apt-get clean -y
                rm -rf /var/lib/apt/lists/*
            '}

        }
        arch: {
            setup:    {|x| $'pacman -Syy; pacman -Syu'}
            install:  {|x| $'pacman -S ($x)'}
            clean:    {|x| $'pacman -R ($x)'}
            teardown: {|x| $'rm -rf /var/cache/pacman/pkg'}
        }
        alpine: {
            install:  {|x| $'apk add ($x)'}
            clean:    {|x| $'apk del ($x)'}
        }
        redhat: {
            setup:    {|x| $'yum update; yum upgrade'}
            install:  {|x| $'yum install ($x)'}
            pip:      {|p| $'pip3 install --no-cache-dir ($p)'}
            clean:    {|x| $'yum remove ($x)'}
            teardown: {|x| $'yum clean all'}
        }
    }
    $default | merge ($diff | get $os) | get $act
}

def interpret-recipe [act] {
    let default = {
        log:      {|x| $"echo '($x)'"}
        mkdir:    {|x| $"mkdir -p ($x.target)"}
        git:      {|x| [
                        $"git clone --depth=($x.depth) ($x.url) ($x.target)"
                        $"cd ($x.target)"
                        "git log -1 --date=iso"
                       ] | str join (char newline)
                  }
        shell:    {|x| $x.args
                        | tap {|y| $x.runner? | not-empty } {|y|
                            let z = $y | str join ';'
                            $"($x.runner) '($z)'"
                        }
                        | tap {|y| $x.workdir? | not-empty } {|y|
                            [
                                $"cd ($x.workdir)"
                                $y
                            ] | str join (char newline)
                        }
                  }
        mv:       {|x| $"mv ($x.from) ($x.to)" }
        rm:       {|x| $"rm -rf ($x.target)" }
        env:      {|x| $"export ($x.key)=($x.value)(char newline)echo '($x.key)=($x.value)' >> /etc/environment"}
        env-pre:  {|x| [ $"export ($x.key)='($x.value):${($x.key)}'"
                         $"echo '($x.key)=($x.value):${($x.key)}' >> /etc/environment"
                       ] | str join (char newline)
                  }
        download: {|x|
                        if ($x.workdir? | not-empty) {
                            # zip
                            let f = if ($x.cache? | is-empty) {
                                $'wget -c ($x.url) -O ($x.target)'
                            } else {
                                $'cp ($x.url) ($x.target)'
                            }
                            [
                            $"cd ($x.workdir)"
                            $f
                            $"($x.decompress) ($x.target)"
                            ]
                            | str join (char newline)
                        } else if ($x.redirect? | not-empty) {
                            # xx -d
                            let f = if ($x.cache? | is-empty) { 'curl -sSL' } else { 'cat' }
                            $"($f) ($x.url) | ($x.decompress) > ($x.target)"
                        } else {
                            # tar
                            let f = if ($x.cache? | is-empty) { 'curl -sSL' } else { 'cat' }
                            let c = $"-C ($x.target)"
                            let s = if ($x.strip? | is-empty) { '' } else {
                                $"--strip-components=($x.strip)"
                            }
                            let o = $x.filter | str join ' '
                            [$f $x.url '|' $x.decompress '-' $s $c $o]
                            | filter {|x| $x | not-empty }
                            | str join ' '
                        }
                  }
    }
    if ($act in $default) {
        $default | get $act
    } else {
        {|args| $"### no ($act)" }
    }
}

def run-stage [dry_run] {
    for x in $in {
        let stage = if $x.action == 'common' {
            let title = $"#################### ($x.context) ####################"
            let cmd = do (cmd-with-args (interpret-common $x.os $x.context)) $x.args
            [$title $cmd]
        } else {
            let title = $"### ($x.context)[($x.action)]"
            let cmd = do (interpret-recipe $x.action) $x
            [$title $cmd]
        }
        | str join (char newline)

        if $dry_run {
            print $stage
        } else {
            sh -c $"set -eux(char newline)($stage)"
        }
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
    gen-stage $in $clean {
        os: $os_type
        dry_run: $dry_run
        defs: $defs
        data: $data
        target: $target
        cache: $cache
        can_ignore: true
        act: null
        args: null
    }
    | optm-stage
    | run-stage $dry_run
}

#####################
###    version    ###
#####################
def extract [input act args?] {
    match $act {
        from-json => {
            $input | from json
        }
        prefix => {
            $"($args)($input)"
        }
        index => {
            $input | get $args
        }
        field => {
            if ($args | is-empty) {
                $input
            } else {
                if $args in $input {
                    $input | get $args
                } else {
                    null
                }
            }
        }
        trim => {
            $input | str trim
        }
        regexp => {
            $input | parse -r $args | get 0?.capture0?
        }
        only-nums => {
            $input | parse -r '(?P<v>[0-9\.\-]+)' | get 0?.v?
        }
        github => {
            let ex = [
                {field: 'tag_name'}
                {trim: null }
                {only-nums: null} ]
            run-extractors ($input | from json) $ex
        }
    }
}

def run-extractors [input extractors] {
    $extractors
    | reduce -f $input {|x, acc|
        let r = $x | record-to-struct k v
        extract $acc $r.k $r.v
    }
}

def update-version [manifest] {
    mut data = {}
    for item in ($manifest | transpose k v) {
        let i = $item.v?
        print $'==> ($item.k)'
        let url = $i.version?.url?
        let ext = $i.version?.extract?
        let header = $i.version?.header?
        let header = if ($header | is-empty) { [] } else {
            $header | transpose k v | each {|x| [-H $"($x.k): ($x.v)"] } | flatten
        }
        if ($url | not-empty) {
            let ver = (run-extractors (curl -sSL $header $url) $ext)
            print $ver
            $data = ($data | upsert $item.k $ver)
        }
    }
    $data
}

#####################
###    download   ###
#####################
def download-recipe [defs versions --cache:string] {
    mkdir /tmp/npkg
    let ctx = {
        defs: $defs
        data: { versions: $versions }
        cache: $cache
    }
    for y in ($defs | columns | each {|x| resolve-recipe $ctx $x }) {
        for i in $y {
            if $i.type == 'download' {
                if ($i.url? | is-empty) {
                    print $'# ($i.name)'
                } else {
                    let x = resolve-download-filename $i
                    print $'# download ($x.file)'
                    let t = [$cache $x.file] | filter {|x| $x | not-empty } | path join
                    if ($cache | find -r '^https?://' | is-empty) {
                        wget -c ($x.url) -O ($t)
                    } else {
                        let lt = ['/tmp/npkg' $x.file] | path join
                        wget -c ($x.url) -O ($lt)
                        curl -T ($lt) ($t)
                    }
                }
            }
        }
    }
    rm -rf /tmp/npkg
}

#####################
###      main     ###
#####################
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
            download-recipe $manifest.defs $data.versions --cache $cache
        }
        debug => {
            $manifest.pkgs | sort-deps1 $needs | log
        }
        _ => {
            echo $manifest | to json
        }

    }
}

def compos [context: string, offset: int] {
    let pkgs = open $"($env.PWD)/manifest.yml" | get pkgs | get name
    [$context $offset] | completion-generator from tree [
        { value: gensh, description: 'gen sh -c', next: (
            [debian arch alpine redhat] | each {|x| { value: $x, next: $pkgs } }
        ) }
        { value: build, description: 'Dockerfile' }
        { value: update, description: 'versions' }
        { value: download, description: 'assets' }
    ]
}
