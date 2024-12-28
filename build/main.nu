use libs *

export def main [
    ...target
    --proxy: string
    --dry-run
    --sys:string
    --save-versions
] {
    let pwd = $env.FILE_PWD?
    let conf = [$pwd manifest.yaml] | path join | open $in
    let versions = [$pwd versions.yaml] | path join | open $in
    build $conf $target --proxy $proxy --dry-run=$dry_run --sys $sys --versions $versions --save-versions=$save_versions
}
