use pkg.nu *

export def pacman_update [] {
    print "apt-get update"
}

export def pacman_install [...pkg] {
    install $pkg --act {|p|
        print $"apt-get install -y --no-install-recommends ($p)"
    }
}

export def pacman_uninstall [pkg, deps] {
    uninstall $pkg $deps --act {|p|
        print $"apt-get purge -y --auto-remove ($p)"
    }
}

export def pacman_clean [] {
    print "apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*"
}
