scriptencoding utf-8

let s:save_cpo = &cpoptions
set cpoptions&vim


" {{{ Data Source: Internal
function! s:change_to_number() dict " {{{
    execute 'silent' 'buffer' self.number
endfunction " }}}

function! s:is_number_choosable() dict " {{{
    return 1
endfunction " }}}

function! s:set_file_suffix(suffix) dict " {{{
    let self.suffix = a:suffix
endfunction " }}}

function! s:set_dir_suffix(suffix) dict " {{{
    let self.suffix = a:suffix . g:chbuf#common#unescaped_path_seg_sep
endfunction " }}}

function! s:ensure_ends_with_seg_sep(path) " {{{
    if strpart(a:path, strlen(a:path) - 1) ==# g:chbuf#common#unescaped_path_seg_sep
        return a:path
    endif

    return a:path . g:chbuf#common#unescaped_path_seg_sep
endfunction " }}}

function! s:file_dir() dict " {{{
    return fnamemodify(self.path, ':h')
endfunction " }}}

function! s:dir_dir() dict " {{{
    return self.path
endfunction " }}}

function! s:cd_buffer() dict " {{{
    execute 'silent' 'cd' fnameescape(self.dir())
endfunction " }}}

function! s:lcd_buffer() dict " {{{
    execute 'silent' 'lcd' fnameescape(self.dir())
endfunction " }}}

function! s:buffer_from_number(number, name) " {{{
    let path = expand('#' . a:number . ':p')

    if isdirectory(path)
        let path = s:ensure_ends_with_seg_sep(path)
        let set_suf_fn = 'set_dir_suffix'
        let dir_fn = 'dir_dir'
    else
        let set_suf_fn = 'set_file_suffix'
        let dir_fn = 'file_dir'
    endif

    return { 'number':          a:number
          \, 'path':            path
          \, 'name':            a:name
          \, 'change':          function('s:change_to_number')
          \, 'is_choosable':    function('s:is_number_choosable')
          \, 'set_suffix':      function('s:' . set_suf_fn)
          \, 'dir':             function('s:' . dir_fn)
          \, 'cd':              function('s:cd_buffer')
          \, 'lcd':             function('s:lcd_buffer')
          \}
endfunction " }}}

function! s:change_to_path() dict " {{{
    execute 'silent' 'edit' fnameescape(self.path)
endfunction " }}}

function! s:path_choosable() dict " {{{
    return filereadable(self.path) || isdirectory(self.path)
endfunction " }}}

function! s:buffer_from_path(path) " {{{
    let expanded = expand(a:path)

    if isdirectory(expanded)
        let expanded = s:ensure_ends_with_seg_sep(expanded)
        let set_suf_fn = 'set_dir_suffix'
        let dir_fn = 'dir_dir'
    else
        let set_suf_fn = 'set_file_suffix'
        let dir_fn = 'file_dir'
    endif

    return { 'path':            expanded
          \, 'change':          function('s:change_to_path')
          \, 'is_choosable':    function('s:path_choosable')
          \, 'set_suffix':      function('s:' . set_suf_fn)
          \, 'dir':             function('s:' . dir_fn)
          \, 'cd':              function('s:cd_buffer')
          \, 'lcd':             function('s:lcd_buffer')
          \}
endfunction " }}}

function! s:buffer_from_relative_path(relative) " {{{
    let absolute = fnamemodify(a:relative, ':p')

    if isdirectory(absolute)
        let absolute = s:ensure_ends_with_seg_sep(absolute)
        let set_suf_fn = 'set_dir_suffix'
        let dir_fn = 'dir_dir'
    else
        let set_suf_fn = 'set_file_suffix'
        let dir_fn = 'file_dir'
    endif

    return { 'relative':        a:relative
          \, 'path':            absolute
          \, 'change':          function('s:change_to_path')
          \, 'is_choosable':    function('s:path_choosable')
          \, 'set_suffix':      function('s:' . set_suf_fn)
          \, 'dir':             function('s:' . dir_fn)
          \, 'cd':              function('s:cd_buffer')
          \, 'lcd':             function('s:lcd_buffer')
          \}
endfunction " }}}

function! s:glob_list(wildcard, flags) " {{{
    if v:version < 704
        return split(glob(a:wildcard, a:flags), "\n")
    endif

    return glob(a:wildcard, a:flags, 1)
