scriptencoding utf-8

if get(g:, 'loaded_chbuf', 0) || &compatible || v:version < 800
    finish
endif

let g:loaded_chbuf = 1

let s:save_cpo = &cpoptions
set cpoptions&vim


command! -nargs=* ChangeBuffer call chbuf#change_buffer(<q-args>)
command! -nargs=* ChangeMixed call chbuf#change_mixed(<q-args>)
command! -nargs=? -complete=customlist,chbuf#path_complete ChangeFileSystem call chbuf#change_current(<q-args>)
command! -nargs=? ChangeOldfiles call chbuf#change_oldfiles(<q-args>)


if executable('files') " https://github.com/mattn/files
    command! -nargs=? -complete=dir ChangeFiles call chbuf#files(<q-args>)
endif

if has('mac')
    command! -nargs=+ -complete=custom,chbuf#spotlight_query_completion Spotlight call chbuf#spotlight(<q-args>)
    command! -nargs=+ -complete=custom,chbuf#spotlight_query_completion SpotlightCurrent call chbuf#spotlight_current(<q-args>)
endif


augroup chbuf
    autocmd!
    autocmd BufAdd,BufEnter,BufLeave,BufWritePost *
                \ if !(has('vim_starting') && argc() == 0) | call chbuf#oldfiles#add(0 + expand('<abuf>')) | endif
augroup END


let &cpoptions = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker shiftwidth=4 expandtab
