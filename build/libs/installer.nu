use log.nu *
use utils.nu *

export def install [inst, down, --prefix:string='/usr/local'] {
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
    let target = [$prefix $inst.target] | str join

    if ($decmp | is-empty) {
        let t = [$target $inst.rename] | path join
        $cmds.0.0 ++= [mv $down.file $t]
        $cmds ++= [[[chmod +x $t]]]
    } else if ($fmt == 'zip') {
        $tmp = mktemp -t unzip.XXX -d
        $cmds.0.0 ++= [unzip $down.file]
        $cmds ++= [[[mv $down.file $target]]]
    } else if ($fmt | str starts-with 'tar') {
        $cmds.0.0 ++= [cat $down.file]
        $cmds.0 ++= [[$decmp]]
        $cmds.0.1 ++= [-C $target]

        if ($inst.strip? | is-not-empty) {
            $cmds.0.1 ++= [$"--strip-components=($inst.strip)"]
        }

        if ($inst.filter? | is-not-empty) {
            $cmds.0.1 ++= [--wildcards ($inst.filter | str join ' ')]
        }
    } else {
        let t = [$target $inst.rename] | path join
        $cmds.0.0 ++= [cat $down.file]
        $cmds.0 ++= [[$decmp]]
        $cmds.0 ++= [[save $t]]
        $cmds ++= [[[chmod +x $t]]]
    }

    log level 5 $cmds
}
