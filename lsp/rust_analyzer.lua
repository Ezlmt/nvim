return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = {
		"Cargo.toml",
		"rust-project.json",
		".git",
	},
	settings = {
		["rust-analyzer"] = {
			check = {
				command = "clippy",
			},
			cargo = {
				allFeatures = true,
			},
			inlayHints = {
				bindingModeHints = { enable = true },
				chainingHints = { enable = true },
				closingBraceHints = { enable = true },
				closureCaptureHints = { enable = true },
				closureReturnTypeHints = { enable = "always" },
				lifetimeElisionHints = { enable = "always" },
				parameterHints = { enable = true },
				typeHints = { enable = true },
			},
		},
	},
}
