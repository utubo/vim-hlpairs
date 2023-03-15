TODO

# vim-hlpairs

vim-hlpairs highlights the parentheses around the cursor.

```diff
+ if
    echo 'For example, the cursor is on this line.▌'
    # vim-hlpairs highlights "if" and "endif".
    # "+" is for color in markdown.
+ endif
```

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
- `limit` Limit number of lines to search.
- `skip` See `:help searchpair()`
- `filetype` parentheses for file types.
- `as_html` The filetypes that highlight as HTML.

The default is
```vimscript
g:hlpairs = {
  delay: 500,
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

