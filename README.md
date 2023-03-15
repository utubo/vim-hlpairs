TODO

# vim-hlpairs

vim-hlpairs Highlight the parentheses around the cursor.

## Requires

Vim9script

## Installation

```vim
call dein#add('utubo/vim-hlpairs')


# optional
NoMatchParen
nnoremap % <ScriptCmd>call hlpairs#Jump()<CR>
```

## Configuration

### `g:hlpairs`

- `delay` The delay millisecond to hilight.
- `skip` See `:help searchpair()`
- `limit` Limit number of rows to search.
- `filetype` parentheses for file types.

The default is
```vimscript
g:hlpairs = {
skip: '',
filetype: {
  'vim': '\<if\>:else:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef',
  'ruby': '\<\(def\|do\|class\)\>:\<end\>'
},
limit: 50,
delay: 500,
}
```

