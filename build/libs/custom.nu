use log.nu
use utils.nu *
use extractor.nu *

export def custom_install [
    o
    -v: record
] {
    let pkg = $o.pkg | reject apt? apk? pacman?
    let types = $pkg | columns
    for t in $types {
        for i in ($pkg | get $t) {
            let j = $i | upsert type $t
            log level 3 {type: $j.type, group: $j.group?, name: $j.name?}
            run_action $j -v $v
        }
    }
}

def run_action [
    o
    -v: record
] {
    match $o.type {
        http => {
            let version = if (($o.name? | default '') in $v) {
                $v | get $o.name
            } else {
                get-version $o.version $o.name?
            }

            log level 1 {group: $o.group, version: $version} update version
            download $o.download $version
        }
        git => {
            run git clone --depth=3 $o.url $o.dist
        }
        cmd => {
            run $o.cmd
        }
        shell => {
            run print $o.cmd?
        }
        flow => {
            for i in $o.pipeline? {
                run_action $i
            }
        }
    }
}


