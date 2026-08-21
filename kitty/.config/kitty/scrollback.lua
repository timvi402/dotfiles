-- init file for the nvim instance kitty launches as `scrollback_pager`.
--
-- Kitty pipes the scrollback in on stdin *with* its SGR escapes. The old config
-- rendered those by handing the text to `:terminal cat`, which meant the buffer
-- held the emulator's SCREEN rather than the text: a 300-char line came out as
-- four hard-wrapped 80-column buffer lines, so anything copied out of it carried
-- line breaks that were never in the original.
--
-- This parses the escapes instead and paints them with extmarks. The buffer ends
-- up holding plain text -- one buffer line per real line, byte-exact on yank --
-- while still rendering in colour.
--
-- Palette comes from `kitty @ get-colors` over KITTY_LISTEN_ON, so indexed
-- colours resolve to whatever matugen last wrote rather than to a hardcoded set.

local o = vim.opt
o.swapfile      = false   -- belt and braces; the -n flag already does this
o.number        = false
o.list          = false
o.wrap          = false   -- one buffer line == one screen row, so a kitty mouse
                          -- drag cannot invent breaks. `:set wrap` to reflow.
o.showtabline   = 0
o.laststatus    = 0
o.ruler         = false
o.showcmd       = false
o.foldcolumn    = '0'
o.signcolumn    = 'no'
o.termguicolors = true
o.clipboard     = 'unnamedplus'
o.fillchars     = { eob = ' ' }
o.mouse         = ''      -- leave dragging to kitty's own selection
o.scrolloff     = 0

---------------------------------------------------------------------------
-- palette
---------------------------------------------------------------------------

local palette = {}
local default_fg, default_bg = '#c0c0c0', '#000000'

do
  local fallback = {
    '#000000', '#cc0000', '#4e9a06', '#c4a000', '#3465a4', '#75507b', '#06989a', '#d3d7cf',
    '#555753', '#ef2929', '#8ae234', '#fce94f', '#729fcf', '#ad7fa8', '#34e2e2', '#eeeeec',
  }
  for i = 0, 15 do palette[i] = fallback[i + 1] end

  local ok, res = pcall(function()
    return vim.system({ 'kitty', '@', 'get-colors' }, { text = true }):wait(1000)
  end)
  if ok and res and res.code == 0 and res.stdout then
    for key, hex in res.stdout:gmatch('(%S+)%s+(#%x%x%x%x%x%x)') do
      local n = key:match('^color(%d+)$')
      if n and tonumber(n) <= 15 then
        palette[tonumber(n)] = hex
      elseif key == 'foreground' then
        default_fg = hex
      elseif key == 'background' then
        default_bg = hex
      end
    end
  end
end

local CUBE = { 0, 95, 135, 175, 215, 255 }

local function idx_to_hex(n)
  if n < 16 then return palette[n] end
  if n < 232 then
    n = n - 16
    return string.format('#%02x%02x%02x',
      CUBE[math.floor(n / 36) % 6 + 1],
      CUBE[math.floor(n / 6) % 6 + 1],
      CUBE[n % 6 + 1])
  end
  local v = math.min(255, 8 + (n - 232) * 10)
  return string.format('#%02x%02x%02x', v, v, v)
end

local function blend(a, b, t)
  local function ch(hex, i) return tonumber(hex:sub(i, i + 1), 16) or 0 end
  return string.format('#%02x%02x%02x',
    math.floor(ch(a, 2) + (ch(b, 2) - ch(a, 2)) * t + 0.5),
    math.floor(ch(a, 4) + (ch(b, 4) - ch(a, 4)) * t + 0.5),
    math.floor(ch(a, 6) + (ch(b, 6) - ch(a, 6)) * t + 0.5))
end

---------------------------------------------------------------------------
-- SGR state -> highlight group
---------------------------------------------------------------------------

local hl_cache, hl_seq = {}, 0

local function hl_for(st)
  if st.fg == nil and st.bg == nil and st.sp == nil and not st.bold and not st.dim
     and not st.italic and st.underline == nil and not st.reverse and not st.strike then
    return nil
  end

  local key = table.concat({
    st.fg or '', st.bg or '', st.sp or '', st.underline or '',
    st.bold and 'b' or '', st.dim and 'd' or '', st.italic and 'i' or '',
    st.reverse and 'r' or '', st.strike and 's' or '',
  }, '|')

  local group = hl_cache[key]
  if group then return group end

  hl_seq = hl_seq + 1
  group = 'KittyScrollback' .. hl_seq

  local fg = st.fg
  if st.dim then fg = blend(fg or default_fg, st.bg or default_bg, 0.45) end

  local spec = {
    fg = fg, bg = st.bg, sp = st.sp,
    bold = st.bold or nil,
    italic = st.italic or nil,
    reverse = st.reverse or nil,
    strikethrough = st.strike or nil,
  }
  if     st.underline == 'single' then spec.underline    = true
  elseif st.underline == 'double' then spec.underdouble  = true
  elseif st.underline == 'curl'   then spec.undercurl    = true
  elseif st.underline == 'dot'    then spec.underdotted  = true
  elseif st.underline == 'dash'   then spec.underdashed  = true end

  vim.api.nvim_set_hl(0, group, spec)
  hl_cache[key] = group
  return group
end

