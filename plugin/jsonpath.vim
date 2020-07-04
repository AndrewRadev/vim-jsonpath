" plugin/jsonpath.vim
" Author: Victor Hallberg <https://hallberg.cc>

if exists("g:loaded_jsonpath") || v:version < 700 || &cp
  finish
endif
let g:loaded_jsonpath = 1

if !exists('g:jsonpath_delimeter')
  let g:jsonpath_delimeter = '.'
endif

if !exists('g:jsonpath_use_python')
  let g:jsonpath_use_python = has('python3')
endif

" The range functionality messes with the current view, so the command needs to
" store it via winsaveview() so that jsonpath#command() can later restore it.
command! -nargs=? -range=% -complete=custom,s:CompleteJsonPath JsonPath
      \ let b:jsonpath_view = winsaveview() |
      \ <line1>,<line2>call jsonpath#command(<q-args>)

let s:type_list = type([])
let s:type_dict = type({})

function! s:CompleteJsonPath(argument_lead, command_line, cursor_position)
  let file_contents = join(getbufline('%', 0, line('$')), "\n")

  try
    let data = json_decode(file_contents)
  catch /^Vim\%((\a\+)\)\=:E\(491\|938\):/
    " json decode error
    return ''
  endtry

  try
    let keepempty = 1
    let path = split(a:argument_lead, '\.', keepempty)
    let last_key = ''
    if len(path) > 0
      let last_key = remove(path, len(path) - 1)
    endif
    let prefix = join(path, '.')

    " Dereference the path so far
    for key in path
      let data = s:DereferenceKey(data, key)
    endfor

    " Get completions at the current level
    let completions = s:GetCompletionKeys(data)

    " Is the last key a complete match? If so, dereference one more level to
    " get next completions
    if index(completions, last_key) >= 0
      let data = s:DereferenceKey(data, last_key)
      let completions = s:GetCompletionKeys(data)

      if prefix != ''
        let prefix .= '.'.last_key
      else
        let prefix = last_key
      endif
    endif

    " Attach current path to result so Vim can match entire input
    if prefix != ''
      let completions = map(completions, '"'.prefix.'.". v:val')
    endif

    return join(completions, "\n")
  catch /^CompletionError:/
    echomsg v:exception
    return ''
  endtry
endfunction

function! s:DereferenceKey(data, key)
  let data = a:data
  let key = a:key

  if type(data) == s:type_list && key =~# '^\d\+' && len(data) > str2nr(key)
    return data[str2nr(key)]
  elseif type(data) == s:type_dict && has_key(data, key)
    return data[key]
  else
    throw "CompletionError: Couldn't dereference key: " . key
  endif
endfunction

function! s:GetCompletionKeys(data)
  let data = a:data

  if type(data) == s:type_list
    return map(range(0, len(data) - 1), 'string(v:val)')
  elseif type(data) == s:type_dict
    return keys(data)
  else
    throw "CompletionError: Couldn't list completions, key is not an array or dict"
  endif
endfunction

" au FileType json noremap <buffer> <silent> <leader>d :call jsonpath#echo()<CR>
" au FileType json noremap <buffer> <silent> <leader>g :call jsonpath#goto()<CR>

" vim:set et sw=2:
