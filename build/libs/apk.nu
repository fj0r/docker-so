use pkg.nu *
use utils.nu *

export def apk_update [] {
    run apk update
    run apk upgrade
}

export def apk_install [...pkg] {
    install $pkg --act {|p|
        run apk add --no-cache ...$p
    }
}

export def apk_uninstall [pkg, rmv] {
    uninstall $pkg $rmv --act {|p|
        run apk del ...$p
    }
}

export def apk_clean [] {
    run rm -rf /var/cache/apk/*
}
