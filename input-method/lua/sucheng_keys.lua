-- 蘋果速成 / Apple SuCheng · Author: Kanaoda
-- 接近 Windows 速成的關聯字／中英切換行為：
--   輕按 Shift     → 切中／英（先結束目前組字，避免英文延續進中文）
--   按住 Shift+字母 → 中文模式下輸出小寫英文（不上屏到組字緩衝）
--   按住 Shift+1-9 → 選關聯字
--   Space          → 循環翻關聯字頁
--   Esc／Backspace → 關閉關聯字（吞鍵，不傳給前景 App）
--   選字／關聯時 →展開、←收起（對齊 Windows 表格展開）
--   純數字 1-9     → 輸入數字（不選字）
--
-- 注意：不再使用 ascii_composer 的 inline_ascii（會把英文黏在同一組字裡）。
local kRejected, kAccepted, kNoop = 0, 1, 2

local COLLAPSED_PAGE = 9
local EXPANDED_PAGE = 45

local RADICALS = {
  a = "日", b = "月", c = "金", d = "木", e = "水", f = "火", g = "土",
  h = "竹", i = "戈", j = "十", k = "大", l = "中", m = "一", n = "弓",
  o = "人", p = "心", q = "手", r = "口", s = "尸", t = "廿",
  u = "山", v = "女", w = "田", x = "難", y = "卜", z = "符",
}

local DEBUG = false
local DEBUG_LOG = (os.getenv("HOME") or "") .. "/Library/AppleSuCheng/key_debug.log"

local function dbg(msg)
  if not DEBUG then return end
  local f = io.open(DEBUG_LOG, "a")
  if not f then return end
  f:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
  f:close()
end

local RAW = {
  space = " ",
  comma = ",",
  period = ".",
  slash = "/",
  semicolon = ";",
  apostrophe = "'",
  backslash = "\\",
  bracketleft = "[",
  bracketright = "]",
  minus = "-",
  equal = "=",
  grave = "`",
  ["Shift+slash"] = "?",
  question = "?",
  ["Shift+apostrophe"] = "\"",
  ["Shift+comma"] = "<",
  ["Shift+period"] = ">",
  ["Shift+semicolon"] = ":",
  ["Shift+backslash"] = "|",
  ["Shift+minus"] = "_",
  ["Shift+equal"] = "+",
  ["Shift+0"] = ")",
  ["Shift+grave"] = "~",
  ["Shift+bracketleft"] = "{",
  ["Shift+bracketright"] = "}",
  parenright = ")",
}

local SHIFT_SELECT = {
  ["Shift+1"] = 0, ["Shift+exclam"] = 0, exclam = 0, ["!"] = 0,
  ["Shift+2"] = 1, ["Shift+at"] = 1, at = 1, ["@"] = 1,
  ["Shift+3"] = 2, ["Shift+numbersign"] = 2, numbersign = 2, ["#"] = 2,
  ["Shift+4"] = 3, ["Shift+dollar"] = 3, dollar = 3, ["$"] = 3,
  ["Shift+5"] = 4, ["Shift+percent"] = 4, percent = 4, ["%"] = 4,
  ["Shift+6"] = 5, ["Shift+asciicircum"] = 5, asciicircum = 5, ["^"] = 5,
  ["Shift+7"] = 6, ["Shift+ampersand"] = 6, ampersand = 6, ["&"] = 6,
  ["Shift+8"] = 7, ["Shift+asterisk"] = 7, asterisk = 7, ["*"] = 7,
  ["Shift+9"] = 8, ["Shift+parenleft"] = 8, parenleft = 8, ["("] = 8,
}

local function is_shift_only(repr)
  return repr == "Shift_L" or repr == "Shift_R"
      or repr == "Shift+Shift_L" or repr == "Shift+Shift_R"
      or repr:match("^Shift%+Shift_")
end

local function is_modifier_only(repr)
  return is_shift_only(repr)
      or repr == "Control_L" or repr == "Control_R"
      or repr == "Control+Control_L" or repr == "Control+Control_R"
      or repr == "Alt_L" or repr == "Alt_R"
      or repr == "Option_L" or repr == "Option_R"
      or repr == "Super_L" or repr == "Super_R"
      or repr == "Meta_L" or repr == "Meta_R"
      or repr == "Caps_Lock"
      or repr:match("^Control%+Control_")
end

