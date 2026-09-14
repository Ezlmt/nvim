-- Automated test suite for jetski.nvim
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
package.path = plugin_root .. "/lua/?.lua;" .. plugin_root .. "/lua/?/init.lua;" .. package.path
vim.o.swapfile = false

local passed = 0
local failed = 0

local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected '%s', got '%s'", msg or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

local function assert_true(val, msg)
  if not val then
    error(string.format("%s: expected truthy, got %s", msg or "Assertion failed", tostring(val)))
  end
end

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  ✓ " .. name)
  else
    failed = failed + 1
    print("  ✗ " .. name .. ": " .. tostring(err))
  end
end

print("\n==========================================")
print("       jetski.nvim Automated Tests        ")
print("==========================================")

-- Test 1: Config
test("Config: default initialization and deep merge", function()
  local config = require("jetski.config")
  local opts = config.setup({
    open_mode = "horizontal",
    vertical = { width = 0.5 },
  })
  assert_eq("horizontal", opts.open_mode, "open_mode override")
  assert_eq(0.5, opts.vertical.width, "vertical.width override")
  assert_eq("right", opts.vertical.side, "preserved vertical.side default")
  assert_eq("<leader>J", opts.keymap_prefix, "keymap_prefix default")
  assert_true(opts.cmd ~= nil and opts.cmd ~= "", "CLI binary detected")
end)

-- Test 2: Workspace Detection
test("Workspace: CitC Google3 path parsing", function()
  local workspace = require("jetski.workspace")
  local test_path = "/google/src/cloud/nachiketb/jetski_neovim_plugin_integration/google3/devtools/foo/bar.go"
  local ws = workspace.detect_workspace(test_path)
  assert_true(ws.is_google3, "is_google3")
  assert_eq("nachiketb", ws.citc_user, "citc_user")
  assert_eq("jetski_neovim_plugin_integration", ws.citc_client, "citc_client")
  assert_eq("//depot/google3/devtools/foo/bar.go", ws.depot_path, "depot_path")
  assert_eq("devtools/foo/bar.go", ws.relative_path, "relative_path")
  assert_true(ws.vcs ~= nil, "vcs detected")
  assert_true(ws.vcs == "hg" or ws.vcs == "jj" or ws.vcs == "p4", "vcs is valid google3 type: " .. tostring(ws.vcs))

  -- Test p4 workspace detection for Google3 path without .jj or .hg
  local p4_g3_path = "/google/src/files/head/depot/google3/devtools/foo/bar.go"
  local p4_ws = workspace.detect_workspace(p4_g3_path)
  assert_true(p4_ws.is_google3, "p4_ws is_google3")
  assert_eq("p4", p4_ws.vcs, "p4_ws vcs is p4")
  assert_true(p4_ws.is_p4, "p4_ws is_p4 is true")
end)

test("Workspace: active file context info", function()
  local workspace = require("jetski.workspace")
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, "/google/src/cloud/nachiketb/jetski_neovim_plugin_integration/google3/test/demo.cc")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "int main() {", "  return 0;", "}" })
  vim.bo[buf].filetype = "cpp"

  local info = workspace.get_active_file_info()
  assert_true(info.is_named, "is_named")
  assert_eq("demo.cc", info.filename, "filename")
  assert_eq("cpp", info.filetype, "filetype")
  assert_eq(3, info.total_lines, "total_lines")
  assert_eq("//depot/google3/test/demo.cc", info.depot_path, "depot_path")
  assert_true(info.vcs ~= nil, "info.vcs is present")
end)

