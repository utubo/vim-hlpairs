vim9script

var mark = [] # origin cursorpos
var skip_mark = 0

export def Init()
  const override = get(g:, 'hlpairs', {})
  g:hlpairs = {
    delay: 200,
    timeout: 20,
    limit: 50,
    filetype: {
      'vim': '\<if\>:else:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:endtry',
      'ruby': '\<\(def\|do\|class\|if\)\>:\<end\>',
      'html,xml': {
        matchpairs: [
          '\<[a-zA-Z0-9_\:-]\+=":"',
          '<\([a-zA-Z0-9_\:]\+\)>\?:</\1>',
          '<!--:-->'
        ],
        ignores: '<:>'
      },
      '*': '\w\@<!\w*(:)',
    },
    skip: {
      'ruby': 'getline(".") =~ "\\S\\s*if\\s"',
    },
  }
  g:hlpairs->extend(override)
  OptionSet()
  augroup hlpairs
    au!
    au CursorMoved,CursorMovedI * silent! call CursorMoved()
    au OptionSet matchpairs call OptionSet()
    au WinNew,FileType * call OptionSet()
  augroup End

  if !!g:hlpairs
  endif

  g:hlpairs.initialized = 1
enddef

var timer = 0
def CursorMoved()
  if timer !=# 0
    timer_stop(timer)
    timer = 0
  endif
  timer = timer_start(g:hlpairs.delay, HighlightPair)
enddef

def HighlightPair(t: any = 0)
  try
    if !exists('g:hlpairs.initialized')
      Init()
      return
    endif
    if !exists('w:hlpairs')
      return
    endif
    const cur = getpos('.')
    if skip_mark
      skip_mark -= 1
    else
      mark = cur[:]
    endif
    const new_pos = FindPairs(cur[1 : 2])
    setpos('.', cur)
    if w:hlpairs.pos ==# new_pos
      # nothing update
      return
    endif
    w:hlpairs.pos = new_pos
    if w:hlpairs.matchid !=# 0
      matchdelete(w:hlpairs.matchid)
      w:hlpairs.matchid = 0
    endif
    if !!new_pos
      w:hlpairs.matchid = matchaddpos('MatchParen', new_pos)
    endif
  catch
    g:hlpairs_err = v:exception
  endtry
enddef

def FindPairs(org: list<number>, nest: number = 0): any
  # find the start
  var spos = searchpos(
    w:hlpairs.start_regex,
    'cbW',
    max([0, line('.') - g:hlpairs.limit]),
    g:hlpairs.timeout,
    w:hlpairs.skip
  )
  if spos[0] ==# 0
    return []
  endif
  # get the pair of start
  var pair = {}
  var text = getline(spos[0])
  var idx = spos[1] - 1
  var start_matches = []
  var start_str = ''
  var slen = 0
  for p in w:hlpairs.pairs
    if match(text, p.s, idx) !=# idx
      continue
    endif
    pair = p
  endfor
  if !pair
    return []
  endif
  if !pair.slen
    start_matches = matchlist(text, pair.s, idx)
    start_str = start_matches[0]
    slen = start_str->len()
  else
    start_str = pair.s
    slen = pair.slen
  endif
  spos += [slen]
  var s = pair.s
  var e = pair.e
  if pair.e_has_matchstr
    # Replace `\1` for searchpairpos()
    e = e->substitute('\\[1-9]', (m) => start_matches[str2nr(m[0][1])], 'g')
    # Replace `\(...\)` for seachpairpos()
    for m in start_matches[1 : count(s, '\(')]->reverse()
      s = s->substitute('^\(.*\)\\([^)]*\\)', $'\1{m}', '')
    endfor
  endif
  # find the end
  var epos = []
  if e ==# start_str[slen - pair.elen :]
    # searchpairpos() does not work the start-word ends with the end-word,
    # so search end-word after start-word.
    e = $'\(\%{spos[0]}l\%{spos[1] + spos[2]}c.*\)\@<={e}\|\%{spos[0] + 1}l\@<={e}'
  endif
  epos = searchpairpos(
    s, '', e,
    'nW',
    w:hlpairs.skip,
    org[0] + g:hlpairs.limit,
    g:hlpairs.timeout
  )
  text = getline(epos[0])
  idx = epos[1] - 1
  if epos[0] !=# 0 && !pair.elen
    epos += [matchstr(text, e, idx)->len()]
  else
    epos += [pair.elen]
  endif
  if org[0] < epos[0] || org[0] ==# epos[0] && org[1] <= idx + epos[2]
    return [spos, epos]
  elseif g:hlpairs.limit < nest
    return []
  else
    if text->len() <= idx
      setpos('.', [0, spos[0] - 1, getline(spos[0] - 1)->len()])
    else
      setpos('.', [0, spos[0], spos[1] - 1])
    endif
    return FindPairs(org, nest + 1)
  endif
