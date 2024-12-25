use pkg.nu *

export def apk_update [] {
    print "apk update; apk upgrade"
}

export def apk_install [...pkg] {
    install $pkg --act {|p|
        print $"apk add --no-cache ($p)"
    }
}

export def apk_uninstall [pkg, deps] {
    uninstall $pkg $deps --act {|p|
        print $"apk del ($p)"
    }
}

export def apk_clean [] {
    print "rm -rf /var/cache/apk/*"
}
