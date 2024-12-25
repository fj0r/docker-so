export def main [...args:string@compos, -c: string=''] {
    match $args.0 {
        build => {
            nerdctl build -t fj0rd/so:test .
        }
        gensh => {
            nu npup/run.nu gensh $args.1  --clean nu nvim-js exec http lsp-rust python yaml haskell --cache $c
        }
        watch => {
            watch . -d 500 {|a|
                if $a == 'Write' {
                    nu ,.nu gensh debian
                    print '----------------------------------------'
                    nu ,.nu sync
                    print '========================================'
                }
            }
        }
        update => {
            nu npup/run.nu update
        }
        download => {
            nu npup/run.nu download --cache http://file.s/npup
        }
        debug => {
            nu npup/run.nu debug nu nvim-js exec http
        }
        sync => {
            rsync -avP --exclude=.git ./npup/ ~/world/npup/
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
        { value: sync, description: 'assets' }
        { value: watch }
    ]
}
