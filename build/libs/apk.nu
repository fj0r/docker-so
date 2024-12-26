use pkg.nu *

export def apk_update [] {
    dry-run apk update
    dry-run apk upgrade
}

export def apk_install [...pkg] {
    install $pkg --act {|p|
        dry-run apk add --no-cache ...$p
    }
}

export def apk_uninstall [pkg, deps] {
    uninstall $pkg $deps --act {|p|
        dry-run apk del ...$p
    }
}

export def apk_clean [] {
    dry-run rm -rf /var/cache/apk/*
}
