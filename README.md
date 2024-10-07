# vim-hlpairs

vim-hlpairs highlights the parentheses around the cursor.

<img src="https://user-images.githubusercontent.com/6848636/225357852-5eca2053-ee41-41a3-9d57-d6bd249b29cc.gif" width="400">

## Requirements

Vim9script

## Installation

```vim
call dein#add('utubo/vim-hlpairs')
# optional
g:loaded_matchparen = 1
g:loaded_matchit = 1
nnoremap % <ScriptCmd>call hlpairs#Jump()<CR>
nnoremap ]% <Cmd>call hlpairs#Jump('f')<CR>
nnoremap [% <Cmd>call hlpairs#Jump('b')<CR>
nnoremap <Leader>% <Cmd>call hlpairs#HighlightOuter()<CR>
nnoremap <Space>% <Cmd>call hlpairs#ReturnCursor()<CR>
autocmd VimEnter * hlpairs#TextObjUserMap('%')
```

## Configuration

### `g:hlpairs`

- `delay` The delay milliseconds to highlight.
- `timeout` The search stops when more than this many milliseconds have passed.
- `limit` Limit number of lines to search.
- `skip` You can set a string or a dict&lt;filetype: expr&gt;.  
  See `:help searchpair()`.
- `filetype` The parentheses for file types.  
  `*` is any filetype.  
  The values are csv-string or list or dict.  
  You can set patterns for ignore with dict.  
  - `matchpairs` match pairs.  
  - `ignores` the patterns for ignore

  You can use `\1` in the end or pair,
  but it won't work perfectly, so use `\V`.  
  See `:help mps`, See `:help \\V`

The default is
```vimscript
g:hlpairs = {
  delay: 150,
  timeout: 20,
  limit: 50,
  filetype: {
    'vim': '\<if\>:else\(if\)\?:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:endtry',
    'ruby': '\<if\>:\(else\|elsif\):\<end\>,\<\(def\|do\|class\)\>:\<end\>',
    'html,xml': {
      matchpairs: [
        '\<[a-zA-Z0-9_\:-]\+=":"',
        '<\([a-zA-Z0-9_\:]\+\)>\?:</\1>',
        '<!--:-->'
      ],
      ignores: '<:>'
    },
    '*': '\w\@<!\w*(:)',
  },
  skip: {
    'ruby': 'getline(".") =~ "\\S\\s*if\\s"',
  }
}
```

### Color
vim-hlpairs uses highlight group `MatchParen`.

## Functions

- `hlpairs#Jump([{flags}])` Jump to the next paren.
  - {flags} is a String.
  - 'f': Jump the next paren.
  - 'b': Jump the previous paren.
  - 'e': Jump to the end of the match.
- `hlpairs#HiglihtOuter()` Highlight the pair outside of the current pair.
- `hlpairs#ReturnCursor()` Return the cursor before `hlpairs#Jump()`.
- `hlpairs#TextObjUserMap({key})` Call `textobj#user#map()` to mapping to $'a{key}' and $'i{key}'.

## Author
utubo (https://github.com/utubo)

## License
This software is released under the MIT License, see LICENSE.

