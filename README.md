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
autocmd VimEnter * nnoremap % <ScriptCmd>call hlpairs#Jump()<CR>
autocmd VimEnter * nnoremap ]% <Cmd>call hlpairs#Jump('f')<CR>
autocmd VimEnter * nnoremap [% <Cmd>call hlpairs#Jump('b')<CR>
nnoremap <Leader>% <Cmd>call hlpairs#HighlightOuter()<CR>
nnoremap <Space>% <Cmd>call hlpairs#ReturnCursor()<CR>
```

`nnoremap %` on VimEnter for override matchit.vim.

## Configuration

### `g:hlpairs`

- `delay` The delay milliseconds to highlight.
- `timeout` The search stops when more than this many milliseconds have passed.
- `limit` Limit number of lines to search.
- `skip` See `:help searchpair()`.
  You can set a string or a dictionary&lt;filetype: expr&gt;.
- `filetype` The parentheses for file types.  
  `*` is any filetype.  
  Value is csv-string or list or dict.
  You can set patterns for ignore with dict.
  - `matchpairs` match pairs.
  - `ignores` the patterns for ignore
  See `:help &matchpairs`

The default is
```vimscript
g:hlpairs = {
  delay: 200,
  timeout: 20,
  limit: 50,
  filetype: {
    'vim': '\<if\>:else:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:endtry',
    'ruby': '\<\(def\|do\|class\|if\)\>:\<end\>',
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

- `hlpairs#Jump([{flags}])` Jump to the far pair.
  - {flags} is a String.
  - 'f' ... Jump forward instead of the far pair
  - 'b' ... Jump backward instead of the far pair
  - 'e' ... Jump to the End of the match
- `hlpairs#HiglihtOuter()`	Highlight the pair outside of the current pair.
- `hlpairs#ReturnCursor()`	Return the cursor before `hlpairs#Jump()`.

## Author
utubo (https://github.com/utubo)

## License
This software is released under the MIT License, see LICENSE.

