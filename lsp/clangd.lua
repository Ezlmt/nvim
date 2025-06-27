return {
	cmd = {
		vim.fn.stdpath("data") .. "/mason/bin/clangd",
	},
  init_options = {
    fallbackFlags ={ "-std=c++23" },
  },
	filetypes = { "c", "cc", "cpp", "objc", "objcpp", "cuda" },
	root_markers = {
		".clangd",
		".clang-tidy",
		".clang-format",
		"compile_commands.json",
		"compile_flags.txt",
		"configure.ac",
		".git",
	},
	capabilities = {
		textDocument = {
			completion = {
				editsNearCursor = true,
			},
		},
		offsetEncoding = { "utf-8", "utf-16" },
	},
}
