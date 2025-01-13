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
    $pkg | items {|t,o|
        for i in $o {
            let j = $i | upsert type $t
            log level 3 {type: $j.type, group: $j.group?, name: $j.name?}
            run_action $j -v $v --cache=$cache
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
                log level 1 {pwd: $env.PWD, ...$dl} download
                download $dl

                log level 1 $i install $version
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
        npm => {
            run npm install --location=global ...$o.pkgs
        }
        pip => {
            run pip3 install --no-cache-dir --break-system-packages ...$o.pkgs
        }
    }
}
