use utils.nu *

export def download [o, version] {
    let url = $o.url | str replace -a '{{version}}' $version
    let dir = ([$env.FILE_PWD assets] | path join)
    cd $dir
    run curl -sSLo $url
}

export def unpack [] {

}

def resolve-format [ctx] {
    let fmt = if ($ctx.format? | not-empty ) { $ctx.format } else {
        let fn = $ctx.file | split row '.'
        let zf = $fn | last
        if ($fn | range (-2..-2) | get 0) == 'tar' {
            $"tar.($zf)"
        } else {
            $zf
        }
    }
    let decmp = match $fmt {
        'tar.gz'  => $"tar zxf"
        'tar.zst' => $"zstd -d -T0 | tar xf"
        'tar.bz2' => $"tar jxf"
        'tar.xz'  => $"tar Jxf"
        'gz'      => $"gzip -d"
        'zst'     => $"zstd -d"
        'bz2'     => $"bzip2 -d"
        'xz'      => $"xz -d"
        'zip'     => $"unzip"
        _ => "(!unknown format)"
    }
    mut override = false
    let target = if $fmt == 'zip' {
        $ctx.file
    } else if not ($fmt | str starts-with 'tar.') {
        $override = true
        let n = if ($ctx.filter? | is-empty) { $ctx.name } else { $ctx.filter | first }
        [$ctx.target $n] | path join
    } else {
        $ctx.target
    }
    {
        decmp: $decmp
        workdir: $ctx.workdir?
        target: $target
        strip: $ctx.strip?
        override: $override
    }
}
