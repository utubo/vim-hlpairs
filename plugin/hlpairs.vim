vim9script

if exists('g:loaded_hlpairs')
  finish
endif
g:loaded_hlpairs = 1

augroup hlpairs
  au!
  au VimEnter * call hlpairs#Init()
augroup End

