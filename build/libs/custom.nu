use log.nu
use utils.nu *
use extractor.nu *
use installer.nu *

export def custom_install [
    o
    -v: record
    --cache
] {
    let pkg = $o.pkg | reject apt? apk? pacman? deps? build-deps?
    let order = [http git cmd shell flow rustup pip npm cargo stack]
    for o in $order {
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
            } else {
                get-version $o.version $o.name? --cache=$cache
            }
            log level 1 {group: $o.group, version: $version} update version

            for i in $o.install {
                let dl = download_info $i $version
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
            run {
                if not ($dist | path exists) { mkdir $dist }
                git clone --depth=3 $o.url $dist
            }
        }
        cmd => {
            for c in $o.cmd {
                run --as-str $c
            }
        }
        shell => {
            run print $o.cmd?
        }
        flow => {
            for i in $o.pipeline? {
                run_action $i -v $v --cache=$cache
            }
        }
        pip => {
            run pip3 install --no-cache-dir --break-system-packages ...$o.pkgs
        }
        npm => {
            run npm install --location=global ...$o.pkgs
        }
        rustup => {
            if 'component' in $o {
                run rustup component add ...$o.component
            }
            if 'target' in $o {
                run rustup target add ...$o.target
            }
        }
        cargo => {
            if 'pkgs' in $o {
                run cargo install ...$o.pkgs
            }
            if 'prefetch' in $o {
                run cargo prefetch ...$o.prefetch
            }
        }
        stack => {
            run stack install --local-bin-path=/usr/local/bin --no-interleaved-output ...$o.pkgs
        }
    }
}