local function is_prediction(ctx)
  if not ctx:has_menu() then return false end
  local seg = ctx.composition:back()
  if seg then
    local ok, tagged = pcall(function() return seg:has_tag("prediction") end)
    if ok and tagged then return true end
    ok, tagged = pcall(function()
      return seg.tags and (seg.tags["prediction"] or seg.tags.prediction)
    end)
    if ok and tagged then return true end
  end
  return (not ctx.input or ctx.input == "") and ctx:is_composing()
end

local function is_expanded(ctx)
  return ctx:get_option("expanded_menu") == true
end

-- 注意：librime 的 schema.page_size 啟動後不可改；展開由前端 candidate_list API 一次取齊。
-- 這裡只維護 expanded_menu option，供 hint／前端讀取。

local function dismiss_prediction(ctx, env)
  ctx:set_option("expanded_menu", false)
  ctx:set_option("prediction", false)
  ctx:clear()
end

local function restore_prediction(ctx)
  ctx:set_option("prediction", true)
end

local function page_size_of(env, ctx)
  ctx = ctx or env.engine.context
  if is_expanded(ctx) then
    return EXPANDED_PAGE
  end
  local n = env.engine.schema.page_size
  if type(n) == "number" and n > 0 then
    return n
  end
  return COLLAPSED_PAGE
end

local function jump_to_index(ctx, seg, index)
  if ctx.highlight then
    ctx:highlight(index)
  else
    seg.selected_index = index
    ctx:refresh_non_confirmed_composition()
  end
end

local function set_menu_expanded(env, ctx, expanded)
  local want = expanded and true or false
  if is_expanded(ctx) == want then
    return kAccepted
  end
  ctx:set_option("expanded_menu", want)
  local seg = ctx.composition:back()
  if seg then
    -- 展開從清單開頭看；收起尽量留在同一候選附近
    local idx = want and 0 or seg.selected_index
    jump_to_index(ctx, seg, idx)
  else
    ctx:refresh_non_confirmed_composition()
  end
  dbg("expanded_menu=" .. tostring(want))
  return kAccepted
end

local function collapse_menu_if_needed(env, ctx)
  if is_expanded(ctx) then
    ctx:set_option("expanded_menu", false)
  end
end

local function handle_expand_keys(key, env, ctx, repr)
  if key:release() or key:shift() or key:ctrl() or key:alt() or key:super() then
    return nil
  end
  if not ctx:has_menu() then
    return nil
  end
  if repr == "Right" or repr == "KP_Right" then
    return set_menu_expanded(env, ctx, true)
  end
  if repr == "Left" or repr == "KP_Left" then
    return set_menu_expanded(env, ctx, false)
  end
  return nil
end

local function commit_raw(env, key, repr)
  local text = RAW[repr]
  if not text and key.chr then
    local ok, c = pcall(function() return key:chr() end)
    if ok then
      if type(c) == "number" and c >= 32 and c < 127 then
        text = string.char(c)
      elseif type(c) == "string" and #c > 0 then
        text = c
      end
    end
  end
  if not text and SHIFT_SELECT[repr] ~= nil then
    return false
  end
  if text then
    env.engine:commit_text(text)
    return true
  end
  return false
end

local function cycle_pages(ctx, env)
  local seg = ctx.composition:back()
  if not seg or not seg.menu then return kNoop end

  local page_size = page_size_of(env, ctx)
  local next_start = (math.floor(seg.selected_index / page_size) + 1) * page_size

  if seg.menu:prepare(next_start + 1) > next_start then
    jump_to_index(ctx, seg, next_start)
  else
    jump_to_index(ctx, seg, 0)
  end
  return kAccepted
end

local function shift_select_index(key, repr)
  if key:ctrl() or key:alt() or key:super() then
    return nil
  end
  if repr:match("^Shift%+") and SHIFT_SELECT[repr] ~= nil then
    return SHIFT_SELECT[repr]
  end
  if key:shift() then
    local d = repr:match("^([1-9])$")
    if d then return tonumber(d) - 1 end
  end
  if SHIFT_SELECT[repr] ~= nil and not repr:match("^[0-9]$") then
    return SHIFT_SELECT[repr]
  end
  return nil
end

local function select_via_selector(env, page_index)
  local digit = tostring(page_index + 1)
  env._pred_select = true
  dbg("select_via_selector send=" .. digit)
  env.engine:process_key(KeyEvent(digit))
  env._pred_select = false
  return kAccepted
