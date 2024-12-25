use pkg.nu *

export def apt_update [] {
    print "apt-get update"
}

export def apt_install [...pkg] {
    install $pkg --act {|p|
        print $"apt-get install -y --no-install-recommends ($p)"
    }
}

export def apt_uninstall [pkg, deps] {
    uninstall $pkg $deps --act {|p|
        print $"apt-get purge -y --auto-remove ($p)"
    }
}

export def apt_clean [] {
    print "apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*"
}
