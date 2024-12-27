use log.nu
use pkg.nu *

export def custom_install [o] {
    let pkg = $o.pkg | reject apt? apk? pacman?
    let types = $pkg | columns
    for t in $types {
        for i in ($pkg | get $t) {
            let j = if $t == pipeline { $i } else { $i | upsert type $t }
            log level 3 {type: $j.type, name: $j.name?}
            run_action $j
        }
    }
}

def run_action [o] {
    match $o.type {
        http => {
            dry-run curl -sSL $o.url?
        }
        git => {
            dry-run git clone --depth=3 $o.url $o.dist
        }
        cmd => {
            dry-run bash -c $o.cmd
        }
        shell => {
            dry-run print $o.cmd?
        }
        pipeline => {
        }
    }

}
