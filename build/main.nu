use libs *

export def main [...target] {
    let pwd = $env.FILE_PWD?
    let conf = [$pwd manifest.yaml] | path join | open $in
    build $conf $target
}
