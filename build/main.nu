use libs *

export def main [
    ...target
    --cache
    --proxy: string
    --dry-run
    --os:string
] {
    let pwd = $env.FILE_PWD?
    let conf = [$pwd manifest.yaml] | path join | open $in
    let versions = [$pwd versions.yaml] | path join | open $in
    build $conf $target --proxy $proxy --cache=$cache --dry-run=$dry_run --os $os --versions $versions
}
