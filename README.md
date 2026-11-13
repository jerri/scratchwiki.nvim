# scratchwiki.nvim

Integrate [scratch.nvim](https://github.com/reybits/scratch.nvim) issues with
Vimwiki.

`scratchwiki.nvim` provides an editable task list inside Vimwiki pages while
using `scratch.nvim` issues as the source of truth.

It is inspired by the workflow of Taskwarrior + Taskwiki, but uses
`scratch.nvim` as the task backend.

## Features

- Render global `scratch.nvim` issues as Markdown checkboxes in Vimwiki
- Complete and reopen Scratch issues directly from Vimwiki
- Rename Scratch issues by changing their title in Vimwiki
- Create new global Scratch issues by adding Markdown checkboxes
- Automatically synchronize when saving the Vimwiki page
- Automatically refresh Scratch tasks when opening a Vimwiki page
- Filter displayed issues by status and tags
- Sort displayed issues by title, priority, type, status, creation time, or
  modification time
- Open the corresponding Scratch issue directly from the Vimwiki task
- Preserve the Scratch issue body, priority, tags, and other metadata when
  changing task status or title
- Detect conflicts and invalid task IDs before modifying Scratch files
- Supports both `[x]` and Vimwiki-style `[X]` completed checkboxes

## Requirements

- Neovim
- [Vimwiki](https://github.com/vimwiki/vimwiki)
- [reybits/scratch.nvim](https://github.com/reybits/scratch.nvim)

`scratchwiki.nvim` currently synchronizes the global issue store used by
`scratch.nvim`.

## Installation

### lazy.nvim

```lua
{
  "jerri/scratchwiki.nvim",

  dependencies = {
    "reybits/scratch.nvim",
  },

  opts = {
    sync = {
      on_open = true,
      on_save = true,
    },

    mappings = {
      open = "<CR>",
    },
  },
}
```

`opts = {}` is sufficient if you want to use the defaults:

```lua
{
  "jerri/scratchwiki.nvim",

  dependencies = {
    "reybits/scratch.nvim",
  },

  opts = {},
}
```

The plugin's `setup()` function must be called. With `lazy.nvim`, specifying
`opts = {}` causes lazy.nvim to call `setup()` automatically.

## Usage

Add a ScratchWiki block anywhere in a Vimwiki page:

```markdown
## Tasks

<!-- scratchwiki:start -->

<!-- scratchwiki:end -->
```

When the page is opened, `scratchwiki.nvim` populates the block from your
global Scratch issues:

```markdown
## Tasks

<!-- scratchwiki:start -->

- [ ] Prepare architecture presentation <!-- scratchwiki:id=2026-10-30T08-12-00 -->
- [ ] Test SharePoint integration <!-- scratchwiki:id=2026-10-30T08-15-42 -->
- [x] Update documentation <!-- scratchwiki:id=2026-10-29T16-20-10 -->

<!-- scratchwiki:end -->
```

Everything between the two ScratchWiki markers is managed by the plugin.

Content outside the markers is left untouched.

### Complete a task

Use the regular Vimwiki checkbox functionality:

```diff
- - [ ] Prepare architecture presentation <!-- scratchwiki:id=... -->
+ - [X] Prepare architecture presentation <!-- scratchwiki:id=... -->
```

Save the Vimwiki file:

```vim
:w
```

The corresponding Scratch issue is updated from:

```yaml
status: open
```

to:

```yaml
status: done
```

Both `[x]` and `[X]` are recognized as completed tasks.

### Reopen a task

Change:

```markdown
- [x] Prepare architecture presentation <!-- scratchwiki:id=... -->
```

back to:

```markdown
- [ ] Prepare architecture presentation <!-- scratchwiki:id=... -->
```

and save the file.

The Scratch issue is changed back to:

```yaml
status: open
```

### Create a task

Add a checkbox without a ScratchWiki ID:

```markdown
- [ ] Review new architecture proposal
```

Save the file.

`scratchwiki.nvim` creates a new global Scratch issue and refreshes the list.
The line then contains its generated ID:

```markdown
- [ ] Review new architecture proposal <!-- scratchwiki:id=2026-10-30T08-42-31 -->
```

New tasks currently use:

```yaml
type: task
priority: normal
status: open
tags:
```

### Rename a task

Change the task text while preserving its ScratchWiki ID:

```diff
- - [ ] Review architecture proposal <!-- scratchwiki:id=... -->
+ - [ ] Review architecture board proposal <!-- scratchwiki:id=... -->
```

Saving updates the H1 title in the corresponding Scratch issue while preserving
the rest of the issue body.

## Filtering

Filters are defined directly on the ScratchWiki start marker.

### Show only open tasks

```markdown
<!-- scratchwiki:start status=open -->

<!-- scratchwiki:end -->
```

Only Scratch issues with:

```yaml
status: open
```

are displayed.

This is useful for a normal TODO list because completed tasks disappear after
you check them and save the page.

For example:

```markdown
# TODO

<!-- scratchwiki:start status=open -->

- [ ] Prepare presentation <!-- scratchwiki:id=... -->
- [ ] Review guardrail <!-- scratchwiki:id=... -->

<!-- scratchwiki:end -->
```

After completing `Prepare presentation` and saving, its Scratch status becomes
`done` and the task disappears from this view.

### Filter by tags

Use `tags=` with a comma-separated list of tags:

```markdown
<!-- scratchwiki:start status=open tags=architecture,backend -->

<!-- scratchwiki:end -->
```

By default, every listed tag must be present on a task. Use `tag_mode=any` to
match tasks that carry at least one of the tags:

```markdown
<!-- scratchwiki:start tags=architecture,backend tag_mode=any -->
```

Tag matching is exact and case-sensitive. Tag values cannot contain spaces.

Filters combine: `status=open tags=backend` shows open tasks tagged `backend`.

## Sorting

The sort order is defined on the same start marker with `sort=`:

```markdown
<!-- scratchwiki:start status=open tags=architecture sort=-priority,title -->

<!-- scratchwiki:end -->
```

- Separate fields with commas.
- Prefix a field with `-` for descending order. Without a prefix, or with `+`,
  the field is sorted ascending.
- Later fields break ties.
- When all requested fields tie, newer Scratch issues come first.

Supported fields:

| Field | Ascending | Descending |
|---|---|---|
| `title` | A-Z, case-insensitive | Z-A |
| `priority` | low, normal, high, critical | critical, high, normal, low |
| `type` | bug, feature, refactor, task | task, refactor, feature, bug |
| `status` | open, done | done, open |
| `created` / `id` | oldest first | newest first |
| `updated` | oldest modification first | newest modification first |

Unknown priority, type, or status values are sorted after known values.

Examples:

```markdown
<!-- scratchwiki:start sort=title -->
<!-- scratchwiki:start sort=-priority,title -->
<!-- scratchwiki:start sort=-updated -->
```

Without a `sort` option, the existing newest-first order is kept.

An invalid sort field or `tag_mode` is reported with `vim.notify`, and the
managed block is left unchanged.

## Opening the Scratch issue

Put the cursor on a generated task:

```markdown
- [ ] Review architecture proposal <!-- scratchwiki:id=... -->
```

and use the configured open mapping.

For example:

```lua
opts = {
  mappings = {
    open = "<CR>",
  },
}
```

Pressing `<CR>` opens the corresponding issue using `scratch.nvim`, allowing
you to edit its full description and metadata.

The mapping is buffer-local to applicable Vimwiki buffers.

You can choose another mapping instead:

```lua
opts = {
  mappings = {
    open = "gf",
  },
}
```

## Commands

### `:ScratchWikiRefresh`

Refresh the current ScratchWiki block from the Scratch issue store. Filters and
the sort order from the start marker are applied.

```vim
:ScratchWikiRefresh
```

This performs:

```text
Scratch -> Vimwiki
```

### `:ScratchWikiSync`

Show a dry run of the changes that would be made to Scratch:

```vim
:ScratchWikiSync
```

Example:

```text
UPDATE   line 5: 2026-10-30T08-12-00 (status: open -> done)
CREATE   line 8: Review architecture proposal [open]

Summary: 1 create, 1 update, 12 unchanged, 0 orphan
```

No Scratch files are modified.

### `:ScratchWikiSync!`

Apply the synchronization:

```vim
:ScratchWikiSync!
```

This can:

- create Scratch issues
- update issue status
- update issue titles

The managed Vimwiki block is refreshed afterwards.

### `:ScratchWikiOpen`

Open the Scratch issue under the cursor:

```vim
:ScratchWikiOpen
```

## Automatic synchronization

Automatic synchronization operates on Vimwiki buffers containing a
ScratchWiki block.

On opening a Vimwiki buffer:

```text
Scratch
   |
   v
Vimwiki
```

On saving:

```text
Vimwiki
   |
   v
Scratch
   |
   v
refresh Vimwiki block
```

The synchronization happens before the Vimwiki buffer is written so IDs
assigned to newly created tasks are included in the same save.

A Vimwiki file without ScratchWiki markers is ignored.

### Disable automatic synchronization

```lua
opts = {
  sync = {
    on_open = false,
    on_save = false,
  },
}
```

You can then use `:ScratchWikiRefresh` and `:ScratchWikiSync!` manually.

## Scratch issue format

`scratchwiki.nvim` works with the Markdown issue format used by
`scratch.nvim`:

```markdown
---
type: task
priority: high
status: open
tags: architecture
---

# Review architecture proposal

Detailed information about the task can live here.

## Notes

Arbitrary Markdown content is preserved.
```

ScratchWiki currently modifies only the fields required by synchronization:

- `status`
- the issue H1 title

Other metadata and body content are preserved.

## How it works

Scratch remains the source of truth.

```text
                    scratch.nvim issues
                           |
               +-----------+-----------+
               |                       |
               v                       v
          reconciliation           filtering
               |                       |
               |                       v
               |                    sorting
               |                       |
               |                       v
               |                  Vimwiki view
               |                       |
               +<----------------------+
                       user edits
```

Each rendered task contains a stable ID:

```markdown
<!-- scratchwiki:id=2026-10-30T08-12-00 -->
```

This allows ScratchWiki to distinguish between:

- an existing task whose status changed
- an existing task whose title changed
- a newly created task
- an orphaned task whose Scratch issue no longer exists

Missing tasks are not interpreted as deletions.

## Safety

`scratchwiki.nvim` deliberately takes a conservative approach to
synchronization:

- Scratch issue bodies are preserved
- updates verify the previous title/status before modifying an issue
- duplicate IDs abort synchronization
- orphaned IDs abort synchronization
- missing Vimwiki entries do not delete Scratch issues
- synchronization can be inspected first with `:ScratchWikiSync`
- only content between ScratchWiki markers is regenerated

Deletion of Scratch issues from Vimwiki is currently not supported.

## Development

Tests use the Plenary/Busted test runner.

Run the complete test suite:

```sh
nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/"
```

On PowerShell:

```powershell
nvim --headless `
  -u tests/minimal_init.lua `
  -c "PlenaryBustedDirectory tests/"
```

The tests cover:

- Markdown parsing/rendering
- Scratch issue parsing and updates
- reconciliation
- validation
- status and tag filtering
- sorting
- managed Vimwiki blocks
- synchronization
- end-to-end synchronization

## Roadmap

Possible future additions include:

- filter by priority
- filter by issue type
- sort by tags
- multiple filtered task views
- richer Taskwiki-style view definitions
- configurable defaults for newly created tasks
- editing Scratch metadata from Vimwiki
- improved conflict handling

Current view examples:

```markdown
<!-- scratchwiki:start status=open tags=architecture -->
```

```markdown
<!-- scratchwiki:start status=open tags=architecture,backend tag_mode=any sort=-priority,title -->
```

A future priority filter might look like:

```markdown
<!-- scratchwiki:start status=open priority=high -->
```

## Acknowledgements

`scratchwiki.nvim` is inspired by
[Taskwiki](https://github.com/tools-life/taskwiki), which provides a similar
workflow between Vimwiki and Taskwarrior.

The task backend and issue editing interface are provided by
[scratch.nvim](https://github.com/reybits/scratch.nvim).

## License

MIT License. See [LICENSE](LICENSE).
