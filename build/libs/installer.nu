use log.nu *
use utils.nu *

export def install [inst, down] {
    let fmt = if ($inst.format? | is-not-empty ) {
        $inst.format
    } else {
        let fn = $down.file | split row '.'
        let zf = $fn | last
        if ($fn | range (-2..-2) | get 0) == 'tar' {
            $"tar.($zf)"
        } else {
            $zf
        }
    }

    let decmp = match $fmt {
        'tar.gz'  => $"tar zxf - "
        'tar.zst' => $"zstd -d -T0 | tar xf -"
        'tar.bz2' => $"tar jxf -"
        'tar.xz'  => $"tar Jxf -"
        'gz'      => $"gzip -d"
        'zst'     => $"zstd -d"
        'bz2'     => $"bzip2 -d"
        'xz'      => $"xz -d"
        'zip'     => $"unzip"
        _ => ""
    }

    mut tmp = ''
    mut cmds = [[[]]]

    if ($decmp | is-empty) {
        $cmds.0.0 ++= [mv $down.file $inst.target]
        $cmds ++= [[[chmod +x $inst.target]]]
    } else if ($fmt == 'zip') {
        $tmp = mktemp -t unzip.XXX -d
        $cmds.0.0 ++= [unzip $down.file]
        $cmds ++= [[[mv $down.file $inst.target]]]
    } else if ($fmt | str starts-with 'tar') {
        $cmds.0.0 ++= [cat $down.file]
        $cmds.0 ++= [[$decmp]]
        $cmds.0.1 ++= [-C $inst.target]

        if ($inst.strip? | is-not-empty) {
            $cmds.0.1 ++= [$"--strip-components=($inst.strip)"]
        }

        if ($inst.filter? | is-not-empty) {
            $cmds.0.1 ++= [--wildcards ($inst.filter | str join ' ')]
        }
    } else {
        $cmds.0.0 ++= [cat $down.file]
        $cmds.0 ++= [[$decmp]]
        $cmds.0 ++= [[save $inst.target]]
        $cmds ++= [[[chmod +x $inst.target]]]
    }

    log level 5 $cmds
}