local function apply_sgr(params, st)
  if params == '' then params = '0' end

  local groups = {}
  for g in (params .. ';'):gmatch('([^;]*);') do groups[#groups + 1] = g end

  local i = 1
  while i <= #groups do
    local sub = {}
    for s in (groups[i] .. ':'):gmatch('([^:]*):') do sub[#sub + 1] = tonumber(s) or -1 end

    local n = sub[1]
    if n < 0 then n = 0 end

    if n == 38 or n == 48 or n == 58 then
      local slot = (n == 38 and 'fg') or (n == 48 and 'bg') or 'sp'
      if #sub > 1 then
        -- colon form, self-contained: 38:5:N / 38:2:R:G:B / 38:2:cs:R:G:B
        if sub[2] == 2 then
          local off = (#sub >= 6) and 3 or 2
          st[slot] = string.format('#%02x%02x%02x',
            math.max(0, sub[off + 1]), math.max(0, sub[off + 2]), math.max(0, sub[off + 3]))
        elseif sub[2] == 5 then
          st[slot] = idx_to_hex(math.max(0, sub[3]))
        end
        i = i + 1
      else
        -- semicolon form: consumes the parameters that follow
        local mode = tonumber(groups[i + 1])
        if mode == 2 then
          st[slot] = string.format('#%02x%02x%02x',
            tonumber(groups[i + 2]) or 0, tonumber(groups[i + 3]) or 0, tonumber(groups[i + 4]) or 0)
          i = i + 5
        elseif mode == 5 then
          st[slot] = idx_to_hex(tonumber(groups[i + 2]) or 0)
          i = i + 3
        else
          i = i + 1
        end
      end
    else
      if n == 0 then
        for k in pairs(st) do st[k] = nil end
      elseif n == 1 then st.bold = true
      elseif n == 2 then st.dim = true
      elseif n == 3 then st.italic = true
      elseif n == 4 then
        local style = sub[2]
        if     style == 0 then st.underline = nil
        elseif style == 2 then st.underline = 'double'
        elseif style == 3 then st.underline = 'curl'
        elseif style == 4 then st.underline = 'dot'
        elseif style == 5 then st.underline = 'dash'
        else                   st.underline = 'single' end
      elseif n == 7  then st.reverse = true
      elseif n == 9  then st.strike = true
      elseif n == 21 then st.underline = 'double'
      elseif n == 22 then st.bold, st.dim = nil, nil
      elseif n == 23 then st.italic = nil
      elseif n == 24 then st.underline = nil
      elseif n == 27 then st.reverse = nil
      elseif n == 29 then st.strike = nil
      elseif n == 39 then st.fg = nil
      elseif n == 49 then st.bg = nil
      elseif n == 59 then st.sp = nil
      elseif n >= 30  and n <= 37  then st.fg = palette[n - 30]
      elseif n >= 40  and n <= 47  then st.bg = palette[n - 40]
      elseif n >= 90  and n <= 97  then st.fg = palette[n - 90 + 8]
      elseif n >= 100 and n <= 107 then st.bg = palette[n - 100 + 8]
      end
      i = i + 1
    end
  end
end

---------------------------------------------------------------------------
-- scan the piped-in lines: strip escapes, remember spans
---------------------------------------------------------------------------

local ESC = '\27'

local function render(lines)
  local st, out, marks = {}, {}, {}

  for row, raw in ipairs(lines) do
    local line = raw:gsub('\r$', '')
    local chunks, col, i, len = {}, 0, 1, #line
    local span_start, span_hl = 0, hl_for(st)
    local first_mark = #marks + 1

    local function close(at)
      if span_hl and at > span_start then
        marks[#marks + 1] = { row - 1, span_start, at, span_hl }
      end
    end

    while i <= len do
      if line:sub(i, i) == ESC then
        local nxt = line:sub(i + 1, i + 1)
        if nxt == '[' then
          local params, final, j = line:match('^\27%[([0-9;:<=>?]*)([@-~])()', i)
          if final then
            if final == 'm' then
              close(col)
              apply_sgr(params, st)
              span_start, span_hl = col, hl_for(st)
            end
            i = j
          else
            i = i + 1
          end
        elseif nxt == ']' then
          -- OSC (hyperlinks, title sets): runs to BEL or ST
          i = line:match('^\27%].-\7()', i) or line:match('^\27%].-\27\\()', i) or (len + 1)
        elseif nxt == 'P' or nxt == 'X' or nxt == '^' or nxt == '_' then
          i = line:match('^\27.-\27\\()', i) or (len + 1)
        else
          i = i + 2
        end
      else
        local j = line:find(ESC, i, true) or (len + 1)
        local chunk = line:sub(i, j - 1)
        chunks[#chunks + 1] = chunk
        col = col + #chunk
        i = j
      end
    end
    close(col)

    -- kitty pads every line out to the window width; that padding is what makes
    -- copied text ragged, and it carries no information.
    local text = (table.concat(chunks):gsub('%s+$', ''))
    out[#out + 1] = text

    local width = #text
    for k = #marks, first_mark, -1 do
      local m = marks[k]
      if m[2] >= width then
        table.remove(marks, k)
      elseif m[3] > width then
        m[3] = width
      end
    end
  end

  while #out > 1 and out[#out] == '' do
    table.remove(out)
  end

  return out, marks
end

---------------------------------------------------------------------------

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.api.nvim_set_hl(0, 'Normal',      { fg = default_fg, bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'NonText',     { fg = 'NONE', bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'EndOfBuffer', { link = 'NonText' })

    local buf = vim.api.nvim_get_current_buf()
    local ns  = vim.api.nvim_create_namespace('kitty_scrollback')
    local out, marks = render(vim.api.nvim_buf_get_lines(buf, 0, -1, false))

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)

    local rows = #out
    for _, m in ipairs(marks) do
      if m[1] < rows then
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, m[1], m[2],
          { end_col = m[3], hl_group = m[4] })
      end
    end

    vim.bo[buf].modified   = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].buftype    = 'nofile'
    vim.bo[buf].bufhidden  = 'wipe'

    vim.keymap.set('n', 'q', '<Cmd>qa!<CR>', { silent = true, buffer = buf })
    vim.cmd('normal! G')
  end,
})
