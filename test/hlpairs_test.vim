vim9script

var suite = themis#suite('Test hlpairs')
const assert = themis#helper('assert')

# setup test {{{
execute 'source' expand('<sfile>:p:h:h') .. '/plugin/hlpairs.vim'
execute 'source' expand('<sfile>:p:h:h') .. '/autoload/hlpairs.vim'
hlpairs#Init()

suite.before = () => {
  g:hlpairs.delay = 1
  nnoremap % <ScriptCmd>call hlpairs#Jump()<CR>
  nnoremap ]% <Cmd>call hlpairs#Jump('f')<CR>
  nnoremap [% <Cmd>call hlpairs#Jump('b')<CR>
  nnoremap <Leader>% <Cmd>call hlpairs#HighlightOuter()<CR>
  nnoremap <Space>% <Cmd>call hlpairs#ReturnCursor()<CR>
  # hlpairs#TextObjUserMap('%')
}

suite.after = () => {
}

suite.before_each = () => {
  normal! ggdG
  append(0, 'if test')
  append(1, '  if nest')
  append(2, '    oneline((a) => (a ? 1 : 0))')
  append(3, '  endif')
  append(4, 'elseif test2')
  append(5, '  nop')
  append(6, 'endif')
  normal gg
  set ft=vim
}

#}}}

suite.Jump = () => {
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [5, 1], 'jump to elseif with %')
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [7, 1], 'jump to endif with %')
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [1, 1], 'jump to if with %')
}

suite.JumpInNested = () => {
  feedkeys('jj', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [4, 3], 'jump to endif with %')
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [2, 3], 'jump to if with %')
}

suite.JumpInOneline = () => {
  feedkeys('jj$h', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [3, 20], 'jump to left paren with %')
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [3, 30], 'jump to right paren with %')
}

suite.JumpForward = () => {
  doautocmd CursorMoved *
  sleep 2m
  feedkeys(']%', 'xt')
  assert.equals(getpos('.')[1 : 2], [5, 1], 'jump to elseif with %')
  feedkeys(']%', 'xt')
  assert.equals(getpos('.')[1 : 2], [7, 1], 'jump to endif with %')
  feedkeys(']%', 'xt')
  assert.equals(getpos('.')[1 : 2], [7, 1], 'not jump to if with %')
}

suite.JumpBack = () => {
  feedkeys('Gk', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('[%', 'xt')
  assert.equals(getpos('.')[1 : 2], [5, 1], 'jump to elseif with %')
  feedkeys('[%', 'xt')
  assert.equals(getpos('.')[1 : 2], [1, 1], 'jump to if with %')
  feedkeys('[%', 'xt')
  assert.equals(getpos('.')[1 : 2], [1, 1], 'not jump to endif with %')
}

suite.HighlightOuter = () => {
  feedkeys('jj$h', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  call hlpairs#HighlightOuter()
  call hlpairs#HighlightOuter()
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [4, 3], 'jump to endif with %')
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [2, 3], 'jump to if with %')
}

