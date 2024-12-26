use log.nu

export def custom_install [pkg] {
    for i in $pkg.http {
        log level 3 setup {type: http, name: $i.name}
    }
    for i in $pkg.git? {
        log level 2 setup {type: git, name: $i.name}
    }
    for i in $pkg.shell? {
        log level 2 setup {type: shell, name: $i.name}
    }
}
