-- 蘋果速成 / Apple SuCheng · Author: Kanaoda
-- 1) 關聯字：首選右側顯示「Shift + 數字鍵」（不要底部 prompt）
-- 2) 可展開時顯示「→展開」（收起態）；展開後提示改由面板頂列「←收起」，避免表格欄位被撐歪
-- 3) 字表每頁固定格數（收起 9／展開 45）
-- 4) 單碼不顯示選字表，但仍維持中文字碼預編輯（避免 void 段掉回英文 a-z）
local HINT_SHIFT = "Shift + 數字鍵"
local HINT_EXPAND = "→展開"
local HINT_COLLAPSE = nil  -- 展開後不塞進候選 comment，改由面板顯示
local PAD_TEXT = "　"
local COLLAPSED_PAGE = 9
local EXPANDED_PAGE = 45

local RADICALS = {
  a = "日", b = "月", c = "金", d = "木", e = "水", f = "火", g = "土",
  h = "竹", i = "戈", j = "十", k = "大", l = "中", m = "一", n = "弓",
  o = "人", p = "心", q = "手", r = "口", s = "尸", t = "廿",
  u = "山", v = "女", w = "田", x = "難", y = "卜", z = "符",
}

local function to_radicals(code)
  if not code or code == "" then return "" end
  local out = {}
  for i = 1, #code do
    local ch = code:sub(i, i)
    out[#out + 1] = RADICALS[ch] or ch
  end
  return table.concat(out)
end

local function is_prediction_seg(ctx, seg)
  if not seg then return false end
  local ok, tagged = pcall(function() return seg:has_tag("prediction") end)
  if ok and tagged then return true end
  ok, tagged = pcall(function()
    return seg.tags and (seg.tags["prediction"] or seg.tags.prediction)
  end)
  if ok and tagged then return true end
  if ctx:has_menu() and ctx:is_composing() and (not ctx.input or ctx.input == "") then
    return true
  end
  return false
end

local function with_preedit(cand, preedit)
  if preedit and preedit ~= "" then
    cand.preedit = preedit
  end
  return cand
end

local function page_size_for(ctx)
  if ctx:get_option("expanded_menu") then
    return EXPANDED_PAGE
  end
  return COLLAPSED_PAGE
end

local function expand_hint_for(ctx, total)
  -- 僅在收起且超過一頁時提示「→展開」；展開後由面板頂列顯示「←收起」
  if total <= COLLAPSED_PAGE then
    return nil
  end
  if ctx:get_option("expanded_menu") then
    return nil
  end
  return HINT_EXPAND
end

local function join_hints(...)
  local parts = {}
  for i = 1, select("#", ...) do
    local p = select(i, ...)
    if p and p ~= "" then
      parts[#parts + 1] = p
    end
  end
  return table.concat(parts, "  ")
end

local function filter(input, env)
  local ctx = env.engine.context
  local seg = ctx.composition:back()
  local predicting = is_prediction_seg(ctx, seg)
  local page_size = page_size_for(ctx)
  local code = ctx.input or ""
  local radical_preedit = to_radicals(code)

  -- 不要底部 prompt
  if seg then
    if seg.prompt == HINT_SHIFT or seg.prompt == HINT_EXPAND or seg.prompt == HINT_COLLAPSE or predicting then
      seg.prompt = ""
    end
  end

  local start_pos = seg and (seg.start or 0) or 0
  local end_pos = seg and (seg._end or 0) or 0

  -- 單碼：不列出選字，放一個不可見占位以套用中文 preedit
  if not predicting and #code == 1 and code:match("^[a-z]$") then
    for _ in input:iter() do end
    local keeper = Candidate("keep_preedit", start_pos, end_pos, "", "")
    keeper.preedit = radical_preedit
    yield(keeper)
    return
  end

  local cands = {}
  for cand in input:iter() do
    table.insert(cands, cand)
  end

  local n = #cands
  local expand_hint = expand_hint_for(ctx, n)

  for i, cand in ipairs(cands) do
    with_preedit(cand, radical_preedit)
    if i == 1 then
      local hint
      if predicting then
        hint = join_hints(HINT_SHIFT, expand_hint)
      else
        hint = expand_hint
      end
      if hint and hint ~= "" then
        local comment = cand.comment
        if not comment or comment == "" or not comment:find("Shift", 1, true) then
          yield(ShadowCandidate(cand, cand.type, cand.text, hint))
        elseif expand_hint and not comment:find("展開", 1, true) and not comment:find("收起", 1, true) then
          yield(ShadowCandidate(cand, cand.type, cand.text, join_hints(comment, expand_hint)))
        else
          yield(cand)
        end
      else
        yield(cand)
      end
    else
      yield(cand)
    end
  end

  if n > 0 then
    local rem = n % page_size
    local pad = (rem == 0) and 0 or (page_size - rem)
    -- 展開時不硬填滿整頁空白，避免畫面被占位字淹沒
    if ctx:get_option("expanded_menu") then
      pad = 0
    end
    if pad > 0 then
      for _ = 1, pad do
        local pad_cand = Candidate("pad", start_pos, end_pos, PAD_TEXT, "")
        pad_cand.preedit = radical_preedit
        yield(pad_cand)
      end
    end
  end
end

return filter
