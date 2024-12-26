use pkg.nu *

export def apk_update [] {
    apk update
    apk upgrade
}

export def apk_install [...pkg] {
    install $pkg --act {|p|
        apk add --no-cache ...$p
    }
}

export def apk_uninstall [pkg, deps] {
    uninstall $pkg $deps --act {|p|
        apk del ...$p
    }
}

export def apk_clean [] {
    rm -rf /var/cache/apk/*
}
