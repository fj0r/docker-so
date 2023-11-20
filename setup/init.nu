def calc-deps [] {
    let x = $in
}

export def main [...args:string@compos, -m] {
    let act = $args.0
    let coms = $args | 1..
    let manifest = if $m {
        open $"($env.PWD)/manifest.yml"
    } else {
        open $"($env.FILE_PWD)/manifest.yml"
    }
    match $act {
        dry-run => {
            echo '??????????'
        }
        _ => {
            echo $manifest | to json
        }

    }
}

def compos [context: string, offset: int] {
    let argv = $context | str substring 0..$offset | split row -r "\\s+" | range 1.. | filter {|s| not ($s | str starts-with "-")}
    match ($argv | length) {
        1 => [dryRun]
        _ => {
            let manifest = open $"($env.PWD)/manifest.yml"
            $manifest.layers | get name
        }
    }
}
