vim9script

const SEARCH_LINE_COUNT = 5
const PAIRS_CACHE_SIZE = 20
var timer = 0 # for CursorMoved
var mark = [] # origin cursorpos
var prevent_remark = 0
var start_time = reltime()
var timeout_sec = 0.0

export def CursorMoved()
  if timer !=# 0
    timer_stop(timer)
  endif
  timer = timer_start(g:hlpairs.delay, HighlightPair)
enddef

def HighlightPair(t: any = 0)
  timer = 0
  if 0 < g:hlpairs.timeout
    timeout_sec = 0.001 * g:hlpairs.timeout
    start_time = reltime()
  endif
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
    const b = bufnr()
    const new_pos = FindPairs(b, cur)
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
  noautocmd setpos('.', [c[0], s.lnum, s.byteidx + 1, c[3]])
  var result: any = false
  try
    result = eval(b:hlpairs.skip)
  catch
    g:hlpairs_err = v:exception
  finally
    noautocmd setpos('.', c)
  endtry
  return !!result
enddef

export def IsSyn(...names: list<string>): bool
  const name = synID(line("."), col("."), 0)->synIDattr('name')
  for n in names
    if n ==# name
      return true
    endif
  endfor
  return false
enddef

def FixPosList(pos_list: list<any>, pair: any): bool
  # for HTML tag
  if pair.s_full !=# pair.s
    const p = pos_list[0]
    const t = getline(p[0])[p[1] - 1 :]
    const l = t->matchstr(pair.s_full)->len()
    if !l
      return false
    endif
    pos_list[0][2] = l
  endif

  # trim
  for p in pos_list
    const t = trim(p[3])
    if t !=# p[3]
      const s = match(p[3], '\S')
      p[1] += s
      p[2] = len(t)
    endif
  endfor
  return true
enddef

def FindPairs(b: number, cur: list<number>): any
  # setup properties
  const limit = g:hlpairs.limit <= 0 ? line('$') : g:hlpairs.limit
  const cur_lnum = cur[1]
  const cur_byteidx = cur[2] - 1
  const min_lnum = max([1, cur_lnum - limit])
  const max_lnum = cur_lnum + limit
  const has_skip = !!b:hlpairs.skip
  var offset = cur_lnum
  while min_lnum <= offset
    # find the start
    var starts = matchbufline(
      b,
      b:hlpairs.start_regex,
      max([1, offset - SEARCH_LINE_COUNT + 1]),
      offset,
      { submatches: true }
    )
    offset -= SEARCH_LINE_COUNT
    # find the end
    for s in starts->reverse()
      if 0 < g:hlpairs.timeout && timeout_sec < reltimefloat(start_time->reltime())
        return []
      endif
      if cur_lnum ==# s.lnum && cur_byteidx < s.byteidx
        continue
      endif
      if has_skip && IsSkip(s)
        continue
      endif
      var pair = GetPairParams(s.text)
      if !pair
        break
      endif
      var pos_list = FindEnd(b, max_lnum, s, pair, has_skip)
      if pos_list ==# []
        continue
      endif
      const e = pos_list[-1]
      if cur[1] < e[0] || cur[1] ==# e[0] && cur[2] < e[1] + e[2]
        if FixPosList(pos_list, pair)
          return pos_list
        else
          pos_list = []
          continue
        endif
      endif
    endfor
  endwhile
  return []
enddef

def GetPairParams(text: string): any
  const pair = get(b:hlpairs.pairs_cache, text, {})
  if !!pair
    return pair
  endif
  for p in b:hlpairs.pairs
    if text =~# p.s
      const k = b:hlpairs.pairs_cache_keys[0]
      if !!k
        unlet b:hlpairs.pairs_cache[k]
      endif
      unlet b:hlpairs.pairs_cache_keys[0]
      b:hlpairs.pairs_cache[text] = p
      b:hlpairs.pairs_cache_keys += [text]
      return p
    endif
  endfor
  return {}
enddef

def ToPosItem(s: any): any
  return [s.lnum, s.byteidx + 1, s.text->len(), s.text]
enddef

