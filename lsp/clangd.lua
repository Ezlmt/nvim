return {
	cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
		"--header-insertion=never",
		"--pch-storage=memory",
		"--completion-style=detailed",
		"-j=8",
	},
	init_options = {
		fallbackFlags = {
			"-std=c++20",
			"-I/usr/local/google/home/element/android_workspace/vendor/google/services/LyricCameraHAL/src",
		},
	},
	filetypes = { "c", "cc", "cpp", "objc", "objcpp", "cuda" },
	root_markers = {
		"compile_commands.json",
		".clangd",
		".repo",
		".clang-tidy",
		".clang-format",
		"compile_flags.txt",
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
