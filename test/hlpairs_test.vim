vim9script

var suite = themis#suite('Test hlpairs')
const assert = themis#helper('assert')

# setup test {{{
execute 'source' expand('<sfile>:p:h:h') .. '/plugin/hlpairs.vim'
execute 'source' expand('<sfile>:p:h:h') .. '/autoload/hlpairs.vim'

suite.before = () => {
  g:hlpairs.delay = 1
  nnoremap % <ScriptCmd>call hlpairs#Jump()<CR>
  nnoremap ]% <Cmd>call hlpairs#Jump('f')<CR>
  nnoremap [% <Cmd>call hlpairs#Jump('b')<CR>
  nnoremap <Leader>% <Cmd>call hlpairs#HighlightOuter(v:count)<CR>
  nnoremap <Space>% <Cmd>call hlpairs#ReturnCursor()<CR>
  # hlpairs#TextObjUserMap('%')
}

suite.after = () => {
}

suite.before_each = () => {
  normal! ggdG
  append(0, 'if test')
  append(1, '  if nest')
  append(2, '    oneline((a) => ((a ? 1 : 0)))')
  append(3, '  endif')
  append(4, 'elseif test2')
  append(5, '  nop')
  append(6, 'endif')
  normal gg
  set ft=vim
  doautocmd Filetype vim
  doautocmd SafeState *
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
  assert.equals(getpos('.')[1 : 2], [3, 32], 'jump to right paren with %')
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

suite.HighlightOuterWithVcount = () => {
  feedkeys('jj$h', 'xt')
  doautocmd CursorMoved *
  feedkeys('2\%', 'xt')
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [4, 3], 'jump to endif with %')
  feedkeys('%', 'xt')
  assert.equals(getpos('.')[1 : 2], [2, 3], 'jump to if with %')
}

suite.TextObjInner = () => {
  feedkeys('5j', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('yi%', 'xt')
  assert.equals(@", "  nop\n", 'select inner')
}

suite.TextObjAroundElseif = () => {
  feedkeys('5j', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('ya%', 'xt')
  assert.equals(@", "elseif test2\n  nop\n", 'select around elseif')
}

suite.TextObjAroundIfThen = () => {
  feedkeys('j', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('ya%', 'xt')
  assert.equals(@", (getline(2, 4) + ['elseif'])->join("\n"), 'select around if-then')
}

suite.TextObjAroundAll = () => {
  feedkeys('j', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('yA%', 'xt')
  assert.equals(@", getline(1, 7)->join("\n"), 'select around all')
}

suite.TextObjWithVcount = () => {
  feedkeys('jj$hhh', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('2yi%', 'xt')
  assert.equals(@", '(a ? 1 : 0)', 'select with vcount')
}

suite.TextObjFromCursor = () => {
  feedkeys('jj$5h', 'xt')
  doautocmd CursorMoved *
  sleep 2m
  feedkeys('2y%', 'xt')
  assert.equals(@", ': 0', 'select with from cursor')
}

