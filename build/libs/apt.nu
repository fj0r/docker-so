export def apt_update [] {
    print "apt-get update"
}

export def apt_install [...pkg] {
    let p = $pkg | flatten | uniq
    $env.DEBIAN_FRONTEND = 'noninteractive'
    print $"apt-get install -y --no-install-recommends ($p)"
}

export def apt_uninstall [pkg] {
    print $"apt-get purge -y --auto-remove ($pkg)"
}

export def apt_clean [] {
    print "apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*"
}
