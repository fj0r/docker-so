def comp-act [] {
    [build]
}
export def main [act:string@comp-act] {
    match $act {
        build => {
            nerdctl build -t fj0rd/so:test .
        }
        _ => {
            echo 'no act'
        }
    }
}
