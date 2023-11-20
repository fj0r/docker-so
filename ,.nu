export def main [...args:string@compos] {
    match $args.0 {
        build => {
            nerdctl build -t fj0rd/so:test .
        }
        _ => {
            echo 'no act'
        }

    }
}

def compos [context: string, offset: int] {
    let argv = $context | str substring 0..$offset | split row -r "\\s+" | range 1..
    match ($argv | length) {
        1 => [build]
        2 => []
        _ => []
    }
}
