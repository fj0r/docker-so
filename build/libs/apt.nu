use pkg.nu *
use utils.nu *

export def apt_update [] {
    run apt-get update
}

export def apt_install [...pkg] {
    install $pkg --act {|p|
        run apt-get install -y --no-install-recommends ...$p
    }
}

export def apt_uninstall [pkg, rmv] {
    uninstall $pkg $rmv --act {|p|
        run apt-get purge -y --auto-remove ...$p
    }
}

export def apt_clean [] {
    run apt-get autoremove -y
    run apt-get clean -y
    run rm -rf /var/lib/apt/lists/*
}
