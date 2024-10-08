vim9script

var mark = [] # origin cursorpos
var skip_mark = 0

export def Init()
  const override = get(g:, 'hlpairs', {})
  g:hlpairs = {
    delay: 200,
    limit: 50,
    filetype: {
    'vim': '\<if\>:else\(if\)\?:endif,\<for\>:\<endfor\>,while:endwhile,function:endfunction,\<def\>:enddef,\<try\>:\<catch\>:\<endtry\>',
      'ruby': '\<if\>:\(else\|elsif\):\<end\>,\<\(def\|do\|class\)\>:\<end\>',
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
    const new_pos = FindPairs(cur)
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

def ReplaceMatchGroup(s: string, g: list<string>): string
  return s->substitute('\\[1-9]', (m) => g[str2nr(m[0][1]) - 1]->escape('\'), 'g')
enddef

def FindPairs(cur: list<number>): any
  # find the start
  const b = bufnr()
  const cur_lnum = cur[1]
  const cur_byteidx = cur[2] - 1
  var starts = matchbufline(
    b,
    w:hlpairs.start_regex,
    max([1, cur_lnum - g:hlpairs.limit]),
    cur_lnum,
    { submatches: true }
  )
  if starts ==# []
    return []
  endif
  # find the end
  const max_lnum = cur[1] + g:hlpairs.limit
  var pairs_cache = {}
  for s in starts->reverse()
    if cur_lnum ==# s.lnum && cur_byteidx < s.byteidx
      continue
    endif
    var pair = GetPair(s.text, pairs_cache)
    if !pair
      return []
    endif
    var pos_list = FindEnd(b, max_lnum, s, pair)
    if pos_list ==# []
      continue
    endif
    const e = pos_list[-1]
    if cur[1] < e[0] || cur[1] ==# e[0] && cur[2] <= e[1] + e[2]
      return pos_list
    endif
  endfor
  return []
enddef

def GetPair(text: string, cache: dict<any>): any
  var pair = get(cache, text, {})
  if !!pair
    return pair
  endif
  for p in w:hlpairs.pairs
    if text !~# p.s
      continue
    endif
    pair = p
  endfor
  cache[text] = pair
  return pair
enddef

def ToPosItem(s: any): any
  return [s.lnum, s.byteidx + 1, s.text->len()]
enddef

def FindEnd(b: number, max_lnum: number, s: dict<any>, pair: dict<any>): any
  var s_regex = pair.s
  var e_regex = pair.e
  var m_regex = pair.m
  const has_m = pair.has_m
  if pair.has_matchstr
    s_regex = s.text->escape('.\*\')
    e_regex = ReplaceMatchGroup(pair.e, s.submatches)
    if has_m
      m_regex = ReplaceMatchGroup(pair.m, s.submatches)
    endif
  endif
  const matches = matchbufline(
    b,
    s_regex .. '\|' .. e_regex .. (has_m ? $'\|{m_regex}' : ''),
    s.lnum,
    max_lnum,
  )
  if matches ==# []
    return []
  endif
  var pos_list = [ToPosItem(s)]
  var level = 0
  const min_col = s.byteidx + s.text->len()
  for ma in matches
    if ma.lnum ==# s.lnum && ma.byteidx < min_col
      continue
    endif
    if ma.text =~ e_regex
      if !level
        pos_list += [ToPosItem(ma)]
        return pos_list
      else
        level -= 1
        continue
      endif
    endif
    if ma.text =~ s_regex
      level += 1
      continue
    endif
    if !!level
      continue
    endif
    if !!has_m && ma.text =~ m_regex
      pos_list += [ToPosItem(ma)]
    endif
  endfor
  return []
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

def ConstantLength(s: string): number
  return s->stridx('*') ==# -1 && s->stridx('\') ==# -1 ? len(s) : 0
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
      has_matchstr: (end =~# '\\[1-9]') || (middle =~# '\\[1-9]'),
      has_m: middle !=# ''
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
  const pos_list = GetWindowValues(true).pos
  if !pos_list
    return false
  endif
  var index = 0
  const cur = getpos('.')
  if flags =~# 'b'
    for i in range(1, pos_list->len())
      const p = pos_list[pos_list->len() - i]
      if cur[1] > p[0] || cur[1] ==# p[0] && cur[2] >= p[1]
        break
      endif
      index -= 1
    endfor
  else
    for p in pos_list
      if cur[1] < p[0] || cur[1] ==# p[0] && cur[2] < p[1]
        break
      endif
      index += 1
    endfor
  endif
  index = (index + pos_list->len()) % pos_list->len()
  const offset = flags =~# 'e' ? pos_list[index][2] - 1 : 0
  skip_mark = 1
  setpos('.', [0, pos_list[index][0], pos_list[index][1] + offset])
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

