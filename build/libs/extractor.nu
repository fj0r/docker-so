export def extract [input act args?] {
    match $act {
        from-json => {
            $input | from json
        }
        prefix => {
            $"($args)($input)"
        }
        index => {
            let r = do -i { $input | get $args }
            if ($r | is-empty) {
                error make { msg: $"'($args)' not in ($input)" }
            } else {
                $r
            }
        }
        field => {
            if ($args | is-empty) {
                $input
            } else {
                if $args in $input {
                    $input | get $args
                } else {
                    null
                }
            }
        }
        trim => {
            $input | str trim
        }
        regexp => {
            $input | parse -r $args | get 0?.capture0?
        }
        only-nums => {
            $input | parse -r '(?P<v>[0-9\.\-]+)' | get 0?.v?
        }
        github => {
            let ex = [
                {field: 'tag_name'}
                {trim: null }
                {only-nums: null} ]
            run ($input | from json) $ex
        }
    }
}

export def get-version [o] {
    mut headers = []
    let url = if $o.type == github {
        $headers ++= [-H 'Accept: application/json']
        $"https://api.github.com/repos/($o.url)/releases/latest"
    } else {
        $o.url
    }
    let r = curl -sSL ...$headers $url
    
    $o.extract | reduce -f $r {|x, acc|
        let r = $x | transpose k v | first
        extract $acc $r.k $r.v
    }
}

export def download [o, version] {
    print $o $version
    
}
