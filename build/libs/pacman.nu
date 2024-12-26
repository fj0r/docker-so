use pkg.nu *

export def pacman_update [] {
    dry-run pacman -Sy
}

export def pacman_install [...pkg] {
    install $pkg --act {|p|
        dry-run pacman -S ...$p
    }
}

export def pacman_uninstall [pkg, rmv] {
    uninstall $pkg $rmv --act {|p|
        dry-run pacman -Rcns ...$p
    }
}

export def pacman_clean [] {
    dry-run rm -rf /var/cache/pacman/pkg/*
}
