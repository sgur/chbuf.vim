scriptencoding utf-8



" Interface {{{1

function! chbuf#oldfiles#add(bufnr) abort
    if !chbuf#common#is_good_buffer(a:bufnr)
        return
    endif

    let max_entries = get(map(filter(split(&viminfo, ','), 'v:val[0] == "''"'), 'v:val[1:]'), 0, 100)

    let path = simplify(fnamemodify(bufname(a:bufnr), ":p:~"))
    let idx = index(v:oldfiles, path)
    if idx > -1
        call remove(v:oldfiles, idx)
    endif
    call insert(v:oldfiles, path)
    let v:oldfiles = v:oldfiles[: max_entries-1]
endfunction

" Internal {{{1


" Initialization {{{1



" 1}}}

" vim:foldmethod=marker shiftwidth=4 expandtab
