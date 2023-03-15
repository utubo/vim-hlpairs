vim9script

export def Init()
  const override = get(g:, 'hlpairs', {})
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
  g:hlpairs->extend(override)
  OptionSet()
  augroup hlpairs
    au!
    au CursorMoved,CursorMovedI * silent! call hlpairs#CursorMoved()
    au OptionSet matchpairs call hlpairs#OptionSet()
    au WinNew,FileType * call hlpairs#OptionSet()
  augroup End
enddef

var timer = 0
export def CursorMoved()
  if timer !=# 0
    timer_stop(timer)
  endif
  timer = timer_start(g:hlpairs.delay, HilightParens)
enddef

def HilightParens(t: any = 0)
  timer = 0
  try
    if !exists('w:hlpairs')
      return
    endif
    const cur = getpos('.')
    const new_pos = NewPos(cur[1 : 2])
    setpos('.', cur)
    if w:hlpairs.pos !=# new_pos
      if w:hlpairs.matchid !=# 0
        matchdelete(w:hlpairs.matchid)
        w:hlpairs.matchid = 0
      endif
      if !!new_pos
        w:hlpairs.matchid = matchaddpos('MatchParen', new_pos)
      endif
      w:hlpairs.pos = new_pos
    endif
  catch
    g:hlpairs_err = v:exception
  endtry
enddef

def NewPos(org: list<number>, nest: number = 0): any
  var spos = searchpos(
    w:hlpairs.start_regex,
    'cbW',
    max([0, line('.') - g:hlpairs.limit]),
    g:hlpairs.timeout,
    g:hlpairs.skip
  )
  if spos[0] ==# 0
    return []
  endif
  var pair = {}
  var text = getline(spos[0])
  var idx = spos[1] - 1
  var start_str = ''
  for p in w:hlpairs.pairs
    if match(text, p.s, idx) !=# idx
      continue
    endif
    pair = p
    if !pair.slen
      start_str = matchstr(text, pair.s, idx)
      spos += [start_str->len()]
    else
      start_str = pair.s
      spos += [pair.slen]
    endif
    break
  endfor
  if !pair
    return []
  endif
  var s = pair.s
  var e = pair.e
  if pair.tag
    s = start_str
    e = '</' .. start_str[1 : ]->substitute('>\?$', '>\\?', '')
  endif
  var epos = searchpairpos(
    s, '', e,
    'nW',
    g:hlpairs.skip,
    line('.') + g:hlpairs.limit,
    g:hlpairs.timeout
  )
  text = getline(epos[0])
  if org[0] < epos[0] || org[0] ==# epos[0] && org[1] <= epos[1]
    idx = epos[1] - 1
    if !pair.elen
      epos += [matchstr(text, e, idx)->len()]
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
  var pairs = []
  const as_html = g:hlpairs.as_html->index(&filetype) !=# -1
  if as_html
    pairs += [{ s: '<[a-zA-Z0-9_:]\+>\?', e: '</>', m: '', slen: 0, elen: 0, tag: true }]
    start_regexs += ['<[a-zA-Z0-9_:]\+']
    pairs += [{ s: '<!--', e: '-->', m: '', slen: 4, elen: 3, tag: false }]
    start_regexs += ['<!--']
  endif
  const ftpairs = get(g:hlpairs.filetype, &filetype, '')
  for sme in &matchpairs->split(',') + ftpairs->split(',')
    if as_html && sme ==# '<:>'
      continue
    endif
    const ary = sme->split(':')
    var s = ary[0]
    var m = len(ary) ==# 3 ? ary[1] : ''
    var e = ary[-1]
    const escaped_s = s ==# '[' ? '\[' : s
    pairs += [{ s: escaped_s, e: e, m: m, slen: GetLen(s), elen: GetLen(e), tag: false}]
    start_regexs += [escaped_s]
  endfor
  w:hlpairs = get(w:, 'hlpairs', {
    matchid: 0,
    pos: [],
    ft: '',
    pairs: [],
    start_regex: '',
  })
  w:hlpairs.pairs = pairs
  w:hlpairs.start_regex = start_regexs->join('\|')
enddef

export def Jump(): bool
  HilightParens()
  const p = get(w:, 'hlpairs', { pos: [] }).pos
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

