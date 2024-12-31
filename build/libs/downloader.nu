use utils.nu *

export def download [o] {
    cd $o.dir
    run curl -sSL $o.url -o $o.file
}

