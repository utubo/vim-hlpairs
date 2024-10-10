vim9script

const SEARCH_LINES = 5 # the line count for matchbufline
var timer = 0 # for CursorMoved
var mark = [] # origin cursorpos
var prevent_remark = 0

export def CursorMoved()
  if timer !=# 0
    timer_stop(timer)
  endif
  timer = timer_start(g:hlpairs.delay, HighlightPair)
enddef

def HighlightPair(t: any = 0)
  timer = 0
  try
    if !exists('b:hlpairs')
      OnOptionSet()
    endif
    if !exists('w:hlpairs')
      w:hlpairs = {
        bufnr: bufnr(),
        matchid: 0,
        pos: [],
        pairs: [],
      }
    endif
    const cur = getpos('.')
    if prevent_remark
      prevent_remark -= 1
    else
      mark = cur[:]
    endif
    # const start_time = reltime()
    const b = bufnr()
    const new_pos = FindPairs(b, cur)
    # g:hlpairs.reltimestr = reltimestr(reltime(start_time))
    if w:hlpairs.pos ==# new_pos && w:hlpairs.bufnr ==# b
      # nothing update
      return
    endif
    w:hlpairs.bufnr = b
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

def IsSkip(s: any): bool
  const c = getpos('.')
  setpos('.', [c[0], s.lnum, s.byteidx, c[3]])
  const result = eval(b:hlpairs.skip)
  setpos('.', c)
  return !!result
enddef

def FindPairs(b: number, cur: list<number>): any
  # setup properties
  const cur_lnum = cur[1]
  const cur_byteidx = cur[2] - 1
  const min_lnum = max([1, cur_lnum - g:hlpairs.limit])
  const max_lnum = cur_lnum + g:hlpairs.limit
  const has_skip = !!b:hlpairs.skip
  # find the start
  var offset = cur_lnum
  while min_lnum <= offset
    var starts = matchbufline(
      b,
      b:hlpairs.start_regex,
      max([1, offset - SEARCH_LINES + 1]),
      offset,
      { submatches: true }
    )
    offset -= SEARCH_LINES
    # find the end
    var pairs_cache = {}
    for s in starts->reverse()
      if cur_lnum ==# s.lnum && cur_byteidx < s.byteidx
        continue
      endif
      if has_skip && IsSkip(s)
        continue
      endif
      var pair = GetPair(s.text, pairs_cache)
      if !pair
        break
      endif
      var pos_list = FindEnd(b, max_lnum, s, pair, has_skip)
      if pos_list ==# []
        continue
      endif
      const e = pos_list[-1]
      if cur[1] < e[0] || cur[1] ==# e[0] && cur[2] < e[1] + e[2]
        return pos_list
      endif
    endfor
  endwhile
  return []
enddef

def GetPair(text: string, cache: dict<any>): any
  const pair = get(cache, text, {})
  if !!pair
    return pair
  endif
  for p in b:hlpairs.pairs
    if text =~# p.s
      cache[text] = p
      return p
    endif
  endfor
  return {}
enddef

def ToPosItem(s: any): any
  return [s.lnum, s.byteidx + 1, s.text->len()]
enddef

def FindEnd(b: number, max_lnum: number, s: dict<any>, pair: dict<any>,
has_skip: bool): any
  # setup properties
  const byteidx = s.byteidx + s.text->len()
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
  # find the end
  var pos_list = [ToPosItem(s)]
  var nest = 0
  var offset = s.lnum
  while offset <= max_lnum
    const matches = matchbufline(
      b,
      s_regex .. '\|' .. e_regex .. (has_m ? $'\|{m_regex}' : ''),
      offset,
      offset + SEARCH_LINES - 1,
    )
    offset += SEARCH_LINES
    for ma in matches
      if ma.lnum ==# s.lnum && ma.byteidx < byteidx
        continue
      endif
      if has_skip && IsSkip(ma)
        continue
      endif
      if ma.text =~ e_regex
        if !nest
          pos_list += [ToPosItem(ma)]
          return pos_list
        else
          nest -= 1
          continue
        endif
      endif
      if ma.text =~ s_regex
        nest += 1
        continue
      endif
      if !!nest
        continue
      endif
      if has_m && ma.text =~ m_regex
        pos_list += [ToPosItem(ma)]
      endif
    endfor
  endwhile
  return []
enddef

def ToList(v: any): any
  return type(v) ==# v:t_string ? v->split(',') : v
enddef

def ConstantLength(s: string): number
  return s->stridx('*') ==# -1 && s->stridx('\') ==# -1 ? len(s) : 0
enddef

def OnOptionSet()
  var ftpairs = []
  var ignores = []
  if !!&filetype
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
  endif
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
  # set the new settings
  b:hlpairs = {
    pairs: pairs,
    start_regex: start_regexs->join('\|'),
  }
  if type(g:hlpairs.skip) ==# type({})
    b:hlpairs.skip = get(g:hlpairs.skip, &filetype, get(g:hlpairs.skip, '*', ''))
  else
    b:hlpairs.skip = g:hlpairs.skip
  endif
enddef


def GetPosList(): any
  var p = get(w:, 'hlpairs', { pos: [] }).pos
  if !!p
    return p
  endif
  HighlightPair()
  return w:hlpairs.pos
enddef

export def Jump(flags: string = ''): bool
  const pos_list = GetPosList()
  if !pos_list
    return false
  endif
  var p = []
  const cur = getpos('.')
  if flags =~# 'b'
    for i in range(pos_list->len())->reverse()
      const j = pos_list[i]
      if cur[1] > j[0] || cur[1] ==# j[0] && cur[2] > j[1]
        p = j
        break
      endif
    endfor
  else
    for i in pos_list
      if cur[1] < i[0] || cur[1] ==# i[0] && cur[2] < i[1]
        p = i
        break
      endif
    endfor
  endif
  if !p
    if flags ==# ''
      p = pos_list[0]
    else
      return false
    endif
  endif
  const offset = flags =~# 'e' ? p[2] - 1 : 0
  prevent_remark = 1
  setpos('.', [0, p[0], p[1] + offset])
  return true
enddef

export def ReturnCursor()
  if !!mark
    setpos('.', mark)
  endif
enddef

export def HighlightOuter()
  const p = GetPosList()
  if !p
    return
  endif
  const c = getcurpos()
  prevent_remark = 1
  setpos('.', [0, p[0][0], p[0][1] - 1])
  HighlightPair()
  setpos('.', c)
enddef

def TextObj(a: bool): list<any>
  const p = GetPosList()
  if !p
    return []
  endif
  var [sy, sx, sl] = p[0]
  var [ey, ex, el] = p[-1]
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