-- Test 3: Context & Prompt Builders
test("Context: extraction and prompt formatting", function()
  local context = require("jetski.context")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "func Add(a, b int) int {",
    "  return a + b",
    "}",
  })
  vim.bo[buf].filetype = "go"
  vim.api.nvim_win_set_cursor(0, { 2, 2 })

  local explain = context.build_explain_prompt()
  assert_true(explain:find("Please explain the following code snippet") ~= nil, "explain prompt header")
  assert_true(explain:find("return a %+ b") ~= nil, "explain code content")

  local refactor = context.build_refactor_prompt("Use generics")
  assert_true(refactor:find("Use generics") ~= nil, "refactor custom instruction")

  local test_prompt = context.build_test_prompt()
  assert_true(test_prompt:find("Please write comprehensive unit tests") ~= nil, "unit test prompt")
end)

test("Context: diagnostics extraction and fix prompt", function()
  local context = require("jetski.context")
  local buf = vim.api.nvim_get_current_buf()

  -- Set mock diagnostics
  local ns = vim.api.nvim_create_namespace("test_diags")
  vim.diagnostic.set(ns, buf, {
    {
      lnum = 1,
      col = 2,
      severity = vim.diagnostic.severity.ERROR,
      message = "undefined: foo",
      source = "gopls",
    },
  })

  local diags = context.get_diagnostics(buf)
  assert_eq(1, diags.count, "diagnostic count")
  assert_true(diags.formatted:find("undefined: foo") ~= nil, "formatted diagnostic message")

  local fix_prompt = context.build_fix_prompt()
  assert_true(fix_prompt ~= nil, "fix prompt built")
  assert_true(fix_prompt:find("undefined: foo") ~= nil, "fix prompt contains error")
end)

