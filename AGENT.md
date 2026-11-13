# AGENT.md

Guidance for automated contributors and future maintainers working on
`scratchwiki.nvim`.

## Project purpose

`scratchwiki.nvim` renders global `scratch.nvim` issues as editable Markdown
checkboxes inside Vimwiki pages. Scratch issues are the source of truth. Only
content between the ScratchWiki markers is managed by the plugin.

## Repository layout

| Path | Responsibility |
|---|---|
| `plugin/scratchwiki.lua` | User commands |
| `lua/scratchwiki/init.lua` | Setup, refresh, open-at-cursor |
| `lua/scratchwiki/config.lua` | Defaults and merged options |
| `lua/scratchwiki/wiki.lua` | Start/end markers, managed block replacement |
| `lua/scratchwiki/markdown.lua` | Render and parse task lines |
| `lua/scratchwiki/scratch.lua` | Read, update, and create Scratch issue files |
| `lua/scratchwiki/filter.lua` | Marker-driven filtering |
| `lua/scratchwiki/sort.lua` | Marker-driven sorting |
| `lua/scratchwiki/reconcile.lua` | Compare Scratch tasks with Vimwiki tasks |
| `lua/scratchwiki/validate.lua` | Duplicate ID and status validation |
| `lua/scratchwiki/sync.lua` | Dry-run and execute synchronization |
| `lua/scratchwiki/autocmds.lua` | FileType and BufWritePre integration |
| `tests/` | Plenary/Busted test suite |
| `README.md` | User-facing documentation |
| `doc/scratchwiki.txt` | Vim help |

## Refresh pipeline

```text
scratch.list()
  -> filter.apply(tasks, marker options)
  -> sort.apply(tasks, marker options)
  -> markdown.render(tasks)
  -> wiki.replace_block(bufnr, lines)
```

Sorting and filtering are view-only. They must never change synchronization or
reconciliation behavior.

## Core invariants

- Scratch remains the source of truth.
- Refreshing is one-way: Scratch -> Vimwiki.
- Synchronizing is Vimwiki -> Scratch, followed by a refresh.
- Only content between `<!-- scratchwiki:start ... -->` and
  `<!-- scratchwiki:end -->` may be regenerated.
- Reconciliation is ID-based, never position-based. Task order in Vimwiki is
  presentation only.
- Missing Vimwiki entries do not delete Scratch issues.
- Orphaned or duplicate IDs abort synchronization before writes.
- Synchronization only changes the Scratch `status` field and the first H1
  title. The issue body and other frontmatter fields must be preserved.
- The trailing `<!-- scratchwiki:id=... -->` comment must remain at the end of
  a task line; parsing depends on that position.
- `refresh()` must never write to Scratch issue files.
- Both `[x]` and `[X]` are valid completed checkboxes.

## Marker options

Marker syntax:

```markdown
<!-- scratchwiki:start status=open tags=architecture,backend tag_mode=all sort=-priority,title -->
```

Current options:

- `status=open|done`
- `tags=tag1,tag2` — exact and case-sensitive
- `tag_mode=all|any` — defaults to `all`
- `sort=field[,field...]`
  - `-field` sorts descending
  - `+field` or `field` sorts ascending
  - fields: `title`, `priority`, `type`, `status`, `created`, `id`, `updated`

Values cannot contain whitespace with the current marker parser
(`wiki.parse_start_marker`).

## Adding a new marker option

1. Confirm the option belongs to the view layer. If it affects synchronization,
   stop and review `reconcile.lua`, `validate.lua`, and `sync.lua` first.
2. Parse the option with the existing marker parser. Add a test in
   `tests/wiki_spec.lua`.
3. Implement validation and behavior in `filter.lua`, `sort.lua`, or a new
   focused module. Keep the implementation pure where possible.
4. Return `nil, "actionable message"` for invalid values.
5. Wire it into `init.refresh()` after filtering and/or sorting as appropriate.
   Prefix notifications with `scratchwiki: ` and return `false` on failure.
6. Add unit tests for the module and an integration test in
   `tests/integration_spec.lua`.
7. Update `README.md` and `doc/scratchwiki.txt`, including the help tags and
   table of contents where appropriate.
8. Run the complete test suite.

## Sorting rules

- `priority` rank: `low < normal < high < critical`
- `type` rank: `bug < feature < refactor < task`
- `status` rank: `open < done`
- `title` comparison is case-insensitive.
- Unknown priority, type, or status values sort after known values in both
  directions.
- A missing `updated` timestamp sorts last.
- After all requested keys tie, newer Scratch IDs come first.
- `table.sort` is not stable. The sort module decorates entries with their
  original index and uses deterministic tie-breaking.
- Without a `sort` option, preserve the order from `scratch.list()`, which is
  newest-first by ID.

## Coding conventions

- Lua with four spaces, no tabs.
- Modules return a local `M` table.
- Annotate typed/public functions with LuaLS comments where useful.
- Prefer small pure helpers in `filter.lua` and `sort.lua`; keep filesystem
  and buffer side effects in `scratch.lua`, `wiki.lua`, `sync.lua`, and
  `init.lua`.
- Invalid user input should produce a clear `vim.notify` error and leave the
  managed block untouched.
- Avoid new global state. `config.options` is the existing exception.
- Keep compatibility with the Neovim version already required by the project.
- Do not add unrelated refactors to a behavior change.

## Tests

The suite uses Plenary's Busted-compatible runner. From the repository root:

```sh
nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/"
```

Run one file:

```sh
nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/sort_spec.lua"
```

Test expectations:

- Filter and sort unit tests should be pure and fast.
- Integration tests should use temporary directories and call
  `config.setup({ scratch_dir = directory })`, then restore configuration.
- Clean up temporary directories in `after_each`.
- Do not depend on a real user Scratch store.
- Test error paths, especially invalid marker options and `vim.notify` calls.
- Add tests at every relevant layer: marker parsing, pure behavior, and
  end-to-end refresh/sync.

## Documentation

When behavior changes:

- Update `README.md` for users.
- Update `doc/scratchwiki.txt` for `:help scratchwiki`.
- Add or adjust help tags for new sections.
- Keep the README roadmap and test coverage list current.
- Run `:helptags ALL` if the plugin manager does not regenerate tags.

## Commit hygiene

Use small, logical commits with conventional prefixes:

- `feat(filter): ...`
- `feat(sort): ...`
- `feat(refresh): ...`
- `test: ...`
- `docs: ...`

Keep behavior changes, tests, and documentation for one feature together.
Do not mix broad refactors with feature work.

## Definition of done

- [ ] Behavior is implemented and wired into the refresh or sync path.
- [ ] Invalid input produces an actionable error.
- [ ] Unit tests cover the new behavior.
- [ ] Integration tests cover the user-visible result.
- [ ] The complete test suite passes.
- [ ] `README.md` and `doc/scratchwiki.txt` are updated.
- [ ] Only managed Vimwiki content is modified.
- [ ] Scratch issue bodies and unrelated metadata remain untouched.

## Deferred and known limitations

- Tag values containing spaces are unsupported by the marker grammar.
- Filtering by priority or issue type is not implemented.
- Sorting by tags is not implemented.
- Cursor preservation is line-based; sorting can move the task under the
  cursor.
- Unknown marker option keys are silently ignored.
- A bare `sort=` value is ignored by the current marker parser.
