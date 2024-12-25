export def apk_update [] {
    print "apk update; apk upgrade"
}

export def apk_install [...pkg] {
    let p = $pkg | flatten | uniq
    log level 4 install ...$p
    print $"apk add --no-cache ($p)"
}

export def apk_uninstall [pkg] {
    log level 4 remove ...$pkg
    print $"apk del ($pkg)"
}

export def apk_clean [] {
    print "rm -rf /var/cache/apk/*"
}
