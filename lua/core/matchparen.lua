-- Custom matchparen: only highlight the MATCHING bracket, not the one under cursor
local ns = vim.api.nvim_create_namespace("custom_matchparen")

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	callback = function()
		vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

		local cursor = vim.api.nvim_win_get_cursor(0)
		local row = cursor[1]
		local col = cursor[2]
		local line = vim.api.nvim_get_current_line()
		local char = line:sub(col + 1, col + 1)

		local open_pairs = { ["("] = ")", ["["] = "]", ["{"] = "}" }
		local close_pairs = { [")"] = "(", ["]"] = "[", ["}"] = "{" }

		local search_pair, flags
		if open_pairs[char] then
			search_pair = { char, open_pairs[char] }
			flags = "nW"
		elseif close_pairs[char] then
			search_pair = { close_pairs[char], char }
			flags = "bnW"
		else
			return
		end

		local match_row, match_col = unpack(vim.fn.searchpairpos(
			"\\V" .. search_pair[1],
			"",
			"\\V" .. search_pair[2],
			flags
		))

		if match_row > 0 then
			vim.api.nvim_buf_add_highlight(0, ns, "MatchParen", match_row - 1, match_col - 1, match_col)
		end
	end,
})
