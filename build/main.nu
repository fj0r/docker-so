use libs *

export def main [
    ...target
    --proxy: string
] {
    let pwd = $env.FILE_PWD?
    let conf = [$pwd manifest.yaml] | path join | open $in
    build $conf $target --proxy $proxy
}
