return {
	cmd = {
		vim.fn.stdpath("data") .. "/mason/bin/lua-language-server",
	},
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
		},
	},
}
