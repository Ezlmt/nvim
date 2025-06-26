return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	settings = {
		Lua = {
			diagnostics = { -- 把全局的 vim、use 等标成已定义
				globals = { "vim", "use", "require" },
			},
		},
	},
}
