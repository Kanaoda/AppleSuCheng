//
//  AppleSuChengInputController.swift
//  Apple SuCheng
//
//  Created by Leo Liu on 5/7/24.
//

import Carbon
import InputMethodKit

final class AppleSuChengInputController: IMKInputController {
  private static let keyRollOver = 50
  private static var unknownAppCnt: UInt = 0

  private weak var client: IMKTextInput?
  private let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
  private var preedit: String = ""
  private var selRange: NSRange = .empty
  private var caretPos: Int = 0
  private var lastModifiers: NSEvent.ModifierFlags = .init()
  private var session: RimeSessionId = 0
  private var schemaId: String = ""
  private var inlinePreedit = false
  private var inlineCandidate = false
  private var chordKeyCodes: [UInt32] = .init(repeating: 0, count: AppleSuChengInputController.keyRollOver)
  private var chordModifiers: [UInt32] = .init(repeating: 0, count: AppleSuChengInputController.keyRollOver)
  private var chordKeyCount: Int = 0
  private var chordTimer: Timer?
  private var chordDuration: TimeInterval = 0
  private var currentApp: String = ""
  /// 候選／關聯字選單是否開著（以 rimeUpdate 為準，不依賴 NSPanel.isVisible）。
  private var candidateMenuOpen = false
  /// 展開模式下面板顯示的是絕對索引列表（非單頁）。
  private var showingExpandedMenu = false
  /// 目前選單是否為關聯字（無組字輸入）；決定 ←／→ 是否需 Shift。
  private var isAssociationMenu = false
  /// 表格焦點（絕對索引）；數字鍵 1–9 對「焦點所在欄」生效。
  private var expandedFocusIndex = 0
  private var expandedCandidateCount = 0
  private static let expandedCandidateLimit = 45
  private static let tablePageSize = 9

  // swiftlint:disable:next cyclomatic_complexity
  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    guard let event = event else { return false }
    let modifiers = event.modifierFlags
    let changes = lastModifiers.symmetricDifference(modifiers)

    // Return true to consume the key event; return false to pass it to the client app.
    var handled = false

    if session == 0 || !rimeAPI.find_session(session) {
      createSession()
      if session == 0 {
        return false
      }
    }

    self.client ?= sender as? IMKTextInput
    if let app = client?.bundleIdentifier(), currentApp != app {
      currentApp = app
      updateAppOptions()
    }

    switch event.type {
    case .flagsChanged:
      if lastModifiers == modifiers {
        handled = true
        break
      }
      var rimeModifiers: UInt32 = AppleSuChengKeycode.osxModifiersToRime(modifiers: modifiers)
      // Some remote desktop tools send flagsChanged with keyCode 0; infer the real modifier key when needed.
      var keyCode = event.keyCode
      if !AppleSuChengKeycode.modifierKeycodes.contains(keyCode) {
        guard let inferred = AppleSuChengKeycode.inferModifierKeycode(from: changes) else {
          lastModifiers = modifiers
          rimeUpdate()
          handled = true
          break
        }
        keyCode = inferred
      }
      let rimeKeycode: UInt32 = AppleSuChengKeycode.osxKeycodeToRime(keycode: keyCode, keychar: nil, shift: false, caps: false)

      if changes.contains(.capsLock) {
        // Rime expects XK_Caps_Lock before the lock mask changes; NSFlagsChanged has already applied it.
        rimeModifiers ^= kLockMask.rawValue
        _ = processKey(rimeKeycode, modifiers: rimeModifiers)
      }

      // Process releases first because some modifier releases arrive with the next keydown.
      var buffer = [(keycode: UInt32, modifier: UInt32)]()
      for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] where changes.contains(flag) {
        if modifiers.contains(flag) {
          buffer.append((keycode: rimeKeycode, modifier: rimeModifiers))
        } else {
          buffer.insert((keycode: rimeKeycode, modifier: rimeModifiers | kReleaseMask.rawValue), at: 0)
        }
      }
      for (keycode, modifier) in buffer {
        _ = processKey(keycode, modifiers: modifier)
      }

      lastModifiers = modifiers
      rimeUpdate()

    case .keyDown:
      // Let client apps handle Command shortcuts.
      if modifiers.contains(.command) {
        break
      }

