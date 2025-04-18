use utils.nu *

export def extract [input act args?] {
    match $act {
        from-json => {
            $input | from json
        }
        prefix => {
            $"($args)($input)"
        }
        index => {
            let p = $args | split row '.' | into cell-path
            let r = do -i { $input | get $p }
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
        lts => {
            $input | where lts != false | first
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

export def get-version [o name --cache] {
    mut headers = []
    let url = if $o.type? == github {
        $headers ++= [-H 'Accept: application/json']
        $"https://api.github.com/repos/($o.repo)/releases/latest"
    } else {
        $o.url
    }

    if ($o.headers? | is-not-empty) {
        for h in ($o.headers | transpose k v) {
            $headers ++= [-H $"($h.k): ($h.v)"]
        }
    }

    let r = curl -sSL ...$headers $url

    let v = $o.extract? | reduce -f $r {|x, acc|
        let r = $x | transpose k v | first
        extract $acc $r.k $r.v
    }

    if $cache and ($name | is-not-empty) {
        let f = [$env.FILE_PWD versions.yaml] | path join
        open $f | upsert $name $v | collect | save -f $f
    }

    $v
}