def FindEnd(b: number, max_lnum: number, s: dict<any>, pair: dict<any>, has_skip: bool): any
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
      offset + SEARCH_LINE_COUNT - 1,
    )
    offset += SEARCH_LINE_COUNT
    for ma in matches
      if 0 < g:hlpairs.timeout && timeout_sec < reltimefloat(start_time->reltime())
        return []
      endif
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
    const s_full = ary[0]
    const s = s_full->split('\\%')[0]
    const m = len(ary) ==# 3 ? ary[1] : ''
    const e = ary[-1]
    pairs += [{
      s: s ==# '[' ? '\[' : s,
      s_full: s_full,
      m: m,
      e: e,
      has_matchstr: (e =~# '\\[1-9]') || (m =~# '\\[1-9]'),
      has_m: m !=# ''
    }]
  endfor
  var start_regexs = []
  for p in pairs
    start_regexs += [p.s]
  endfor
  # set the new settings
  b:hlpairs = {
    pairs: pairs,
    pairs_cache: {},
    pairs_cache_keys: repeat([''], PAIRS_CACHE_SIZE),
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

export def HighlightOuter(vcount: number = 1)
  const p = GetPosList()
  if !p
    return
  endif
  if 1 < vcount
    for i in range(vcount)
      HighlightOuter()
    endfor
    return
  endif
  const c = getcurpos()
  prevent_remark = 1
  var [y, x] = p[0][0 : 1]
  x -= 1
  if x <= 1 && 1 < y
    y -= 1
    x = y->getline()->len()
  endif
  noautocmd setpos('.', [0, y, x])
  HighlightPair()
  noautocmd setpos('.', c)
enddef

export def TextObj(around: string, vcount: number = 1)
  const p = GetPosList()
  const lenp = len(p)
  if lenp < 2
    return
  endif
  var a = around
  const count = max([vcount, 1])
  const [buf, cy, cx, offset]  = getpos('.')
  # support v:count
  if (a ==# 'A' || a ==# 'I') && 1 < count
    # ignore sub blocks e.g. `if-elseif-else-endif`
    for i in range(count - 1)
      HighlightOuter()
    endfor
    TextObj(a, 1)
    return
  endif
  if lenp <= count
    HighlightOuter()
    TextObj(around, count - lenp + 1)
    return
  endif
  # default selection
  if lenp ==# count + 1
    a = a->toupper()
  endif
  var [sy, sx, sl, st] = p[0]
  var [ey, ex, el, et] = p[-1]
  # find block
  var index = -1
  if 2 < lenp && (a ==# 'i' || a ==# 'a' || a ==# '')
    for i in range(lenp)
      var [y, x, l, t] = p[i]
      if cy < y || cy ==# y && cx <= x
        index = i - 1
        break
      endif
    endfor
    if index < 0
      return
    endif
    [sy, sx, sl, st] = p[index]
    [ey, ex, el, et] = p[min([index + count, lenp - 1])]
  endif
  if a ==# ''
    [sy, sx, sl, st] = [cy, cx, 0, '']
  endif
  # ready
  var m = mode()
  if m ==# 'v' || m ==# 'V'
    execute 'normal!' m
  else
    m = 'v'
  endif
  noautocmd setpos('.', [buf, ey, ex, offset])
  execute 'normal!' m
  noautocmd setpos('.', [buf, sy, sx, offset])
  # start
  var indent = ''
  if a ==# 'A' || a ==# 'a' && 0 < index
    # nop
  else
    if sl !=# 0
      execute $'normal! {sl}l'
    endif
    if sy + 1 < ey
      # keep linebreak
      normal! j0
      indent = getline(sy)->matchstr('^\s\+')
    endif
  endif
  # end
  if a ==# 'A' || a ==# 'a' && index <= 0
    if 1 < el
      execute $'normal! o{el - 1}l'
    endif
  elseif ex < 2 || getline(ey)[ : ex - 2] ==# indent
    normal! ok$
  else
    normal! oh
  endif
enddef

export def JumpBack()
  Jump('b')
enddef

export def JumpForward()
  Jump('fe')
enddef

export def TextObjUserMap(key: string)
  for o in ['o', 'v']
    for a in ['a', 'i', 'A', 'I']
      execute $'{o}noremap {a}{key} <ScriptCmd>hlpairs#TextObj("{a}", v:count)<CR>'
    endfor
  endfor
  execute $'onoremap {key} <ScriptCmd>hlpairs#TextObj("")<CR>'
enddef

