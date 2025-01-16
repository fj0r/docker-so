use log.nu
use utils.nu *
use extractor.nu *
use installer.nu *

export def custom_install [
    pkg
    -v: record
    --cache
] {
    for o in $env.custom_list {
        if $o in $pkg {
            for i in ($pkg | get $o) {
                let j = $i | upsert type $o
                log level 3 {type: $j.type, group: $j.group?, name: $j.name?}
                run_action $j -v $v --cache=$cache
            }
        }
    }
}

export def custom_clean [] {
    let dir = ([$env.FILE_PWD assets] | path join)
    cd $dir
    let files = ls | get name
    log level 4 clean $files
    if not ($env.dry_run? | default false) {
        rm -rf ...$files
    }
}

def run_action [
    o
    -v: record
    --cache
] {
    match $o.type {
        http => {
            let version = if (($o.name? | default '') in $v) {
                $v | get $o.name
            } else if 'version' in $o {
                get-version $o.version $o.name? --cache=$cache
            }
            log level 1 {group: $o.group, version: $version} update version

            for i in $o.install {
                let dl = download_info $i {version: $version, ...$env}
                log level 1 {pwd: $env.PWD, url: $dl.url} download
                download $dl

                log level 1 ($i | upsert filename $dl.file | reject url?) install $version
                install $i $dl
            }
        }
        git => {
            let dist = if ($o.dist | str starts-with '/') {
                $o.dist
            } else {
                [$env.HOME $o.dist] | path join
            }
            log level 1 {dist: $dist}
            run {
                if not ($dist | path exists) { mkdir $dist }
                git clone --depth=3 $o.url $dist
            }
        }
        cmd => {
            for c in $o.cmd {
                run --as-str ($c | render $env)
            }
        }
        shell => {
            run print ($o.cmd? | render $env)
        }
        flow => {
            for i in $o.pipeline? {
                let j = $i
                | items {|k, v| [$k, ($v | upsert group $o.group)] }
                | reduce -f {} {|i, a| $a | insert $i.0 $i.1}
                custom_install $j -v $v --cache=$cache
            }
        }
        pip => {
            run pip3 install --no-cache-dir --break-system-packages ...$o.pkgs
        }
        npm => {
            run npm install --location=global ...$o.pkgs
            run npm cache clean --force
        }
        rustup => {
            if 'component' in $o {
                run rustup component add ...$o.component
            }
            if 'target' in $o {
                run rustup target add ...$o.target
            }
        }
        ghcup => {
            if 'component' in $o {
                run ghcup install ...$o.component
            }

            let ver = $env.MESSAGE?
            | default ''
            | parse -r '\+ghc_ver=(?<v>[0-9\.]+)'
            | get -i v.0
            let ver = if ($ver | is-empty) {
                http get -H [Accept application/json] $env.STACK_INFO_URL
                | get snapshot.ghc
            } else {
                $ver
            }

            run ghcup -s '["GHCupURL", "StackSetupURL"]' install ghc $ver
        }
        cargo => {
            if 'pkgs' in $o {
                run cargo install ...$o.pkgs
            }
            if 'prefetch' in $o {
                run cargo prefetch ...$o.prefetch
            }
            if 'CARGO_HOME' in $env {
                let p = [$env.CARGO_HOME registry src *] | path join | into glob
                run rm -rf $p
            }
        }
        stack => {
            if 'global_config' in $o {
                for i in ($o.global_config | transpose k v) {
                    run stack config set $i.k --global $i.v
                }
            }
            if 'config' in $o {
                let conf = $"($env.STACK_ROOT)/config.yaml"
                log level 1 {conf: $conf}
                run {
                    open $conf
                    | merge $o.config
                    | collect { $in | save -f $conf }
                }
            }

            if 'pkgs' in $o {
                run stack install --local-bin-path=/usr/local/bin --no-interleaved-output ...$o.pkgs
            }
        }
    }
}
