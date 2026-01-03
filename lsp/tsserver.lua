return {
	cmd = { "typescript-language-server", "--stdio" },

	filetypes = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
		"vue",
	},

	root_markers = {
		"tsconfig.json",
		"jsconfig.json",
		"package.json",
		".git",
	},
}
