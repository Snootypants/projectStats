Prompt summary:
- Consolidate project data into SwiftData as the source of truth.
- Add terminal output monitoring for git events to trigger syncs.
- Cache commit history and update UI to reflect live data.

Closing report:
- Added CachedCommit model + schema, terminal output monitor, and git log parsing.
- Implemented per-project sync to SwiftData with hashing and commit caching.
- Wired terminal output to trigger debounced syncs and surfaced cached commits in the UI.
