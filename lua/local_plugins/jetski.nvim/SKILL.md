---
name: nvim
description: Seamlessly interact with the host Neovim editor instance when running inside Neovim.
---

# Skill: Neovim Integration

> [!CAUTION]
> **CRITICAL USAGE CONDITION**: This skill **MUST ONLY** be used if the agent is running inside a Neovim terminal session (i.e. the environment variable `NVIM` is non-empty). If you are not running inside a Neovim terminal, you **MUST IGNORE** all instructions and recipes in this file.

This skill allows the Jetski agent to seamlessly interact with the Neovim editor instance hosting the terminal, bringing full parity with Cider-J.

## Instructions

### 1. Detection
When running inside a Neovim terminal, the environment variable `NVIM` is automatically set to the address of Neovim's active RPC server socket (e.g. `/tmp/nvim.../0` or similar).

You can verify it via:
```bash
echo "$NVIM"
```

### 2. Opening and Showing Files
> [!IMPORTANT]
> 1. Whenever the user asks to "show", "view", "open", or "see" a file, you **MUST** open it directly in the current Neovim session using the RPC command below, rather than merely printing the content into the chat.
> 2. Whenever you inform the user that a file has been modified, created, or is ready for review, you **MUST** open it in Neovim so the user can inspect it immediately.
> 3. Whenever you need to open several files at once, use the `open_files` RPC command.

#### Open a single file:
```bash
nvim --server "$NVIM" --remote-send "<C-\><C-n>:lua require('jetski').open_file('<file_path>', <line_number>)<CR>"
```

#### Open multiple files:
```bash
nvim --server "$NVIM" --remote-send "<C-\><C-n>:lua require('jetski').open_files({'<file1>', '<file2>'})<CR>"
```

### 3. Implementation Plans and Walkthroughs
Whenever you produce or update an implementation plan, task list, or walkthrough artifact:
- Inform the user of the plan or walkthrough.
- Automatically command Neovim to display the artifact buffer in a split:

```bash
# Open implementation plan
nvim --server "$NVIM" --remote-send "<C-\><C-n>:lua require('jetski').open_plan('<path_to_plan.md>')<CR>"

# Open walkthrough
nvim --server "$NVIM" --remote-send "<C-\><C-n>:lua require('jetski').open_walkthrough('<path_to_walkthrough.md>')<CR>"
```

### 4. Interactive Diff Review (Cider-J Parity)
When you modify files or when the user asks to review changes:
- Trigger an interactive side-by-side diff review directly in Neovim:
```bash
nvim --server "$NVIM" --remote-send "<C-\><C-n>:lua require('jetski').diff_review('<path_to_modified_file>')<CR>"
```
This enables Neovim's interactive diff view where the user can accept all changes with `:JetskiAccept` (`<leader>ya`), reject changes with `:JetskiReject` (`<leader>yr`), or navigate hunks with `]c` and `[c`.

### 5. Handling Code Review Comments
When the user submits code review comments from Neovim, you will receive a prompt formatted with JSON structured as:
```json
[
  {
    "file": "/absolute/path/to/source.go",
    "display_path": "source.go",
    "line": 42,
    "end_line": 48,
    "comment": "Refactor this block to use the new Context API instead of global state.",
    "selection": "func MyHandler(w http.ResponseWriter, r *http.Request) {\n  ...\n}"
  }
]
```
You **MUST** treat each entry as direct line-specific feedback from the user. Address each comment systematically, explain the changes made, and update the code accordingly.
