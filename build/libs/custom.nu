use log.nu
use utils.nu *
use extractor.nu *

export def custom_install [o] {
    let pkg = $o.pkg | reject apt? apk? pacman?
    let types = $pkg | columns
    for t in $types {
        for i in ($pkg | get $t) {
            let j = $i | upsert type $t
            log level 3 {type: $j.type, group: $j.group?, name: $j.name?}
            run_action $j
        }
    }
}

def run_action [o] {
    match $o.type {
        http => {
            if $o.group == neovim {
                let version = get-version $o.version
                log level 1 {group: $o.group, version: $version} update version
                run download $o.download $version
            }
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


