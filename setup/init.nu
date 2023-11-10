export def main [] {
    let manifest = open $"($env.FILE_PWD)/manifest.yml"
    print $manifest
}
