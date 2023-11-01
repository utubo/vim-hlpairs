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
nnoremap <Leader>% <ScriptCmd>call hlpairs#HighlightOuter()<CR>
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
- `as_html` The filetypes that highlight as HTML.

The default is
```vimscript
g:hlpairs = {
  delay: 200,
  timeout: 20,
  limit: 50,
  filetype: {
    'vim': '\<if\>:else:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:endtry',
    'ruby': '\<\(def\|do\|class\|if\)\>:\<end\>',
    '*': '\w\@<!\w*(:)',
  },
  skip: {
    'ruby': 'getline(".") =~ "\\S\\s*if\\s"',
  },
  as_html: ['html', 'xml']
}
```

### Color
vim-hlpairs uses highlight group `MatchParen`.

## Functions

- `hlpairs#Jump()` Jump to the far pair.

- `hlpairs#HiglihtOuter()`	Highlight the pair outside of the current pair.

## Author
utubo (https://github.com/utubo)

## License
This software is released under the MIT License, see LICENSE.