endfunction " }}}

function! s:is_file_system_object(path) " {{{
    let type = getftype(a:path)
    if type ==# 'file' || type ==# 'dir'
        return 1
    elseif type ==# 'link'
        let resolved = getftype(resolve(a:path))
        return resolved ==# 'file' || resolved ==# 'dir'
    endif

    return 0
endfunction " }}}

function! s:get_glob_objects(glob_pattern) " {{{
    let paths = s:glob_list(a:glob_pattern, 0)
    call filter(paths, 's:is_file_system_object(v:val)')
    call map(paths, 's:buffer_from_relative_path(v:val)')
    return paths
endfunction " }}}

function! s:get_oldfiles(filter_pattern) abort "{{{
    let result = map(chbuf#oldfiles#clone(), 's:buffer_from_path(v:val)')

    if a:filter_pattern ==# ''
        return result
    endif

    let escaped = escape(a:filter_pattern, "'")
    return filter(result, printf("v:val.path =~ '%s'", escaped))
endfunction " }}}

function! s:get_buffers(filter_pattern) " {{{
    let current_bufnr = bufnr('%')
    return filter(map(
                \   filter(range(1, bufnr('$')), 'bufexists(v:val) && chbuf#common#is_good_buffer(v:val) && v:val != current_bufnr'),
                \   's:buffer_from_number(v:val, bufname(v:val))'),
                \ '!empty(v:val.path) && v:val.path =~ a:filter_pattern')
endfunction " }}}

function! s:segmentwise_shortest_unique_prefix(cur, ref) " {{{
    let curlen = len(a:cur)
    let reflen = len(a:ref)

    let result = []
    for i in range(curlen)
        call add(result, a:cur[i])

        if i >= reflen
            break
        endif

        let equal = g:chbuf#common#case_sensitive_file_system ? a:cur[i] ==# a:ref[i] : a:cur[i] ==? a:ref[i]
        if equal
            continue
        endif

        break
    endfor

    return result
endfunction " }}}

function! s:set_unique_segments_prefix(bufs) " {{{
    let bufslen = len(a:bufs)
    if bufslen == 0
        return []
    elseif bufslen == 1
        return [[a:bufs[0].segments[0]]]
    endif

    let result = [s:segmentwise_shortest_unique_prefix(a:bufs[0].segments, a:bufs[1].segments)]
    for i in range(1, bufslen-2)
        let left = s:segmentwise_shortest_unique_prefix(a:bufs[i].segments, a:bufs[i-1].segments)
        let right = s:segmentwise_shortest_unique_prefix(a:bufs[i].segments, a:bufs[i+1].segments)
        call add(result, len(left) > len(right) ? left : right)
    endfor
    call add(result, s:segmentwise_shortest_unique_prefix(a:bufs[-1].segments, a:bufs[-2].segments))

    return result
endfunction " }}}

function! s:by_segments(left, right) " {{{
    let less = g:chbuf#common#case_sensitive_file_system ? a:left.segments <# a:right.segments : a:left.segments <? a:right.segments
    return less ? -1 : 1
endfunction " }}}

function! s:by_suffix_len(left, right) " {{{
    return strlen(a:left.suffix) - strlen(a:right.suffix)
endfunction " }}}

function! s:uniq_segments(buffers) " {{{
    if len(a:buffers) == 0
        return a:buffers
    endif

    let prev = a:buffers[0]
    let result = [prev]
    for i in range(1, len(a:buffers)-1)
        let equal = g:chbuf#common#case_sensitive_file_system ? a:buffers[i].segments ==# prev.segments : a:buffers[i].segments ==? prev.segments
        if !equal
            call add(result, a:buffers[i])
        endif
        let prev = a:buffers[i]
    endfor

    return result
endfunction " }}}

function! s:set_segmentwise_shortest_unique_suffixes(buffers, attrib) " {{{
    let result = a:buffers

    let sep = printf('\V%s\+', g:chbuf#common#escaped_path_seg_sep)
    for buf in result
        let buf.segments = join(reverse(split(get(buf, a:attrib), sep)), g:chbuf#common#unescaped_path_seg_sep)
    endfor

    call sort(result, 's:by_segments')
    let result = s:uniq_segments(result)

    for buf in result
        let buf.segments = split(buf.segments, sep)
    endfor

    let unique_segmentwise_prefixes = s:set_unique_segments_prefix(result)
    for i in range(len(result))
        call result[i].set_suffix(join(reverse(unique_segmentwise_prefixes[i]), g:chbuf#common#unescaped_path_seg_sep))
        unlet result[i].segments
    endfor

    call sort(result, 's:by_suffix_len')

    return result
endfunction " }}}

function! s:filter_matching(input, buffers) " {{{
    let result = a:buffers

    if &ignorecase
        for needle in split(tolower(a:input), '\v\s+')
            call filter(result, printf('stridx(tolower(v:val.suffix), "%s") >= 0', escape(needle, '\\"')))
        endfor
    else
        for needle in split(a:input, '\v\s+')
            call filter(result, printf('stridx(v:val.suffix, "%s") >= 0', escape(needle, '\\"')))
        endfor
    endif

    return result
endfunction " }}}

function! s:render_hint(buffers) " {{{
    if len(a:buffers) == 1
        return a:buffers[0].path
    else
        return join(map(copy(a:buffers), 'v:val.suffix'))
    endif
endfunction " }}}

function! s:get_line_callback(cache, input) " {{{
    let matching = s:filter_matching(a:input, copy(a:cache))

    if len(matching) == 0
        return {}
    endif

    return {'data': matching, 'hint': s:render_hint(matching)}
endfunction " }}}

function! s:accept(state, key) " {{{
    if a:state.data[0].is_choosable()
        return {'result': a:state.data[0]}
    endif

    return {'state': a:state}
endfunction " }}}

function! s:yank(state, key) " {{{
    call setreg(v:register, a:state.data[0].path)
    return {'final': a:state.config.separator . a:state.data[0].path}
endfunction " }}}

function! s:guarded_space(state, key) " {{{
    if len(a:state.contents) == 0
        return {'state': a:state}
    endif

    if a:state.contents =~# '\v\s$'
        return {'state': a:state}
    endif

    if len(a:state.data) <= 1
        return {'state': a:state}
    endif

    return {'state': a:state.transition(a:state.contents . a:key)}
endfunction " }}}

function! s:chdir(state, key) " {{{
    let result = a:state.data[0]
    if a:key ==# 'CTRL-I'
        call result.cd()
        return {'final': ':cd ' . result.dir()}
    elseif a:key ==# 'CTRL-L'
        call result.lcd()
        return {'final': ':lcd ' . result.dir()}
    else
        throw 'Unhandled key: ' . a:key
    endif
endfunction " }}}

function! s:reset(state, key) " {{{
    if a:key ==# 'CTRL-_'
        return {'result': a:state.data[0]}
    else
        throw 'Unhandled key: ' . a:key
    endif
endfunction " }}}

let s:key_handlers =
    \{ 'CTRL-S': function('s:accept')
    \, 'CTRL-V': function('s:accept')
    \, 'CTRL-T': function('s:accept')
    \, 'CTRL-M': function('s:accept')
    \, 'CTRL-Y': function('s:yank')
    \, 'CTRL-L': function('s:chdir')
    \, 'CTRL-I': function('s:chdir')
    \, 'CTRL-_': function('s:reset')
    \, ' '     : function('s:guarded_space')
    \}

function! s:prompt(buffers) " {{{
    return getline#get_line_reactively_override_keys(function('s:get_line_callback', [a:buffers]), s:key_handlers)
endfunction " }}}

function! s:change(result) " {{{
    if !has_key(a:result, 'value')
        return ''
    endif
    let buffer = a:result.value
    let key = a:result.key

    if key ==# 'CTRL-M'
        if isdirectory(buffer.path)
            return buffer.path
        endif
        call buffer.change()
    elseif key ==# 'CTRL-T'
        execute 'tabnew'
        call buffer.change()
    elseif key ==# 'CTRL-S'
        execute 'split'
        call buffer.change()
    elseif key ==# 'CTRL-V'
        execute 'vsplit'
        call buffer.change()
    elseif key ==# 'CTRL-_'
        return fnamemodify(buffer.dir(),':p:h:h')
    endif
    return ''
endfunction " }}}

function! s:choose_path_interactively(path_objects) " {{{
    return s:change(s:prompt(a:path_objects))
endfunction " }}}

function! s:change_current_internal(glob_pattern) abort " {{{
    let buffers = s:get_glob_objects(a:glob_pattern)
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'relative')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#change_buffer(filter_pattern) " {{{
    let buffers = s:get_buffers(a:filter_pattern)
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'path')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#change_mixed(filter_pattern) " {{{
    let buffers = extend(s:get_buffers(a:filter_pattern), s:get_oldfiles(a:filter_pattern))
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'path')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#change_current(glob_pattern) " {{{
    let pattern = a:glob_pattern . (empty(a:glob_pattern) ? '*' : isdirectory(expand(a:glob_pattern)) ? '/*' : '')
    while 1
        let result = s:change_current_internal(pattern)
        if empty(result) | break | endif
        let pattern = result . '*'
    endwhile
endfunction " }}}

function! chbuf#change_oldfiles(filter_pattern)  "{{{
    let buffers = s:get_oldfiles(a:filter_pattern)
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'path')
    return s:choose_path_interactively(buffers)
endfunction "}}}

" }}}

" {{{ Data Source: External
function! chbuf#spotlight_query_completion(arglead, cmdline, cursorpos) " {{{
    " https://developer.apple.com/library/mac/#documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html
    let keywords =
        \[ 'kMDItemFSName'
        \, 'kMDItemDisplayName'
        \, 'kMDItemFSCreationDate'
        \, 'kMDItemFSContentChangeDate'
        \, 'kMDItemContentType'
        \, 'kMDItemContentTypeTree'
        \, 'kMDItemFSSize'
        \, 'kMDItemFSInvisible'
        \, '$time.now'
        \, '$time.today'
        \, '$time.yesterday'
        \, '$time.this_week'
        \, '$time.this_month'
        \, '$time.this_year'
        \, '$time.iso'
        \, 'InRange'
        \]
    return join(keywords, "\n")
endfunction " }}}

function! s:error(msg) " {{{
    echohl ErrorMsg
    echo a:msg
    echohl None
endfunction " }}}

function! chbuf#spotlight_current(query) " {{{
    let output = system(printf('mdfind -onlyin %s %s', shellescape(getcwd()), shellescape(a:query)))
    if v:shell_error > 0
        call s:error('mdfind: ' . substitute(output, "\\v\n*$", '', ''))
        return
    endif
    let paths = map(split(output, "\n"), 'fnamemodify(v:val, '':.'')')
    let buffers = map(paths, 's:buffer_from_relative_path(v:val)')
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'relative')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#spotlight(query) " {{{
    let output = system(printf('mdfind %s', shellescape(a:query)))
    if v:shell_error > 0
        call s:error('mdfind: ' . substitute(output, "\\v\n*$", '', ''))
        return
    endif
    let buffers = map(split(output, "\n"), 's:buffer_from_path(v:val)')
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'path')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#path_complete(arglead, cmdline, cursorpos) abort "{{{
  let arglead = fnamemodify(a:arglead, ':p')
  return stridx(fnamemodify(arglead, ':t'), '*') >= 0
              \ ? [arglead]
              \ : map(filter(glob(arglead . '*', 1, 1), 'isdirectory(v:val)'), 'fnamemodify(v:val, '':~:.'')')
endfunction "}}}

function! chbuf#external(path_type, args, ...) abort
    if !a:0
        call s:change_external(a:path_type, systemlist(join(a:args)))
    else " with timeout
        let job_nr = job_start(a:args, {'close_cb': function('s:external_on_close_callback', [a:path_type])})
        call timer_start(a:1, {timer -> job_stop(job_nr)})
    endif
endfunction

function! s:change_external(path_type, raw_list) abort "{{{
    let func = a:path_type is# 'path' ? 's:buffer_from_path' : 's:buffer_from_relative_path'
    let buffers = map(filter(a:raw_list, 's:is_file_system_object(v:val)'), func . '(v:val)')
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, a:path_type)
    call s:choose_path_interactively(buffers)
endfunction "}}}

function! s:external_on_close_callback(path_type, ch) abort "{{{
    let result = []
    let status = ch_status(a:ch)
    while status is# 'buffered' || status is# 'open'
        try
            let result += [ch_read(a:ch)]
        catch /^Vim\%((\a\+)\)\=:E906/
            break
        endtry
        let status = ch_status(a:ch)
    endwhile
    call s:change_external(a:path_type, result)
endfunction "}}}

" }}}


let &cpoptions = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker shiftwidth=4 expandtab
