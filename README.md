# vim-hlpairs

vim-hlpairs highlights the parentheses around the cursor.

<img src="https://user-images.githubusercontent.com/6848636/225357852-5eca2053-ee41-41a3-9d57-d6bd249b29cc.gif" width="400">

## Requires

Vim9script

## Installation

```vim
call dein#add('utubo/vim-hlpairs')


# optional
autocmd VimEnter * silent! NoMatchParen
nnoremap % <ScriptCmd>call hlpairs#Jump()<CR>
```

## Configuration

### `g:hlpairs`

- `delay` The delay milliseconds to highlight.
- `Timeout` The search stops when more than this many milliseconds have passed.
- `limit` Limit number of lines to search.
- `skip` See `:help searchpair()`
- `filetype` parentheses for file types.
- `as_html` The filetypes that highlight as HTML.

The default is
```vimscript
g:hlpairs = {
  delay: 500,
  timeout: 20,
  limit: 50,
  skip: '',
  filetype: {
    'vim': '\<if\>:else:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:endtry',
    'ruby': '\<\(def\|do\|class\)\>:\<end\>'
  },
  as_html: ['html', 'xml']
}
```

### Color
vim-hlsearch uses highlight group `MatchParen`.

## Functions

- `hlpairs#Jump()` Jump to the far pair.

## Author
utubo (https://github.com/utubo)

## License
This software is released under the MIT License, see LICENSE.

