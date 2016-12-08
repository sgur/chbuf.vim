scriptencoding utf-8

let s:save_cpo = &cpoptions
set cpoptions&vim


" {{{ Data Source: Internal
function! s:init()  " {{{
    let s:oldfiles = filter(copy(v:oldfiles), 'filereadable(expand(v:val)) || isdirectory(expand(v:val))')
endfunction " }}}
" }}}

" {{{ Data Source: External
function! chbuf#oldfiles#clone()  " {{{
    return copy(s:oldfiles)
endfunction " }}}

function! chbuf#oldfiles#add(bufnr) abort " {{{
    if !chbuf#common#is_good_buffer(a:bufnr)
        return
    endif

    let max_entries = get(map(filter(split(&viminfo, ','), 'v:val[0] ==# "''"'), 'v:val[1:]'), 0, 100)

    let path = simplify(fnamemodify(bufname(a:bufnr), ':p:~'))
    let idx = index(s:oldfiles, path)
    if idx > -1
        call remove(s:oldfiles, idx)
    endif
    call insert(s:oldfiles, path)
    let s:oldfiles = s:oldfiles[: max_entries-1]
endfunction " }}}
" }}}

call s:init()


let &cpoptions = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker shiftwidth=4 expandtab
