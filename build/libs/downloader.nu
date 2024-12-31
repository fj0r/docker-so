use log.nu *
use utils.nu *

export def download [o, version] {
    let url = $o.url | str replace -a '{{version}}' $version
    let dir = ([$env.FILE_PWD assets] | path join)
    cd $dir
    run curl -sSLO $url
    {
        dir: $dir
        file: ($url | path basename)
    }
}

