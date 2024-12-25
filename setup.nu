def get-version-from-github [
    repo
    opts
] {
    let tag = $opts.tag? | default false
    let s = if $tag {
        curl -sSL $"https://api.github.com/repos/($repo)/tags"
    } else {
        curl -sSL $"https://api.github.com/repos/($repo)/releases/latest"
    } 
    | from json

    let v = if $tag {
        $s | first | get name
    } else {
        $s.name
    }

    $v
}

def get-version-parse [
    url
    reg
] {
    curl -sSL $url | parse -r $reg
}

def get-version-json [
    url
    path
    filter?
] {
    let d = curl -sSL $url | from json
    let d = if ($filter | is-not-empty) {
        $d | filter $filter
    } else {
        $d
    }
    $d | get ($path | into cell-path)
}

def trim-version [] {
    let v = $in
    if ($v | str starts-with 'v') {
        $v | str substring 1..
    } else {
        $v
    }
}

def run [...target] {
    let list = $in
    | transpose k v
    | where $it.k in $target
    for i in $list {
        let v = $i.v
        print $"==> ($i.k)"
        if 'repo' in $v {
            get-version-from-github $v.repo $v.opts?
        } else if 'url' in $v {
            get-version-parse $v.url $v.parse
        } else if 'json' in $v {
            get-version-json $v.json $v.path $v.filter?
        }
        | trim-version
        | print
    }
}

let l = {
    nodejs: {
        version: {
            json: 'https://nodejs.org/dist/index.json'
            path: [0 version]
        }
    }
    rust-analyzer: {
        version: {
            repo: 'rust-lang/rust-analyzer'
        }
    }
    lua-language-server: {
        repo: 'LuaLS/lua-language-server' 
    }
    neovim: {
        repo: 'neovim/neovim'
        opts: { tag: true }
    }
    nushell: {
        repo: 'nushell/nushell'
    }
}

let cond = 2
match $cond {
    0 => {
        $l | run ...($l | columns)
    }
    1 => {
        $l | run nodejs
    }
    2 => {
        $l | run nushell
    }
}
