use pkg.nu *
use utils.nu *

export def pacman_update [] {
    run pacman -Sy
}

export def pacman_install [...pkg] {
    install $pkg --act {|p|
        run pacman -S ...$p
    }
}

export def pacman_uninstall [pkg, rmv] {
    uninstall $pkg $rmv --act {|p|
        run pacman -Rcns ...$p
    }
}

export def pacman_clean [] {
    run rm -rf /var/cache/pacman/pkg/*
}
