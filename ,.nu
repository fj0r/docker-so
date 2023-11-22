export def main [...args:string@compos] {
    match $args.0 {
        build => {
            nerdctl build -t fj0rd/so:test .
        }
        test => {
            nu npkg/main.nu test-debian base nu nvim python-utils search
        }
        update => {
            nu npkg/main.nu update-version
        }
        merge-actions => {
            nu npkg/main.nu merge-actions base nu nvim python-utils search
        }
        _ => {
            echo 'no act'
        }

    }
}

def compos [context: string, offset: int] {
    let argv = $context
        | str substring 0..$offset
        | split row -r "\\s+"
        | range 1..
        | where not ($it | str starts-with "-")
    match ($argv | length) {
        1 => [test build merge-actions update]
        2 => []
        _ => []
    }
}