end

local function is_pad_cand(cand)
  if not cand then return true end
  if cand.type == "pad" or cand.type == "keep_preedit" then return true end
  local t = cand.text
  return t == nil or t == "" or t == "　" or t == " "
end

local function candidate_at_page_index(ctx, env, page_index)
  local seg = ctx.composition:back()
  if not seg then return nil end
  local page_size = page_size_of(env, ctx)
  local page_start = math.floor(seg.selected_index / page_size) * page_size
  return seg:get_candidate_at(page_start + page_index)
end

local function select_via_commit(ctx, env, page_index)
  local cand = candidate_at_page_index(ctx, env, page_index)
  if is_pad_cand(cand) then
    dbg("select_via_commit skip pad")
    return false
  end
  local text = cand.text
  dbg("select_via_commit text=" .. text)
  dismiss_prediction(ctx, env)
  env.engine:commit_text(text)
  restore_prediction(ctx)
  return true
end

local function shift_letter(key, repr)
  if not key:shift() or key:ctrl() or key:alt() or key:super() then
    return nil
  end
  if is_modifier_only(repr) then
    return nil
  end
  local ch = repr:match("^Shift%+([A-Za-z])$")
  if not ch and repr:match("^[A-Za-z]$") then
    ch = repr
  end
  if not ch then
    return nil
  end
  return ch:lower()
end

-- 結束目前組字，避免中英切換後英文／字碼黏在同一段 preedit
local function flush_composition(ctx, env)
  if not ctx:is_composing() then return end

  if is_prediction(ctx) then
    dismiss_prediction(ctx, env)
    restore_prediction(ctx)
    return
  end

  if ctx:has_menu() then
    local ok = pcall(function() ctx:confirm_current_selection() end)
    if ok and not ctx:is_composing() then return end
  end

  local raw = ctx.input or ""
  ctx:clear()
  -- 未完成的英文／混雜 preedit：直接上屏，勿留在組字緩衝
  if raw ~= "" and raw:match("[A-Za-z]") then
    env.engine:commit_text(raw)
  end
end

local function toggle_ascii_mode(ctx, env)
  local to_ascii = not ctx:get_option("ascii_mode")
  dbg("toggle_ascii_mode -> " .. tostring(to_ascii))
  flush_composition(ctx, env)
  ctx:set_option("ascii_mode", to_ascii)
end

local function mark_shift_used(env)
  if env._shift_chord then
    env._shift_chord.used = true
  end
end

local function commit_lowercase_latin(ctx, env, letter)
  mark_shift_used(env)
  if is_prediction(ctx) then
    dismiss_prediction(ctx, env)
    env.engine:commit_text(letter)
    restore_prediction(ctx)
    return
  end
  if ctx:is_composing() then
    -- 組字中插入臨時英文：先清掉，避免跟字碼黏在一起
    flush_composition(ctx, env)
  end
  env.engine:commit_text(letter)
end

-- macOS 常丟修飾鍵 keyUp，故採：
--   Shift 按下 → 立刻切中／英
--   若接著按住 Shift+字母／數字 → 撤銷剛才切換，改走臨時英文／選關聯
local function handle_shift_chord(key, env, repr)
  local ctx = env.engine.context

  if is_shift_only(repr) and not key:release() then
    -- 關聯字：Shift 只表示準備選字，不切英文
    if is_prediction(ctx) then
      env._shift_chord = { used = false, toggled = false }
      dbg("shift down during prediction (no toggle)")
      return kAccepted
    end
    local before = ctx:get_option("ascii_mode")
    toggle_ascii_mode(ctx, env)
    env._shift_chord = {
      used = false,
      toggled = true,
      before = before,
    }
    dbg("shift down toggled ascii_mode=" .. tostring(ctx:get_option("ascii_mode")))
    return kAccepted
  end

  if is_shift_only(repr) and key:release() then
    env._shift_chord = nil
    dbg("shift up")
    return kAccepted
  end

  return nil
end

-- 按住 Shift 組合鍵：若剛因 Shift 按下而切換，先撤銷
local function undo_shift_toggle_if_chord(ctx, env)
  local chord = env._shift_chord
  if not chord or not chord.toggled or chord.used then
    return
  end
  chord.used = true
  chord.toggled = false
  flush_composition(ctx, env)
  ctx:set_option("ascii_mode", chord.before and true or false)
  dbg("undo shift toggle -> ascii_mode=" .. tostring(ctx:get_option("ascii_mode")))
