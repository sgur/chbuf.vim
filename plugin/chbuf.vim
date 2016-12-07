scriptencoding utf-8

if get(g:, 'loaded_chbuf', 0) || &compatible || v:version < 800
    finish
endif

let g:loaded_chbuf = 1

let s:save_cpo = &cpo
set cpo&vim


command! -nargs=* ChangeBuffer call chbuf#change_buffer(<q-args>)
command! -nargs=* ChangeMixed call chbuf#change_mixed(<q-args>)
command! -nargs=? ChangeFileSystem call chbuf#change_current(<q-args>)
command! -nargs=? ChangeOldfiles call chbuf#change_oldfiles(<q-args>)


if has('mac')
    command! -nargs=+ -complete=custom,chbuf#spotlight_query_completion Spotlight call chbuf#spotlight(<q-args>)
    command! -nargs=+ -complete=custom,chbuf#spotlight_query_completion SpotlightCurrent call chbuf#spotlight_current(<q-args>)
endif


augroup chbuf
    autocmd!
    autocmd BufAdd,BufEnter,BufLeave,BufWritePost * call chbuf#oldfiles#add(0 + expand('<abuf>'))
augroup END


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker shiftwidth=4 expandtab
