-- 蘋果速成 / Apple SuCheng · Author: Kanaoda
-- 1) 關聯字：首選右側顯示「Shift + 數字鍵」（不要底部 prompt）
-- 2) 字表每頁固定 9 格
-- 3) 單碼不顯示選字表，但仍維持中文字碼預編輯（避免 void 段掉回英文 a-z）
local HINT = "Shift + 數字鍵"
local PAD_TEXT = "　"

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

local function filter(input, env)
  local ctx = env.engine.context
  local seg = ctx.composition:back()
  local predicting = is_prediction_seg(ctx, seg)
  local page_size = env.engine.schema.page_size or 9
  local code = ctx.input or ""
  local radical_preedit = to_radicals(code)

  -- 不要底部 prompt
  if seg then
    if seg.prompt == HINT or predicting then
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
  for i, cand in ipairs(cands) do
    with_preedit(cand, radical_preedit)
    if predicting and i == 1 then
      local comment = cand.comment
      if not comment or comment == "" or not comment:find("Shift", 1, true) then
        yield(ShadowCandidate(cand, cand.type, cand.text, HINT))
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
