vim9script

var pairs = []
var start_regex = ''
var timer = 0

export def Init()
  const override = get(g:, 'hlpairs', {})
  g:hlpairs = {
    skip: '',
    filetype: {
      'vim': '\<if\>:else:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef',
      'ruby': '\<\(def\|do\|class\)\>:\<end\>'
    },
    limit: 50,
    delay: 500,
  }
  g:hlpairs->extend(override)
  OptionSet()
  augroup hlpairs
    au!
    au CursorMoved,CursorMovedI * silent! call hlpairs#CursorMoved()
    au OptionSet matchpairs call hlpairs#OptionSet()
    au FileType * call hlpairs#OptionSet()
  augroup End
enddef

export def CursorMoved()
  if timer !=# 0
    timer_stop(timer)
  endif
  timer = timer_start(g:hlpairs.delay, HilightParens)
enddef

def HilightParens(t: any = 0)
  timer = 0
  try
    const cur = getpos('.')
    const new_pos = NewPos(cur[1 : 2])
    setpos('.', cur)
    if get(w:, 'hlpairs_pos', []) !=# new_pos
      const m = get(w:, 'hlpairs_id', 0)
      if m !=# 0
        matchdelete(m)
        w:hlpairs_id = 0
      endif
      if !!new_pos
        w:hlpairs_id = matchaddpos('MatchParen', new_pos)
      endif
      w:hlpairs_pos = new_pos
    endif
  catch
    g:hlpairs_err = v:exception
  endtry
enddef

def NewPos(org: list<number>, nest: number = 0): any
  var spos = searchpos(start_regex, 'cbW', max([0, line('.') - g:hlpairs.limit]), 20)[0 : 1]
  if spos[0] ==# 0
    return []
  endif
  var pair = {}
  var text = getline(spos[0])
  var idx = spos[1] - 1
  for p in pairs
    if match(text, p.s, idx) ==# idx
      pair = p
      if !pair.slen
        const m = matchstr(text, pair.s, idx)
        spos += [m->len()]
      else
        spos += [pair.slen]
      endif
      break
    endif
  endfor
  if !pair
    return []
  endif
  var epos = searchpairpos(pair.s, '', pair.e, 'nW', '', line('.') + g:hlpairs.limit, 20)
  text = getline(epos[0])
  if org[0] < epos[0] || org[0] ==# epos[0] && org[1] <= epos[1]
    idx = epos[1] - 1
    if !pair.elen
      epos += [matchstr(text, pair.e, idx)->len()]
    else
      epos += [pair.elen]
    endif
    return [spos, epos]
  elseif g:hlpairs.limit < nest
    return []
  else
    if len(text) <= idx
      setpos('.', [0, spos[0] - 1, getline(spos[0] - 1)->len()])
    else
      setpos('.', [0, spos[0], spos[1] - 1])
    endif
    return NewPos(org, nest + 1)
  endif
enddef

def GetLen(s: string): number
  return s->stridx('*') ==# -1 && s->stridx('\') ==# -1 ? len(s) : 0
enddef

export def OptionSet()
  var start_regexs = []
  pairs = []
  const ftpairs = get(g:hlpairs.filetype, &filetype, '')
  for sme in &matchpairs->split(',') + ftpairs->split(',')
    const ary = sme->split(':')
    var s = ary[0]
    var m = len(ary) ==# 3 ? ary[1] : ''
    var e = ary[-1]
    const slen = GetLen(s)
    const elen = GetLen(e)
    s = s ==# '[' ? '\[' : s
    pairs += [{ s: s, e: e, m: m, slen: slen, elen: elen }]
    start_regexs += [s]
  endfor
  start_regex = start_regexs->join('\|')
enddef

export def Jump(): bool
  HilightParens()
  const p = get(w:, 'hlpairs_pos', {})
  if !p
    return false
  endif
  const cy = (p[0][0] + p[1][0]) / 2
  const cx = (p[0][1] + p[1][1]) / 2
  const c = getpos('.')[1 : 2]
  if c[0] < cy || c[0] ==# cy && c[1] < cx
    setpos('.', [0, p[1][0], p[1][1]])
  else
    setpos('.', [0, p[0][0], p[0][1]])
  endif
  return true
enddef

