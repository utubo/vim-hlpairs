vim9script

if exists('g:loaded_hlpairs')
  finish
endif
g:loaded_hlpairs = 1

const override = get(g:, 'hlpairs', {})
g:hlpairs = {
  key: '%',
  delay: 50,
  limit: 50,
  filetype: {
  'vim': '\<if\>:else\(if\)\?:endif,\<for\>:\<endfor\>,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:\<\(catch\|finally\)\>:\<endtry\>,augroup .*:augroup END',
    'ruby': '\<if\>:\(else\|elsif\):\<end\>,\<\(def\|do\|class\|if\)\>:\<end\>',
    'lua': '\<if\>:\(else\|elseif\):\<end\>,\<\(function\|while\|for\|do\|if\)\>:\<end\>,\[\[:\]\]',
    'html,xml': {
      matchpairs: [
        '\<[a-zA-Z0-9_\:-]\+=":"',
        '<\([a-zA-Z0-9_\:]\+\)\%([^>]*\)>:</\1>',
        '<!--:-->'
      ],
      ignores: '<:>'
    },
    '*': '\w\@<!\w*(:)',
  },
  skip: {
    'ruby': 'getline(".") =~ "\\S\\s*if\\s"',
  },
}
g:hlpairs->extend(override)
augroup hlpairs
  au!
  au CursorMoved,CursorMovedI * silent! call hlpairs#CursorMoved()
  au OptionSet matchpairs silent! unlet b:hlpairs
  au FileType * silent! unlet b:hlpairs
augroup END

if !!g:hlpairs.key
  const k = g:hlpairs.key
  execute $"nnoremap {k} <ScriptCmd>call hlpairs#Jump()<CR>"
  execute $"nnoremap ]{k} <Cmd>call hlpairs#Jump('f')<CR>"
  execute $"nnoremap [{k} <Cmd>call hlpairs#Jump('b')<CR>"
  execute $"nnoremap <Leader>{k} <Cmd>call hlpairs#HighlightOuter()<CR>"
  execute $"nnoremap <Space>{k} <Cmd>call hlpairs#ReturnCursor()<CR>"
  execute $"hlpairs#TextObjUserMap('{k}')"
endif