enddef

def ConstantLength(s: string): number
  return s->stridx('*') ==# -1 && s->stridx('\') ==# -1 ? len(s) : 0
enddef

def GetWindowValues(retry: bool = false): any
  var w = get(w:, 'hlpairs', {
    matchid: 0,
    pos: [],
    pairs: [],
    start_regex: '',
  })
  if !!w.pos || !retry
    return w
  endif
  HighlightPair()
  return GetWindowValues()
enddef

def ToList(v: any): any
  return type(v) ==# v:t_string ? v->split(',') : v
enddef

def OptionSet()
  var ftpairs = []
  var ignores = []
  for [k, v] in g:hlpairs.filetype->items()
    if k->split(',')->index(&filetype) !=# -1
      if type(v) ==# v:t_dict
        ftpairs += v.matchpairs->ToList()
        ignores += get(v, 'ignores', '')->ToList()
      else
        ftpairs += v->ToList()
      endif
    endif
  endfor
  ftpairs += g:hlpairs.filetype['*']->ToList()
  ftpairs += &matchpairs->split(',')
  var pairs = []
  for sme in ftpairs
    if ignores->index(sme) !=# -1
      continue
    endif
    const ary = sme->split('\\\@<!:')
    const start = ary[0]
    const middle = len(ary) ==# 3 ? ary[1] : ''
    const end = ary[-1]
    pairs += [{
      s: start ==# '[' ? '\[' : start,
      m: middle,
      e: end,
      slen: ConstantLength(start),
      elen: ConstantLength(end),
      e_has_matchstr: (end =~# '\\[1-9]')
    }]
  endfor
  var start_regexs = []
  for p in pairs
    start_regexs += [p.s]
  endfor
  # keep old positions
  w:hlpairs = GetWindowValues()
  # set the new settings
  w:hlpairs.pairs = pairs
  w:hlpairs.start_regex = start_regexs->join('\|')
  if type(g:hlpairs.skip) ==# type({})
    w:hlpairs.skip = get(g:hlpairs.skip, &filetype, get(g:hlpairs.skip, '*', ''))
  else
    w:hlpairs.skip = g:hlpairs.skip
  endif
enddef

export def Jump(flags: string = ''): bool
  const p = GetWindowValues(true).pos
  if !p
    return false
  endif
  var index = 0
  if flags =~# 'f'
    index = 1
  elseif flags =~# 'b'
    index = 0
  else
    const cy = (p[0][0] + p[1][0]) / 2.0
    const cx = (p[0][1] + p[1][1]) / 2.0
    const [y, x] = getpos('.')[1 : 2]
    index = (y < cy || y ==# cy && x < cx) ? 1 : 0
  endif
  var offset = flags =~# 'e' ? p[index][2] - 1 : 0
  skip_mark = 1
  setpos('.', [0, p[index][0], p[index][1] + offset])
  return true
enddef

export def ReturnCursor()
  if !!mark
    setpos('.', mark)
  endif
enddef

export def HighlightOuter()
  const p = GetWindowValues(true).pos
  if !p
    return
  endif
  const c = getcurpos()
  skip_mark = 1
  setpos('.', [0, p[0][0], p[0][1] - 1])
  HighlightPair()
  setpos('.', c)
enddef

def TextObj(a: bool): list<any>
  const p = GetWindowValues(true).pos
  if !p
    return []
  endif
  var [sy, sx, sl] = p[0]
  var [ey, ex, el] = p[1]
  if a
    ex += el - 1
  else
    sx += sl
    ex -= 1
    if ex ==# 0
      ey -= 1
      ex = getline(ey)->len()
    endif
  endif
  const c = getpos('.')
  return [
    'v',
    [c[0], sy, sx, c[3]],
    [c[0], ey, ex, c[3]],
  ]
enddef

export def TextObjA(): list<any>
  return TextObj(true)
enddef

export def TextObjI(): list<any>
  return TextObj(false)
enddef

export def TextObjUserMap(key: string)
  textobj#user#plugin('hlpairs', {
    '-': {
      'select-a': $'a{key}',
      'select-a-function': 'hlpairs#TextObjA',
      'select-i': $'i{key}',
      'select-i-function': 'hlpairs#TextObjI',
    },
  })
enddef