end

local function processor(key, env)
  local ctx = env.engine.context
  local repr = key:repr()

  if not ctx:has_menu() then
    collapse_menu_if_needed(env, ctx)
  end

  -- 先處理 Shift 起／止（含 release）
  local shift_result = handle_shift_chord(key, env, repr)
  if shift_result ~= nil then
    return shift_result
  end

  -- 其他修飾鍵在關聯字時吞掉
  if is_prediction(ctx) and is_modifier_only(repr) and not key:release() then
    dbg("modifier swallow repr=" .. repr)
    return kAccepted
  end

  if key:release() then return kNoop end

  -- 選字／關聯：→展開、←收起（展開後方向鍵／數字改由前端表格導航）
  local expand_result = handle_expand_keys(key, env, ctx, repr)
  if expand_result ~= nil then
    return expand_result
  end

  -- 中文模式：按住 Shift 打字 → 撤銷誤切換，輸出小寫英文
  local letter = shift_letter(key, repr)
  if letter then
    undo_shift_toggle_if_chord(ctx, env)
    if not ctx:get_option("ascii_mode") then
      dbg("shift_latin lower=" .. letter)
      commit_lowercase_latin(ctx, env, letter)
      return kAccepted
    end
    -- 若撤銷後仍是英文模式（理論上 before 為 true），放行給英文輸入
  end

  -- 有按著 Shift 的其他鍵：標記 chord 已使用（選關聯／符號等）
  if key:shift() then
    undo_shift_toggle_if_chord(ctx, env)
    mark_shift_used(env)
  end

  -- 空白占位格不可選
  if ctx:has_menu() and not key:ctrl() and not key:alt() and not key:super() then
    local d = repr:match("^([1-9])$")
    if d and not key:shift() then
      if is_pad_cand(candidate_at_page_index(ctx, env, tonumber(d) - 1)) then
        dbg("swallow pad digit=" .. d)
        return kAccepted
      end
    end
  end

  if is_prediction(ctx) then
    dbg(string.format(
      "pred key=%s shift=%s",
      repr, tostring(key:shift())
    ))

    -- 關閉關聯字並吞掉按鍵，避免 Esc／Backspace 漏給文字編輯器／其他 App
    if repr == "BackSpace" or repr == "Escape" then
      dbg("dismiss prediction via " .. repr)
      dismiss_prediction(ctx, env)
      restore_prediction(ctx)
      return kAccepted
    end

    if env._pred_select and repr:match("^[1-9]$") then
      return kNoop
    end

    local shift_idx = shift_select_index(key, repr)
    if shift_idx ~= nil then
      mark_shift_used(env)
      if is_pad_cand(candidate_at_page_index(ctx, env, shift_idx)) then
        return kAccepted
      end
      select_via_selector(env, shift_idx)
      if is_prediction(ctx) then
        select_via_commit(ctx, env, shift_idx)
      end
      return kAccepted
    end

    if repr:match("^[0-9]$") and not key:shift() and not key:ctrl() and not key:alt() then
      dismiss_prediction(ctx, env)
      env.engine:commit_text(repr)
      restore_prediction(ctx)
      return kAccepted
    end

    if repr == "space" and not key:shift() and not key:ctrl() and not key:alt() and not key:super() then
      return cycle_pages(ctx, env)
    end

    dbg("dismiss other key=" .. repr)
    dismiss_prediction(ctx, env)
    local committed = commit_raw(env, key, repr)
    restore_prediction(ctx)
    if committed then
      return kAccepted
    end
    return kNoop
  end

  -- ===== 一般速成（有編碼）=====
  if key:shift() or key:ctrl() or key:alt() or key:super() then
    return kNoop
  end
  if repr ~= "space" then return kNoop end

  local input = ctx.input or ""
  if #input == 1 and RADICALS[input] then
    local ch = RADICALS[input]
    ctx:clear()
    env.engine:commit_text(ch)
    return kAccepted
  end

  if not ctx:has_menu() then return kNoop end

  local seg = ctx.composition:back()
  if not seg or not seg.menu then return kNoop end

  if seg.menu:prepare(2) == 1 then
    local cand = seg:get_candidate_at(0)
    if cand and not is_pad_cand(cand) then
      ctx:select(0)
      return kAccepted
    end
  end

  return cycle_pages(ctx, env)
end

return processor
