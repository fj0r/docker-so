use log.nu

export def http_install [pkg] {
    for i in $pkg {
        log level 3 setup {name: $i.name}
    }
}
