if exists('g:autoloaded_chbuf_common') || &compatible || v:version < 700
    finish
endif

let g:autoloaded_chbuf_common = 1

let s:save_cpo = &cpoptions
set cpoptions&vim


if !exists('+shellslash') || &shellslash
    let chbuf#common#unescaped_path_seg_sep = '/'
    let chbuf#common#escaped_path_seg_sep = '/'
else
    let chbuf#common#unescaped_path_seg_sep = '\'
    let chbuf#common#escaped_path_seg_sep = '\\'
endif

let s:script_name = expand('<sfile>')

function! s:is_file_system_case_sensitive() " {{{
    let ignores_case = filereadable(tolower(s:script_name)) && filereadable(toupper(s:script_name))
    return !ignores_case
endfunction " }}}

let chbuf#common#case_sensitive_file_system = s:is_file_system_case_sensitive()

function! chbuf#common#is_good_buffer(buffer) " {{{
    if !buflisted(a:buffer)
        return 0
    endif

    if !empty(getbufvar(a:buffer, 'buftype'))
        return 0
    endif

    if bufname(a:buffer) ==# ''
        return 0
    endif

    return 1
endfunction " }}}


let &cpoptions = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker shiftwidth=4 expandtab