-- Test 4: Comments Manager (Cider-J CommentsManager parity)
test("Comments: add, store, format, and clear", function()
  local comments = require("jetski.comments")
  comments.clear_all_comments()

  local filepath = "/google/src/cloud/nachiketb/jetski_neovim_plugin_integration/google3/test/demo.cc"
  comments.comments[filepath] = {
    [2] = {
      file = filepath,
      display_path = "test/demo.cc",
      line = 2,
      end_line = 2,
      comment = "Check for integer overflow",
      selection = "  return a + b",
    },
  }

  local all = comments.get_all_comments()
  assert_eq(1, #all, "stored comments count")
  assert_eq("Check for integer overflow", all[1].comment, "comment text")

  local payload = comments.format_comments_payload(all)
  assert_true(payload:find("Check for integer overflow") ~= nil, "payload comment")
  assert_true(payload:find("test/demo.cc") ~= nil, "payload display path")

  comments.clear_all_comments()
  assert_eq(0, #comments.get_all_comments(), "comments cleared")
end)

-- Test 5: Diff Manager (Cider-J AgentEditManager parity)
test("Diff: snapshot, review, and reject restoration", function()
  local diff = require("jetski.diff")
  local buf = vim.api.nvim_create_buf(true, false)
  local test_file = "/google/src/cloud/nachiketb/jetski_neovim_plugin_integration/google3/test/diff_test.txt"
  vim.api.nvim_buf_set_name(buf, test_file)

  local original_lines = { "Line 1", "Line 2", "Line 3" }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, original_lines)
  vim.api.nvim_set_current_buf(buf)

  -- Record pre-edit snapshot
  diff.record_pre_edit_snapshot(test_file)
  assert_true(diff.snapshots[test_file] ~= nil, "snapshot recorded")
  assert_eq(3, #diff.snapshots[test_file].lines, "snapshot lines count")

  -- Simulate agent edit
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Line 1", "Line 2 MODIFIED BY AGENT", "Line 3" })

  -- Review diff
  diff.review_diff(test_file)
  assert_true(diff.active_diff ~= nil, "diff review active")
  assert_true(vim.api.nvim_win_is_valid(diff.active_diff.orig_win), "orig win valid")
  assert_true(vim.api.nvim_win_is_valid(diff.active_diff.mod_win), "mod win valid")

  local p_orig = vim.api.nvim_win_get_position(diff.active_diff.orig_win)
  local p_mod = vim.api.nvim_win_get_position(diff.active_diff.mod_win)
  assert_true(p_orig[2] < p_mod[2], "original/old window is on the LEFT of modified/new window")

  -- Reject edits
  diff.reject_diff(test_file)
  assert_true(diff.active_diff == nil, "diff closed after reject")

  local restored_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert_eq("Line 2", restored_lines[2], "restored line 2")

  -- Verify identical lines do not trigger diff splits
  diff.review_diff(test_file)
  assert_true(diff.active_diff == nil, "no diff created when lines are identical")

  -- Test are_lines_equal helper (including carriage return tolerance)
  assert_true(diff.are_lines_equal({ "a", "b" }, { "a", "b" }), "are_lines_equal true")
  assert_true(diff.are_lines_equal({ "a\r", "b\r" }, { "a", "b" }), "are_lines_equal CRLF match")
  assert_true(not diff.are_lines_equal({ "a", "b" }, { "a", "c" }), "are_lines_equal false")

  -- Test newly created file diffing and clean rejection
  local new_tmp = vim.fn.tempname() .. "_newfile.txt"
  vim.fn.writefile({ "Brand new line 1", "Brand new line 2" }, new_tmp)
  diff.review_diff(new_tmp)
  assert_true(diff.active_diff ~= nil, "new file triggers diff review")
  assert_eq("new file", diff.active_diff.source, "new file detected as source")
  local orig_lines_new = vim.api.nvim_buf_get_lines(diff.active_diff.orig_buf, 0, -1, false)
  assert_true(#orig_lines_new == 0 or (#orig_lines_new == 1 and orig_lines_new[1] == ""), "original lines are empty for brand new file")
  diff.reject_diff(new_tmp)
  assert_true(diff.active_diff == nil, "diff closed after rejecting new file")
  assert_true(vim.fn.filereadable(new_tmp) == 0, "rejected new file is deleted from disk")

  -- Test stale in-memory buffer reload during diff
  local reload_tmp = vim.fn.tempname() .. "_reload.txt"
  vim.fn.writefile({ "initial text" }, reload_tmp)
  local reload_buf = vim.fn.bufadd(reload_tmp)
  vim.fn.bufload(reload_buf)
  -- External modification on disk
  vim.fn.writefile({ "updated by agent on disk" }, reload_tmp)
  diff.review_diff(reload_tmp)
  assert_true(diff.active_diff ~= nil, "diff review opened for modified file")
  local cur_lines_reloaded = vim.api.nvim_buf_get_lines(diff.active_diff.mod_buf, 0, -1, false)
  assert_eq("updated by agent on disk", cur_lines_reloaded[1], "mod_buf was automatically refreshed from disk")
  local orig_lines_reloaded = vim.api.nvim_buf_get_lines(diff.active_diff.orig_buf, 0, -1, false)
  assert_eq("initial text", orig_lines_reloaded[1], "orig_buf captured initial in-memory text")
  diff.accept_diff(reload_tmp)
  assert_true(diff.active_diff == nil, "diff closed after accept")
  pcall(vim.fn.delete, reload_tmp)
  if vim.api.nvim_buf_is_valid(reload_buf) then
    pcall(vim.api.nvim_buf_delete, reload_buf, { force = true })
  end
  diff.snapshots[reload_tmp] = nil

  -- Test keymap cleanup on diff close (macros and normal mode keys restored)
  local map_tmp = vim.fn.tempname() .. "_keymaps.txt"
  vim.fn.writefile({ "v1" }, map_tmp)
  diff.record_pre_edit_snapshot(map_tmp)
  vim.fn.writefile({ "v2" }, map_tmp)
  diff.review_diff(map_tmp)
  assert_true(diff.active_diff ~= nil, "diff review active")
  local mod_buf_id = diff.active_diff.mod_buf
  diff.close_diff_review()
  assert_true(diff.active_diff == nil, "diff review closed")
  -- Verify 'q' is NOT bound on mod_buf
  local keymaps = vim.api.nvim_buf_get_keymap(mod_buf_id, "n")
  local q_bound = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "q" then q_bound = true break end
  end
  assert_true(not q_bound, "'q' is not bound on editor buffer after diff close")
  pcall(vim.fn.delete, map_tmp)
  if vim.api.nvim_buf_is_valid(mod_buf_id) then
    pcall(vim.api.nvim_buf_delete, mod_buf_id, { force = true })
  end
  diff.snapshots[map_tmp] = nil

  -- Test VCS base lines retrieval
  local readme_path = vim.fn.fnamemodify(plugin_root .. "/README.md", ":p")
  local vcs_lines, vcs_src = diff.get_vcs_base_lines(readme_path)
  assert_true(vcs_lines ~= nil and #vcs_lines > 0, "retrieved VCS base lines for README.md")
  assert_true(vcs_src ~= nil, "retrieved VCS source description: " .. tostring(vcs_src))

  -- Verify get_vcs_base_lines works when active buffer is terminal session (jetski://session)
  local term_dummy = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, term_dummy, "jetski://session")
  vim.api.nvim_set_current_buf(term_dummy)
  local vcs_lines_term, vcs_src_term = diff.get_vcs_base_lines(readme_path)
  assert_true(vcs_lines_term ~= nil and #vcs_lines_term > 0, "retrieved VCS lines while active buffer is terminal session")
  assert_true(vcs_src_term ~= nil, "retrieved VCS source while active buffer is terminal session: " .. tostring(vcs_src_term))
  pcall(vim.api.nvim_buf_delete, term_dummy, { force = true })

  -- Verify Jujutsu target_path construction logic
  local ws_info = require("jetski.workspace").detect_workspace(readme_path)
  local rel_p = ws_info.relative_path or ""
  local target_p = rel_p:find("^google3/") and ("root:" .. rel_p) or ("root:google3/" .. rel_p)
  assert_true(target_p:find("^root:google3/") ~= nil, "Jujutsu target path starts with root:google3/: " .. target_p)

  -- Clean up test_file and buffer from Test 5
  pcall(vim.fn.delete, test_file)
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  diff.snapshots[test_file] = nil
end)

test("Diff: smart resolution and multi-file review cycle", function()
  local diff = require("jetski.diff")
  diff.close_diff_review()

  local f1 = vim.fn.tempname() .. "_file1.txt"
  local f2 = vim.fn.tempname() .. "_file2.txt"
  vim.fn.writefile({ "initial 1" }, f1)
  vim.fn.writefile({ "initial 2" }, f2)

  -- Record baseline snapshots for both files
  diff.record_pre_edit_snapshot(f1)
  diff.record_pre_edit_snapshot(f2)

  -- Simulate agent modifications to both files
  vim.fn.writefile({ "agent modified 1" }, f1)
  vim.fn.writefile({ "agent modified 2" }, f2)

  -- Verify both files are detected in all_modified
  local all_mod = diff.get_all_modified_files()
  local has_f1, has_f2 = false, false
  for _, p in ipairs(all_mod) do
    if p == f1 then has_f1 = true end
    if p == f2 then has_f2 = true end
  end
  assert_true(has_f1, "f1 detected as modified")
  assert_true(has_f2, "f2 detected as modified")

  -- Create a clean dummy buffer and focus it
  local clean_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(clean_buf)

  -- When multiple files are modified and active buffer is clean, resolve_diff_target returns nil (picker)
  local target_multi = diff.resolve_diff_target()
  assert_true(target_multi == nil, "resolve_diff_target returns nil when multiple files are modified")

  -- But if current buffer is f1, resolve_diff_target returns f1
  local b1 = vim.fn.bufadd(f1)
  vim.fn.bufload(b1)
  vim.api.nvim_set_current_buf(b1)
  assert_eq(f1, diff.resolve_diff_target(), "resolve_diff_target prioritizes active buffer f1")

  -- Review and accept f1
  diff.review_diff(f1)
  assert_true(diff.active_diff ~= nil, "diff review active for f1")
  assert_eq(f1, diff.active_diff.filepath, "f1 is the reviewed target")
  diff.accept_diff(f1)
  assert_true(diff.active_diff == nil, "f1 diff closed after accept")

  -- Now only f2 remains modified
  vim.api.nvim_set_current_buf(clean_buf)
  local single_target = diff.resolve_diff_target()
  assert_eq(f2, single_target, "single remaining modified file automatically targeted from clean buffer")

  -- Review and reject f2
  diff.review_diff(f2)
  assert_true(diff.active_diff ~= nil, "diff review active for f2")
  diff.reject_diff(f2)
  assert_true(diff.active_diff == nil, "f2 diff closed after reject")

  local f2_restored = vim.fn.readfile(f2)
  assert_eq("initial 2", f2_restored[1], "f2 restored to pre-edit baseline")

  -- Now neither f1 nor f2 should have pending diffs
  diff.review_diff(f1)
  assert_true(diff.active_diff == nil, "no diff created for accepted f1")
  diff.review_diff(f2)
  assert_true(diff.active_diff == nil, "no diff created for rejected f2")

  -- Clean up
  pcall(vim.fn.delete, f1)
  pcall(vim.fn.delete, f2)
  diff.snapshots[f1] = nil
  diff.snapshots[f2] = nil
  if vim.api.nvim_buf_is_valid(clean_buf) then pcall(vim.api.nvim_buf_delete, clean_buf, { force = true }) end
  if vim.api.nvim_buf_is_valid(b1) then pcall(vim.api.nvim_buf_delete, b1, { force = true }) end
  local b2 = vim.fn.bufnr(f2)
  if b2 ~= -1 and vim.api.nvim_buf_is_valid(b2) then pcall(vim.api.nvim_buf_delete, b2, { force = true }) end
end)

test("Diff: window lifecycle, WinClosed cleanup, and existing window reuse", function()
  local diff = require("jetski.diff")
  diff.close_diff_review()

  local test_file = vim.fn.tempname() .. "_lifecycle.txt"
  vim.fn.writefile({ "original text" }, test_file)
  diff.record_pre_edit_snapshot(test_file)
  vim.fn.writefile({ "agent text" }, test_file)

  -- Open diff review
  diff.review_diff(test_file)
  assert_true(diff.active_diff ~= nil, "diff review active")
  local orig_win = diff.active_diff.orig_win
  local mod_win = diff.active_diff.mod_win
  local orig_buf = diff.active_diff.orig_buf

  assert_true(vim.wo[orig_win].diff, "orig_win has diff mode on")
  assert_true(vim.wo[mod_win].diff, "mod_win has diff mode on")

  -- Closing orig_win should automatically trigger close_diff_review
  vim.api.nvim_win_close(orig_win, true)

  -- Wait for scheduled autocmd
  vim.wait(100, function() return diff.active_diff == nil end)

  assert_true(diff.active_diff == nil, "diff review closed when orig_win was closed")
  assert_true(not vim.wo[mod_win].diff, "diff mode turned off on mod_win after orig_win closed")
  assert_true(not vim.api.nvim_buf_is_valid(orig_buf), "scratch orig_buf wiped after diff close")

  -- Re-open diff review: should reuse existing mod_win showing mod_buf
  diff.review_diff(test_file)
  assert_true(diff.active_diff ~= nil, "re-opened diff review")
  assert_eq(mod_win, diff.active_diff.mod_win, "reused existing editor window for mod_buf")
  diff.close_diff_review()
  assert_true(diff.active_diff == nil, "diff review cleanly closed")

  -- Clean up
  pcall(vim.fn.delete, test_file)
  diff.snapshots[test_file] = nil
end)

test("Diff: edge cases - empty files, unsaved new buffers, and mod_win close recovery", function()
  local diff = require("jetski.diff")
  diff.close_diff_review()

  -- 1. Test are_lines_equal with empty states
  assert_true(diff.are_lines_equal({}, {}), "empty tables are equal")
  assert_true(diff.are_lines_equal({}, { "" }), "empty table and empty line are equal")
  assert_true(diff.are_lines_equal({ "" }, {}), "empty line and empty table are equal")
  assert_true(diff.are_lines_equal({ "\r" }, {}), "carriage return empty line and empty table are equal")
  assert_true(not diff.are_lines_equal({}, { "content" }), "empty table and content are not equal")

  -- 2. Test unsaved new buffer (not yet written to disk)
  local unsaved_path = vim.fn.tempname() .. "_unsaved.txt"
  local unsaved_buf = vim.fn.bufadd(unsaved_path)
  vim.fn.bufload(unsaved_buf)
  vim.api.nvim_buf_set_lines(unsaved_buf, 0, -1, false, { "New line in unsaved buffer" })
  vim.bo[unsaved_buf].modified = true
  assert_true(vim.fn.filereadable(unsaved_path) == 0, "unsaved file does not exist on disk")

  diff.review_diff(unsaved_path)
  assert_true(diff.active_diff ~= nil, "unsaved modified buffer opens diff review")
  assert_eq("new file", diff.active_diff.source, "detected as new file")
  diff.close_diff_review()
  assert_true(diff.active_diff == nil, "diff review closed")
  if vim.api.nvim_buf_is_valid(unsaved_buf) then
    pcall(vim.api.nvim_buf_delete, unsaved_buf, { force = true })
  end
  diff.snapshots[unsaved_path] = nil

  -- 3. Test closing mod_win directly (user closes modified window; orig_win recovers editor)
  local test_recover = vim.fn.tempname() .. "_recover.txt"
  vim.fn.writefile({ "original recovery text" }, test_recover)
  diff.record_pre_edit_snapshot(test_recover)
  vim.fn.writefile({ "modified recovery text" }, test_recover)

  diff.review_diff(test_recover)
  assert_true(diff.active_diff ~= nil, "diff review active")
  local orig_w = diff.active_diff.orig_win
  local mod_w = diff.active_diff.mod_win
  local mod_b = diff.active_diff.mod_buf

  -- User closes mod_w directly
  vim.api.nvim_win_close(mod_w, true)
  vim.wait(100, function() return diff.active_diff == nil end)

  assert_true(diff.active_diff == nil, "diff review closed when mod_win was closed")
  assert_true(vim.api.nvim_win_is_valid(orig_w), "orig_win remains open to display editor")
  assert_eq(mod_b, vim.api.nvim_win_get_buf(orig_w), "orig_win transitioned to displaying mod_buf")
  assert_true(not vim.wo[orig_w].diff, "diff mode turned off on recovered window")

  -- Clean up
  pcall(vim.fn.delete, test_recover)
  diff.snapshots[test_recover] = nil
  if vim.api.nvim_buf_is_valid(mod_b) then
    pcall(vim.api.nvim_buf_delete, mod_b, { force = true })
  end
end)

-- Test 6: Terminal Command Builder
test("Terminal: command line construction", function()
  local terminal = require("jetski.terminal")
  local cmd = terminal.build_command({
    prompt = "Hello Jetski",
    continue_session = true,
  })
  assert_true(cmd:find("--prompt%-interactive=") ~= nil, "interactive prompt flag")
  assert_true(cmd:find("%-%-continue") ~= nil, "continue flag")
  assert_true(cmd:find("%-%-add%-dir=") ~= nil, "CitC add-dir flag")
end)

test("Terminal: split window creation preserves main window buffer", function()
  local terminal = require("jetski.terminal")
  local orig_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, { "Original file content" })
  local main_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(main_win, orig_buf)

  local term_buf = vim.api.nvim_create_buf(false, true)
  local split_win = terminal.create_window(term_buf)

  assert_true(main_win ~= split_win, "main window and split window are distinct")
  assert_eq(orig_buf, vim.api.nvim_win_get_buf(main_win), "main window retains original buffer")
  assert_eq(term_buf, vim.api.nvim_win_get_buf(split_win), "split window receives dedicated terminal buffer")

  -- Clean up split window
  pcall(vim.api.nvim_win_close, split_win, true)
end)

test("Terminal: background preload starts process without opening a window", function()
  local terminal = require("jetski.terminal")
  -- Reset any active terminal
  terminal.kill()

  assert_true(not terminal.is_active(), "process not active before preload")
  assert_true(not terminal.is_open(), "window not open before preload")

  terminal.preload()

  assert_true(terminal.term_buf ~= nil, "dedicated term buffer created")
  assert_true(terminal.term_win == nil, "no window created for preload")
  assert_true(terminal.is_active(), "process is active in background")
  assert_true(not terminal.is_open(), "is_open is false while window is hidden")

  -- Now calling open() reveals the preloaded buffer in a window
  terminal.open()
  assert_true(terminal.is_open(), "window is now open")
  assert_true(terminal.term_win ~= nil, "term_win assigned")
  assert_eq(terminal.term_buf, vim.api.nvim_win_get_buf(terminal.term_win), "window displays preloaded buffer")

  -- Clean up
  terminal.kill()
  assert_true(not terminal.is_active(), "cleaned up")
end)

test("Terminal: exit cleanup terminates process and wipes buffer", function()
  local terminal = require("jetski.terminal")
  terminal.preload()
  assert_true(terminal.is_active(), "process active")
  local b = terminal.term_buf
  assert_true(vim.api.nvim_buf_is_valid(b), "buffer valid")

  -- Test silent kill as invoked by VimLeavePre
  terminal.kill(true)
  assert_true(not terminal.is_active(), "process terminated")
  assert_true(not vim.api.nvim_buf_is_valid(b), "buffer deleted")
  assert_true(terminal.term_buf == nil, "term_buf reset to nil")
end)

-- Test 7: Health Check
test("Health: :checkhealth jetski executes cleanly", function()
  local health = require("jetski.health")
  local ok, err = pcall(health.check)
  assert_true(ok, "health.check succeeded without error: " .. tostring(err))
end)

-- Test 8: Commands and Plugin Autoload
test("Plugin: user commands registration", function()
  vim.g.loaded_jetski_nvim = nil
  dofile(plugin_root .. "/plugin/jetski.lua")

  local commands = {
    "Jetski",
    "JetskiToggle",
    "JetskiNew",
    "JetskiContinue",
    "JetskiKill",
    "JetskiStatus",
    "JetskiPreload",
    "JetskiAsk",
    "JetskiExplain",
    "JetskiRefactor",
    "JetskiFix",
    "JetskiTest",
    "JetskiComment",
    "JetskiCommentDelete",
    "JetskiCommentList",
    "JetskiCommentSubmit",
    "JetskiCommentClear",
    "JetskiDiff",
    "JetskiDiffReview",
    "JetskiAccept",
    "JetskiDiffAccept",
    "JetskiReject",
    "JetskiDiffReject",
    "JetskiCloseDiff",
    "JetskiDiffClose",
    "JetskiPlan",
    "JetskiWalkthrough",
    "JetskiArtifacts",
    "JetskiUpdateSkill",
    "JetskiOpenFile",
  }

  for _, cmd in ipairs(commands) do
    local def = vim.api.nvim_get_commands({})[cmd]
    assert_true(def ~= nil, string.format("Command :%s registered", cmd))
  end
end)

print("------------------------------------------")
print(string.format("Result: %d passed, %d failed", passed, failed))
print("==========================================\n")

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
