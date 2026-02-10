# Prompt 17: VIBE Tab — Phase 2
# Conversation Memory, Cleanup, Polish, Vector DB Foundation

## MISSION

Phase 1 built the headless Claude Code chat UI with JSON stream parsing, permission handling, and basic conversation persistence. Phase 2 closes the gaps: clean up dead code from the old VIBE system, add markdown rendering to assistant messages, implement session resume, build the conversation memory layer with vector search, and wire up context injection so Claude Code starts every session already knowing what happened before.

## SCOPES

- A: Dead Code Cleanup
- B: Markdown Rendering in Assistant Messages
- C: Session Resume
- D: Conversation Chunking Service
- E: Embedding Service
- F: Vector Storage (Pure Swift cosine similarity)
- G: Memory Pipeline (End-to-End)
- H: Context Injection
