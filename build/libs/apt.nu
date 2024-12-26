use pkg.nu *

export def apt_update [] {
    dry-run apt-get update
}

export def apt_install [...pkg] {
    install $pkg --act {|p|
        dry-run apt-get install -y --no-install-recommends ...$p
    }
}

export def apt_uninstall [pkg, deps] {
    uninstall $pkg $deps --act {|p|
        dry-run apt-get purge -y --auto-remove ...$p
    }
}

export def apt_clean [] {
    dry-run apt-get autoremove -y
    dry-run apt-get clean -y
    dry-run rm -rf /var/lib/apt/lists/*
}
