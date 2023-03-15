TODO

# vim-hlpairs

vim-hlpairs Highlight the parentheses around the cursor.

<pre><code>
<span style="color:#333;background:#ce9;">if</span>
  echo 'example, cursor is this line.'
<span style="color:#333;background:#ce9;">endif</span>
</code></pre>

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

- `delay` The delay millisecond to hilight.
- `limit` Limit number of rows to search.
- `skip` See `:help searchpair()`
- `filetype` parentheses for file types.

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
}
```

