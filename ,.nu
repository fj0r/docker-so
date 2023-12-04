export def main [...args:string@compos] {
    match $args.0 {
        build => {
            nerdctl build -t fj0rd/so:test .
        }
        gensh => {
            nu npkg/run.nu gensh $args.1  --clean nu nvim-js exec http lsp-rust python yaml haskell
        }
        update => {
            nu npkg/run.nu update
        }
        download => {
            nu npkg/run.nu download --cache http://file.s/npkg
        }
        debug => {
            nu npkg/run.nu debug nu nvim-js exec http
        }
        _ => {
            echo 'no act'
        }

    }
}

def compos [...context: string] {
    $context | completion-generator from tree [
        { value: gensh, description: 'gen sh -c',
            next: ([debian arch alpine redhat] | wrap value) }
        { value: build, description: 'Dockerfile' }
        { value: update, description: 'versions' }
        { value: download, description: 'assets' }
        { value: debug, description: 'xxx' }
    ]
}