      let keyCode = event.keyCode
      var keyChars = event.charactersIgnoringModifiers
      let capitalModifiers = modifiers.isSubset(of: [.shift, .capsLock])
      if let code = keyChars?.first,
         (capitalModifiers && !code.isLetter) || (!capitalModifiers && !code.isASCII) {
        keyChars = event.characters
      }
      // Esc／方向鍵等可能沒有 characters；仍必須用 keyCode 送給 Rime，否則會漏給前景 App。
      let rimeKeycode = AppleSuChengKeycode.osxKeycodeToRime(
        keycode: keyCode,
        keychar: keyChars?.first,
        shift: modifiers.contains(.shift),
        caps: modifiers.contains(.capsLock)
      )
      // 必須在 processKey／rimeUpdate 之前判斷：Rime 關閉關聯後 candidates／panel 已空，事後再查會漏吞。
      let isEscape = keyCode == UInt16(kVK_Escape)
      let swallowEscape = isEscape && shouldSwallowEscape()
      if isEscape {
        traceEscape(
          "down menu=\(candidateMenuOpen) panel=\(NSApp.appleSuChengAppDelegate.panel?.isVisible == true) " +
          "swallow=\(swallowEscape) rimeKey=\(rimeKeycode) app=\(currentApp)"
        )
      }

      // 展開表格：方向鍵走格、1–9 選焦點欄（對齊 Windows），勿先丟給 Rime。
      if !isEscape,
         session != 0,
         rimeAPI.get_option(session, "expanded_menu"),
         handleExpandedTableKey(keyCode: keyCode, keyChars: keyChars, modifiers: modifiers) {
        handled = true
        break
      }

      if rimeKeycode != 0 && rimeKeycode != UInt32(XK_VoidSymbol) {
        let rimeModifiers = AppleSuChengKeycode.osxModifiersToRime(modifiers: modifiers)
        handled = processKey(rimeKeycode, modifiers: rimeModifiers)
        rimeUpdate()
      } else if swallowEscape {
        _ = processKey(UInt32(XK_Escape), modifiers: 0)
        rimeUpdate()
        handled = true
      }

