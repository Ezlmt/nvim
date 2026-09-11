local lua_cmd = "lua-language-server"
local mason_lua = vim.fn.stdpath("data") .. "/mason/bin/lua-language-server"
if vim.fn.executable(mason_lua) == 1 then
	lua_cmd = mason_lua
end

return {
	cmd = { lua_cmd },
	filetypes = { "lua" },

	root_markers = {
		".git",
		".luarc.json",
		".luarc.jsonc",
	},

	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				checkThirdParty = false,
			},
			telemetry = {
				enable = false,
			},
			hint = {
				enable = true,
				setType = true,
				paramType = true,
				paramName = "All",
				semicolon = "Disable",
				arrayIndex = "Disable",
			},
		},
	},
}
