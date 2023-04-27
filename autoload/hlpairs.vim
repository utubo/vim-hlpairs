vim9script

export def Init()
  const override = get(g:, 'hlpairs', {})
  g:hlpairs = {
    delay: 500,
    timeout: 20,
    limit: 50,
    filetype: {
      'vim': '\<if\>:else:endif,for:endfor,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:endtry',
      'ruby': '\<\(def\|do\|class\|if\)\>:\<end\>',
      '*': '\w\@<!\w*(:)',
    },
    skip: {
      'ruby': 'getline(".") =~ "\\S\\s*if\\s"',
    },
    as_html: ['html', 'xml']
  }
  g:hlpairs->extend(override)
  OptionSet()
  augroup hlpairs
    au!
    au CursorMoved,CursorMovedI * silent! call CursorMoved()
    au OptionSet matchpairs call OptionSet()
    au WinNew,FileType * call OptionSet()
  augroup End
  g:hlpairs.initialized = 1
enddef

var timer = 0
def CursorMoved()
  if timer !=# 0
    timer_stop(timer)
  endif
  timer = timer_start(g:hlpairs.delay, HighlightPair)
enddef

def HighlightPair(t: any = 0)
  timer = 0
  try
    if !exists('g:hlpairs.initialized')
      Init()
      return
    endif
    if !exists('w:hlpairs')
      return
    endif
    const cur = getpos('.')
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
  if pair.is_tag
    s = start_str
    e = '</' .. start_str[1 : ]->substitute('>\?$', '>\\?', '')
  endif
  # find the end
  var epos = searchpairpos(
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

def OptionSet()
  var pairs = []
  const as_html = g:hlpairs.as_html->index(&filetype) !=# -1
  if as_html
    pairs += [{ s: '<[a-zA-Z0-9_:]\+>\?', e: '</>', m: '', slen: 0, elen: 0, is_tag: true }]
    pairs += [{ s: '<!--', e: '-->', m: '', slen: 4, elen: 3, is_tag: false }]
  endif
  const ftpairs = get(g:hlpairs.filetype, &filetype, '')
  for sme in ftpairs->split(',') + g:hlpairs.filetype['*']->split(',') + &matchpairs->split(',')
    if as_html && sme ==# '<:>'
      continue
    endif
    const ary = sme->split(':')
    const start = ary[0]
    const middle = len(ary) ==# 3 ? ary[1] : ''
    const end = ary[-1]
    pairs += [{
      s: start ==# '[' ? '\[' : start,
      m: middle,
      e: end,
      slen: ConstantLength(start),
      elen: ConstantLength(end),
      is_tag: false
    }]
  endfor
  var start_regexs = []
  for p in pairs
    start_regexs += [p.s]
  endfor
  # keep old positions
  w:hlpairs = get(w:, 'hlpairs', {
    matchid: 0,
    pos: [],
    ft: '',
    pairs: [],
    start_regex: '',
  })
  # set the new settings
  w:hlpairs.pairs = pairs
  w:hlpairs.start_regex = start_regexs->join('\|')
  if type(g:hlpairs.skip) ==# type({})
    w:hlpairs.skip = get(g:hlpairs.skip, &filetype, get(g:hlpairs.skip, '*', ''))
  else
    w:hlpairs.skip = g:hlpairs.skip
  endif
enddef

export def Jump(): bool
  HighlightPair()
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

