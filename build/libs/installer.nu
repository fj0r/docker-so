use log.nu *
use utils.nu *

export def download [o] {
    cd $o.dir
    run curl -sSL $o.url -o $o.file
}

export def download_info [o, vars] {
    let url = $o.url | render $vars
    let file = if ($o.filename? | is-empty) {
        $url | path basename
    } else {
        $o.filename | render $vars
    }
    let dir = [$env.FILE_PWD assets] | path join | render $vars
    {
        dir: $dir
        file: $file
        url: $url
    }
}

export def install [inst, down, --prefix:string='/usr/local'] {
    let fmt = if ($inst.format? | is-not-empty ) {
        $inst.format
    } else {
        let fn = $down.file | split row '.'
        let zf = $fn | last
        if ($fn | length) >= 2 and ($fn | range (-2..-2) | get 0) == 'tar' {
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
    mut cmds = []
    let target = if ($inst.root? | default false) {
        $inst.target
    } else {
        [$prefix $inst.target] | str join
    }
    | render $env

    let file = [$down.dir $down.file] | path join
    if ($decmp | is-empty) {
        let r = $inst.rename? | default $target
        let t = [$target $r] | path join
        $cmds ++= [[[cp $file $t]]]
        $cmds ++= [[[chmod +x $t]]]
    } else if ($fmt == 'zip') {
        $tmp = mktemp -t unzip.XXX -d
        cd $tmp
        $cmds ++= [[[unzip $file]]]
        for i in $inst.filter? {
            $cmds ++= [[[mv $i $target]]]
        }
        $cmds ++= [[['cd ; rm -rf' $tmp]]]
    } else if ($fmt | str starts-with 'tar') {
        $cmds ++= [[[cat $file]]]
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
        $cmds ++= [[[cat $file]]]
        $cmds.0 ++= [[$decmp]]
        $cmds.0 ++= [[save $t]]
        $cmds ++= [[[chmod +x $t]]]
    }

    for c in $cmds {
        let x =  $c | each {|x| $x | str join ' '} | str join ' | '
        run --as-str $x
    }
}