      // 關聯字／選字面板顯示中按 Esc：一律吞掉，避免觸發編輯器或其他 App 的 Esc。
      if swallowEscape {
        hidePalettes()
        candidateMenuOpen = false
        // 清掉標記文字，避免部分 App 在「無組字」狀態下又自行解讀 Esc。
        if let client = client {
          client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: .empty)
        }
        preedit = ""
        handled = true
      }
      if isEscape {
        traceEscape("result handled=\(handled) menuNow=\(candidateMenuOpen)")
      }

    default:
      break
    }

    return handled
  }

  /// 選字／關聯面板開著，或 Rime 仍在組字時，Esc 應由輸入法吃掉。
  private func shouldSwallowEscape() -> Bool {
    if candidateMenuOpen {
      return true
    }
    if let panel = NSApp.appleSuChengAppDelegate.panel, panel.isVisible || panel.hasCandidateList {
      return true
    }
    if !preedit.isEmpty {
      return true
    }
    var ctx = RimeContext_stdbool.rimeStructInit()
    defer { _ = rimeAPI.free_context(&ctx) }
    guard session != 0, rimeAPI.get_context(session, &ctx) else { return false }
    if ctx.menu.num_candidates > 0 {
      return true
    }
    if let raw = ctx.composition.preedit, raw.pointee != 0 {
      return true
    }
    return false
  }

  private func traceEscape(_ message: String) {
    let path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/AppleSuCheng/esc_trace.log")
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    if let data = line.data(using: .utf8) {
      if FileManager.default.fileExists(atPath: path),
         let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
      } else {
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
      }
    }
  }

  func selectCandidate(_ index: Int) -> Bool {
    let success: Bool
    if showingExpandedMenu || rimeAPI.get_option(session, "expanded_menu") {
      expandedFocusIndex = index
      success = rimeAPI.select_candidate(session, index)
    } else {
      success = rimeAPI.select_candidate_on_current_page(session, index)
    }
    if success {
      rimeUpdate()
    }
    return success
  }

  /// 滑鼠移到表格某一格時，同步焦點欄（讓隨後的 1–9 選對欄）。
  func noteExpandedFocus(_ index: Int) {
    guard showingExpandedMenu, index >= 0, index < expandedCandidateCount else { return }
    expandedFocusIndex = index
    _ = rimeAPI.highlight_candidate(session, index)
  }

  /// librime 無法在執行期改 page_size；展開時用 candidate_list 一次取出多頁候選。
  private func loadExpandedCandidates() -> (texts: [String], comments: [String])? {
    var iterator = RimeCandidateListIterator()
    guard rimeAPI.candidate_list_begin(session, &iterator) else {
      return nil
    }
    defer { rimeAPI.candidate_list_end(&iterator) }

    var texts = [String]()
    var comments = [String]()
    while texts.count < Self.expandedCandidateLimit && rimeAPI.candidate_list_next(&iterator) {
      let text = iterator.candidate.text.map { String(cString: $0) } ?? ""
      if text.isEmpty || text == "　" {
        continue
      }
      texts.append(text)
      comments.append(iterator.candidate.comment.map { String(cString: $0) } ?? "")
    }
    return texts.isEmpty ? nil : (texts, comments)
  }

  /// 展開表格導航。普通選字：←／→ 走欄，最左 ← 收起。關聯字：←／→ 走欄，Shift+←／→ 收起。
  private func handleExpandedTableKey(keyCode: UInt16, keyChars: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
    let pageSize = Self.tablePageSize
    let count = max(expandedCandidateCount, 1)
    if expandedFocusIndex >= count {
      expandedFocusIndex = count - 1
    }
    let col = expandedFocusIndex / pageSize
    let row = expandedFocusIndex % pageSize
    let columns = max(1, (expandedCandidateCount + pageSize - 1) / pageSize)
    let mods = modifiers.intersection([.shift, .control, .option, .command])

    if mods.isEmpty || mods == [.shift] {
      if let digit = Self.digitIndex(fromKeyCode: keyCode, keyChars: keyChars) {
        let absolute = col * pageSize + digit
        guard absolute < expandedCandidateCount else { return true }
        return selectCandidate(absolute)
      }
    }

    // 關聯字：Shift+←／→ 收起（展開由 Lua 在收起態處理 Shift+→）
    if isAssociationMenu, mods == [.shift] {
      switch Int(keyCode) {
      case kVK_LeftArrow, kVK_RightArrow:
        rimeAPI.set_option(session, "expanded_menu", false)
        _ = rimeAPI.highlight_candidate(session, min(row, pageSize - 1))
        rimeUpdate()
        return true
      default:
        return false
      }
    }

    guard mods.isEmpty else { return false }

    switch Int(keyCode) {
    case kVK_LeftArrow:
      if col == 0 {
        // 普通選字：最左欄 ← 收起；關聯字：停在最左欄（收起改用 Shift+←）
        if !isAssociationMenu {
          rimeAPI.set_option(session, "expanded_menu", false)
          _ = rimeAPI.highlight_candidate(session, min(row, pageSize - 1))
          rimeUpdate()
        }
        return true
      }
      moveExpandedFocus(to: (col - 1) * pageSize + row)
      return true
    case kVK_RightArrow:
      if col + 1 < columns {
        moveExpandedFocus(to: min((col + 1) * pageSize + row, expandedCandidateCount - 1))
      }
      return true
    case kVK_UpArrow:
      if row > 0 { moveExpandedFocus(to: expandedFocusIndex - 1) }
      return true
    case kVK_DownArrow:
      if row + 1 < pageSize && expandedFocusIndex + 1 < expandedCandidateCount {
        moveExpandedFocus(to: expandedFocusIndex + 1)
      }
      return true
    case kVK_Return, kVK_ANSI_KeypadEnter:
      return selectCandidate(expandedFocusIndex)
    case kVK_Space:
      let nextCol = (col + 1) % columns
      moveExpandedFocus(to: min(nextCol * pageSize + row, expandedCandidateCount - 1))
      return true
    default:
      return false
    }
  }

  private func moveExpandedFocus(to index: Int) {
    guard expandedCandidateCount > 0 else { return }
    expandedFocusIndex = max(0, min(index, expandedCandidateCount - 1))
    _ = rimeAPI.highlight_candidate(session, expandedFocusIndex)
    rimeUpdate()
  }

  private static func digitIndex(fromKeyCode keyCode: UInt16, keyChars: String?) -> Int? {
    if let ch = keyChars?.first, ch >= "1", ch <= "9" {
      return Int(ch.asciiValue! - Character("1").asciiValue!)
    }
    switch Int(keyCode) {
    case kVK_ANSI_1, kVK_ANSI_Keypad1: return 0
    case kVK_ANSI_2, kVK_ANSI_Keypad2: return 1
    case kVK_ANSI_3, kVK_ANSI_Keypad3: return 2
    case kVK_ANSI_4, kVK_ANSI_Keypad4: return 3
    case kVK_ANSI_5, kVK_ANSI_Keypad5: return 4
    case kVK_ANSI_6, kVK_ANSI_Keypad6: return 5
    case kVK_ANSI_7, kVK_ANSI_Keypad7: return 6
    case kVK_ANSI_8, kVK_ANSI_Keypad8: return 7
    case kVK_ANSI_9, kVK_ANSI_Keypad9: return 8
    default: return nil
    }
  }

  // swiftlint:disable:next identifier_name
  func page(up: Bool) -> Bool {
    var handled = false
    handled = rimeAPI.change_page(session, up)
    if handled {
      rimeUpdate()
    }
    return handled
  }

  func moveCaret(forward: Bool) -> Bool {
    let currentCaretPos = rimeAPI.get_caret_pos(session)
    guard let input = rimeAPI.get_input(session) else { return false }
    if forward {
      if currentCaretPos <= 0 {
        return false
      }
      rimeAPI.set_caret_pos(session, currentCaretPos - 1)
    } else {
      let inputStr = String(cString: input)
      if currentCaretPos >= inputStr.utf8.count {
        return false
      }
      rimeAPI.set_caret_pos(session, currentCaretPos + 1)
    }
    rimeUpdate()
    return true
  }

  override func recognizedEvents(_ sender: Any!) -> Int {
    return Int(NSEvent.EventTypeMask.Element(arrayLiteral: .keyDown, .flagsChanged).rawValue)
  }

  override func activateServer(_ sender: Any!) {
    self.client ?= sender as? IMKTextInput
    var keyboardLayout = NSApp.appleSuChengAppDelegate.config?.getString("keyboard_layout") ?? ""
    if keyboardLayout == "last" || keyboardLayout == "" {
      keyboardLayout = ""
    } else if keyboardLayout == "default" {
      keyboardLayout = "com.apple.keylayout.ABC"
    } else if !keyboardLayout.hasPrefix("com.apple.keylayout.") {
      keyboardLayout = "com.apple.keylayout.\(keyboardLayout)"
    }
    if keyboardLayout != "" {
      client?.overrideKeyboard(withKeyboardNamed: keyboardLayout)
    }
    // Activation delivers no flagsChanged event, and NSEvent.modifierFlags
    // only reflects this process's own event stream, so lastModifiers may
    // disagree with the actual Caps Lock state by now. Seed it from the
    // session-wide hardware state; otherwise the next Caps Lock press can
    // compare equal to the stale lastModifiers and be dropped by the
    // early-return in handle().
    if CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift) {
      lastModifiers.insert(.capsLock)
    } else {
      lastModifiers.remove(.capsLock)
    }
    preedit = ""
    if session != 0 {
      let state = rimeAPI.get_option(session, "ascii_mode")
      let label = rimeAPI.get_state_label_abbreviated(session, "ascii_mode", state, true).asString
      NSApp.appleSuChengAppDelegate.updateStatusIcon(asciiMode: state, schemaLabel: label)
    }
  }

  override init!(server: IMKServer!, delegate: Any!, client: Any!) {
    self.client = client as? IMKTextInput
    super.init(server: server, delegate: delegate, client: client)
    createSession()

    NotificationCenter.default.addObserver(
      forName: .init("AppleSuChengSetASCIIModeNotification"),
      object: nil,
      queue: nil
    ) { [weak self] notification in
      self?.handleASCIIModeToggle(notification)
    }

    NotificationCenter.default.addObserver(
      forName: .init("AppleSuChengReportASCIIModeNotification"),
      object: nil,
      queue: nil
    ) { [weak self] notification in
      self?.reportASCIIMode(notification)
    }
  }

  override func deactivateServer(_ sender: Any!) {
    hidePalettes()
    commitComposition(sender)
    client = nil
  }

  override func hidePalettes() {
    candidateMenuOpen = false
    showingExpandedMenu = false
    expandedCandidateCount = 0
    expandedFocusIndex = 0
    isAssociationMenu = false
    NSApp.appleSuChengAppDelegate.panel?.hide()
    super.hidePalettes()
  }

  override func commitComposition(_ sender: Any!) {
    self.client ?= sender as? IMKTextInput
    if session != 0 {
      if let input = rimeAPI.get_input(session) {
        commit(string: String(cString: input))
        rimeAPI.clear_composition(session)
      }
    }
  }

  override func menu() -> NSMenu! {
    let deploy = NSMenuItem(title: NSLocalizedString("Deploy", comment: "Menu item"), action: #selector(deploy), keyEquivalent: "`")
    deploy.target = self
    deploy.keyEquivalentModifierMask = [.control, .option]
    let sync = NSMenuItem(title: NSLocalizedString("Sync user data", comment: "Menu item"), action: #selector(syncUserData), keyEquivalent: "")
    sync.target = self
    let logDir = NSMenuItem(title: NSLocalizedString("Logs...", comment: "Menu item"), action: #selector(openLogFolder), keyEquivalent: "")
    logDir.target = self
    let setting = NSMenuItem(title: NSLocalizedString("Settings...", comment: "Menu item"), action: #selector(openRimeFolder), keyEquivalent: "")
    setting.target = self
    let wiki = NSMenuItem(title: NSLocalizedString("Help...", comment: "Menu item"), action: #selector(openWiki), keyEquivalent: "")
    wiki.target = self
    let update = NSMenuItem(title: NSLocalizedString("Check for updates...", comment: "Menu item"), action: #selector(checkForUpdates), keyEquivalent: "")
    update.target = self

    let menu = NSMenu()
    menu.addItem(deploy)
    menu.addItem(sync)
    menu.addItem(logDir)
    menu.addItem(setting)
    menu.addItem(wiki)
    menu.addItem(update)

    return menu
  }

  @objc func deploy() {
    NSApp.appleSuChengAppDelegate.deploy()
  }

  @objc func syncUserData() {
    NSApp.appleSuChengAppDelegate.syncUserData()
  }

  @objc func openLogFolder() {
    NSApp.appleSuChengAppDelegate.openLogFolder()
  }

  @objc func openRimeFolder() {
    NSApp.appleSuChengAppDelegate.openRimeFolder()
  }

  @objc func checkForUpdates() {
    NSApp.appleSuChengAppDelegate.checkForUpdates()
  }

  @objc func openWiki() {
    NSApp.appleSuChengAppDelegate.openWiki()
  }

  private(set) var specialCommentIndices: [ReservedPropertyKey: Set<Int>] = [:]

  func handleReservedProperty(key rawKey: String, value rawValue: String, for sessionId: RimeSessionId) throws(ReservedPropertyError) {
    guard session == sessionId, session != 0, rimeAPI.find_session(session) else { return }
    guard let key = ReservedPropertyKey(rawValue: rawKey) else { throw .unknownInput(rawKey) }
    let parsed = try ReservedPropertyValue.parse(rawValue)
    switch key {
    case .commentHighlight:
      specialCommentIndices[.commentHighlight] = try parsed.indices()
    case .commentWarning:
      specialCommentIndices[.commentWarning] = try parsed.indices()
    case .refreshUI:
      rimeUpdate(clearReservedComments: false)
    }
  }

  deinit {
    destroySession()
  }
}

private extension AppleSuChengInputController {

  func onChordTimer(_: Timer) {
    var processedKeys = false
    if chordKeyCount > 0 && session != 0 {
      // Chord typing releases are synthesized after the configured timeout.
      for i in 0..<chordKeyCount {
        let handled = rimeAPI.process_key(session, Int32(chordKeyCodes[i]), Int32(chordModifiers[i] | kReleaseMask.rawValue))
        if handled {
          processedKeys = true
        }
      }
    }
    clearChord()
    if processedKeys {
      rimeUpdate()
    }
  }

  func updateChord(keycode: UInt32, modifiers: UInt32) {
    for i in 0..<chordKeyCount where chordKeyCodes[i] == keycode {
      return
    }
    if chordKeyCount >= Self.keyRollOver {
      return
    }
    chordKeyCodes[chordKeyCount] = keycode
    chordModifiers[chordKeyCount] = modifiers
    chordKeyCount += 1
    if let timer = chordTimer, timer.isValid {
      timer.invalidate()
    }
    chordDuration = 0.1
    if let duration = NSApp.appleSuChengAppDelegate.config?.getDouble("chord_duration"), duration > 0 {
      chordDuration = duration
    }
    chordTimer = Timer.scheduledTimer(withTimeInterval: chordDuration, repeats: false, block: onChordTimer)
  }

  func clearChord() {
    chordKeyCount = 0
    if let timer = chordTimer {
      if timer.isValid {
        timer.invalidate()
      }
      chordTimer = nil
    }
  }

  func createSession() {
    let app = client?.bundleIdentifier() ?? {
      AppleSuChengInputController.unknownAppCnt &+= 1
      return "UnknownApp\(AppleSuChengInputController.unknownAppCnt)"
    }()
    print("createSession: \(app)")
    currentApp = app
    session = rimeAPI.create_session()
    schemaId = ""

    if session != 0 {
      updateAppOptions()
    }
  }

  func updateAppOptions() {
    if currentApp == "" {
      return
    }
    if let appOptions = NSApp.appleSuChengAppDelegate.config?.getAppOptions(currentApp) {
      for (key, value) in appOptions {
        print("set app option: \(key) = \(value)")
        rimeAPI.set_option(session, key, value)
      }
    }
    if let reportBundleID = NSApp.appleSuChengAppDelegate.config?.getBool("unsafe/report_bundleid"), reportBundleID {
      currentApp.withCString { name in
        rimeAPI.set_property(session, "client_app", name)
      }
    }
  }

  func destroySession() {
    if session != 0 {
      _ = rimeAPI.destroy_session(session)
      session = 0
    }
    clearChord()
  }

  func processKey(_ rimeKeycode: UInt32, modifiers rimeModifiers: UInt32) -> Bool {
    if let panel = NSApp.appleSuChengAppDelegate.panel {
      if panel.linear != rimeAPI.get_option(session, "_linear") {
        rimeAPI.set_option(session, "_linear", panel.linear)
      }
      if panel.vertical != rimeAPI.get_option(session, "_vertical") {
        rimeAPI.set_option(session, "_vertical", panel.vertical)
      }
    }

    let handled = rimeAPI.process_key(session, Int32(rimeKeycode), Int32(rimeModifiers))

    if !handled {
      let isVimBackInCommandMode = rimeKeycode == XK_Escape || ((rimeModifiers & kControlMask.rawValue != 0) && (rimeKeycode == XK_c || rimeKeycode == XK_C || rimeKeycode == XK_bracketleft))
      if isVimBackInCommandMode && rimeAPI.get_option(session, "vim_mode") &&
          !rimeAPI.get_option(session, "ascii_mode") {
        rimeAPI.set_option(session, "ascii_mode", true)
      }
    } else {
      let isChordingKey = switch Int32(rimeKeycode) {
      case XK_space...XK_asciitilde, XK_Control_L, XK_Control_R, XK_Alt_L, XK_Alt_R, XK_Shift_L, XK_Shift_R:
        true
      default:
        false
      }
      if isChordingKey && rimeAPI.get_option(session, "_chord_typing") {
        updateChord(keycode: rimeKeycode, modifiers: rimeModifiers)
      } else if (rimeModifiers & kReleaseMask.rawValue) == 0 {
        clearChord()
      }
    }

    return handled
  }

  func rimeConsumeCommittedText() {
    var commitText = RimeCommit.rimeStructInit()
    if rimeAPI.get_commit(session, &commitText) {
      if let text = commitText.text {
        commit(string: String(cString: text))
      }
      _ = rimeAPI.free_commit(&commitText)
    }
  }

  // Preserve reserved comment marks when librime requests a UI-only refresh.
  func rimeUpdate(clearReservedComments: Bool = true) {
    if clearReservedComments {
      specialCommentIndices = [:]
    }
    rimeConsumeCommittedText()

    var status = RimeStatus_stdbool.rimeStructInit()
    if rimeAPI.get_status(session, &status) {
      // swiftlint:disable:next identifier_name
      if let schema_id = status.schema_id, schemaId == "" || schemaId != String(cString: schema_id) {
        schemaId = String(cString: schema_id)
        NSApp.appleSuChengAppDelegate.loadSettings(for: schemaId)
        if let panel = NSApp.appleSuChengAppDelegate.panel {
          inlinePreedit = (panel.inlinePreedit && !rimeAPI.get_option(session, "no_inline")) || rimeAPI.get_option(session, "inline")
          inlineCandidate = panel.inlineCandidate && !rimeAPI.get_option(session, "no_inline")
          rimeAPI.set_option(session, "soft_cursor", !inlinePreedit)
        }
      }
      _ = rimeAPI.free_status(&status)
    }

    var ctx = RimeContext_stdbool.rimeStructInit()
    if rimeAPI.get_context(session, &ctx) {
      let preedit = ctx.composition.preedit.map({ String(cString: $0) }) ?? ""

      let start = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_start)), within: preedit) ?? preedit.startIndex
      let end = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_end)), within: preedit) ?? preedit.startIndex
      let caretPos = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.cursor_pos)), within: preedit) ?? preedit.startIndex

      if inlineCandidate {
        var candidatePreview = ctx.commit_text_preview.map { String(cString: $0) } ?? ""
        let endOfCandidatePreview = candidatePreview.endIndex
        if inlinePreedit {
          // 左移光標後的情形：
          // preedit:             ^已選某些字[xiang zuo yi dong]|guangbiao$
          // commit_text_preview: ^已選某些字向左移動$
          // candidate_preview:   ^已選某些字[向左移動]|guangbiao$
          // 繼續翻頁至指定更短字詞的情形：
          // preedit:             ^已選某些字[xiang zuo]yidong|guangbiao$
          // commit_text_preview: ^已選某些字向左yidong$
          // candidate_preview:   ^已選某些字[向左]yidong|guangbiao$
          // 光標移至當前段落最左端的情形：
          // preedit:             ^已選某些字|[xiang zuo yi dong guang biao]$
          // commit_text_preview: ^已選某些字向左移動光標$
          // candidate_preview:   ^已選某些字|[向左移動光標]$
          // 討論：
          // preedit 與 commit_text_preview 中“已選某些字”部分一致
          // 因此，選中範圍即正在翻譯的碼段“向左移動”中，兩者的 start 值一致
          // 光標位置的範圍是 start ..= endOfCandidatePreview
          if caretPos >= end && caretPos < preedit.endIndex {
            // 從 preedit 截取光標後未翻譯的編碼“guangbiao”
            candidatePreview += preedit[caretPos...]
          }
        } else {
          // 翻頁至指定更短字詞的情形：
          // preedit:             ^已選某些字[xiang zuo]yidong|guangbiao$
          // commit_text_preview: ^已選某些字向左yidongguangbiao$
          // candidate_preview:   ^已選某些字[向左???]|$
          // 光標移至當前段落最左端，繼續翻頁至指定更短字詞的情形：
          // preedit:             ^已選某些字|[xiang zuo]yidongguangbiao$
          // commit_text_preview: ^已選某些字向左yidongguangbiao$
          // candidate_preview:   ^已選某些字|[向左]???$
          // FIXME: add librime APIs to support preview candidate without remaining code.
        }
        // preedit can contain additional prompt text before start:
        // ^(prompt)[selection]$
        let start = min(start, candidatePreview.endIndex)
        let caretPos = caretPos <= start ? caretPos : endOfCandidatePreview
        show(preedit: candidatePreview,
             selRange: NSRange(location: start.utf16Offset(in: candidatePreview),
                               length: candidatePreview.utf16.distance(from: start, to: candidatePreview.endIndex)),
             caretPos: caretPos.utf16Offset(in: candidatePreview))
      } else {
        if inlinePreedit {
          show(preedit: preedit, selRange: NSRange(location: start.utf16Offset(in: preedit), length: preedit.utf16.distance(from: start, to: end)), caretPos: caretPos.utf16Offset(in: preedit))
        } else {
          // Use a full-width space placeholder to prevent iTerm2 from echoing raw preedit;
          // half-width placeholders make the Chinese composition baseline unstable.
          show(preedit: preedit.isEmpty ? "" : "　", selRange: NSRange(location: 0, length: 0), caretPos: 0)
        }
      }

      let pageSize = max(Int(ctx.menu.page_size), 1)
      let pageNo = Int(ctx.menu.page_no)
      var highlighted = Int(ctx.menu.highlighted_candidate_index)
      var page = pageNo
      var lastPage = ctx.menu.is_last_page

      var candidates = [String]()
      var comments = [String]()
      let expanded = rimeAPI.get_option(session, "expanded_menu")
      let wasExpanded = showingExpandedMenu
      showingExpandedMenu = false
      // 與 lua is_prediction 對齊：無組字輸入＝關聯字選單
      let inputPtr = rimeAPI.get_input(session)
      let inputStr = inputPtr.map { String(cString: $0) } ?? ""
      isAssociationMenu = inputStr.isEmpty
      if expanded, let all = loadExpandedCandidates() {
        candidates = all.texts
        comments = all.comments
        showingExpandedMenu = true
        expandedCandidateCount = candidates.count
        if !wasExpanded {
          expandedFocusIndex = 0
        } else {
          expandedFocusIndex = min(expandedFocusIndex, max(candidates.count - 1, 0))
        }
        highlighted = expandedFocusIndex
        _ = rimeAPI.highlight_candidate(session, expandedFocusIndex)
        page = 0
        lastPage = true
      } else {
        expandedCandidateCount = 0
        let numCandidates = Int(ctx.menu.num_candidates)
        for i in 0..<numCandidates {
          let candidate = ctx.menu.candidates[i]
          candidates.append(candidate.text.map { String(cString: $0) } ?? "")
          comments.append(candidate.comment.map { String(cString: $0) } ?? "")
        }
      }

      candidateMenuOpen = !candidates.isEmpty
      // 關聯字常無 preedit；塞入零寬標記讓 TSM 維持組字態，Esc 才會先進輸入法。
      if !candidates.isEmpty && preedit.isEmpty && self.preedit.isEmpty {
        show(preedit: "\u{200B}", selRange: NSRange(location: 0, length: 1), caretPos: 0)
      }

      var labels = [String]()
      // swiftlint:disable identifier_name
      if let select_keys = ctx.menu.select_keys {
        labels = String(cString: select_keys).map { String($0) }
      } else if let select_labels = ctx.select_labels {
        for i in 0..<pageSize {
          labels.append(select_labels[i].map { String(cString: $0) } ?? "")
        }
      }
      // swiftlint:enable identifier_name

      let selRange = NSRange(location: start.utf16Offset(in: preedit), length: preedit.utf16.distance(from: start, to: end))
      showPanel(preedit: inlinePreedit ? "" : preedit, selRange: selRange, caretPos: caretPos.utf16Offset(in: preedit),
                candidates: candidates, comments: comments, labels: labels, highlighted: highlighted,
                page: page, lastPage: lastPage, expanded: showingExpandedMenu, association: isAssociationMenu)
      _ = rimeAPI.free_context(&ctx)
    } else {
      candidateMenuOpen = false
      showingExpandedMenu = false
      isAssociationMenu = false
      hidePalettes()
    }
  }

  func commit(string: String) {
    guard let client = client else { return }

    let forceMarkedText =
      session != 0 &&
      rimeAPI.get_option(session, "force_marked_text_for_direct_commit")

    // Direct commits such as full-width punctuation do not necessarily have an
    // active marked-text phase. Some NSTextInputClient implementations require
    // one before accepting insertText.
    if forceMarkedText && preedit.isEmpty && !string.isEmpty {
      let markedText = NSMutableAttributedString(string: string)
      client.setMarkedText(
        markedText,
        selectionRange: NSRange(location: markedText.length, length: 0),
        replacementRange: .empty
      )
    }

    client.insertText(string, replacementRange: .empty)
    preedit = ""
    hidePalettes()
  }

  func show(preedit: String, selRange: NSRange, caretPos: Int) {
    guard let client = client else { return }
    if self.preedit == preedit && self.caretPos == caretPos && self.selRange == selRange {
      return
    }

    self.preedit = preedit
    self.caretPos = caretPos
    self.selRange = selRange

    let start = selRange.location
    let attrString = NSMutableAttributedString(string: preedit)
    if start > 0 {
      let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSRange(location: 0, length: start))! as! [NSAttributedString.Key: Any]
      attrString.setAttributes(attrs, range: NSRange(location: 0, length: start))
    }
    let remainingRange = NSRange(location: start, length: preedit.utf16.count - start)
    let attrs = mark(forStyle: kTSMHiliteSelectedRawText, at: remainingRange)! as! [NSAttributedString.Key: Any]
    attrString.setAttributes(attrs, range: remainingRange)
    client.setMarkedText(attrString, selectionRange: NSRange(location: caretPos, length: 0), replacementRange: .empty)
  }

  // swiftlint:disable:next function_parameter_count
  func showPanel(preedit: String, selRange: NSRange, caretPos: Int, candidates: [String], comments: [String], labels: [String], highlighted: Int, page: Int, lastPage: Bool, expanded: Bool = false, association: Bool = false) {
    guard let client = client else { return }
    var inputPos = NSRect()
    client.attributes(forCharacterIndex: 0, lineHeightRectangle: &inputPos)
    if let panel = NSApp.appleSuChengAppDelegate.panel {
      panel.position = inputPos
      panel.inputController = self
      panel.update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels,
                   highlighted: highlighted, page: page, lastPage: lastPage, expanded: expanded, association: association, update: true)
    }
  }

  private func handleASCIIModeToggle(_ notification: Notification) {
    guard let enableASCII = notification.object as? Bool else { return }
    guard session != 0 && rimeAPI.find_session(session) else { return }

    rimeAPI.set_option(session, "ascii_mode", enableASCII)
    rimeUpdate()
  }

  private func reportASCIIMode(_: Notification) {
    guard client != nil else { return }
    guard session != 0 && rimeAPI.find_session(session) else { return }

    let isASCIIMode = rimeAPI.get_option(session, "ascii_mode")
    let status = isASCIIMode ? "ascii" : "nascii"

    DistributedNotificationCenter.default().postNotificationName(
      .init("AppleSuChengASCIIModeResponse"),
      object: status
    )
  }

}
