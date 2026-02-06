import Foundation

enum SwarmTestPrompt {
    static let kanbanPrompt = """
    # Build Kanban App — Agent Teams (Swarm)

    ## LEAD AGENT
    Owns: integration, final testing, commit
    Files: index.html (shared read), all files (final review)
    Tasks:
    1. Wait for all teammates to complete
    2. Integration test: drag-drop works, persistence survives refresh, theme toggle restyles all
    3. Fix any cross-file coordination bugs
    4. Commit and push

    ## TEAMMATE 1: HTML Structure
    Owns: index.html
    Constraints:
    - 3 columns: To Do, In Progress, Done
    - Cards use data-id, data-column attributes
    - Drag handles with draggable="true"
    - Empty state messages per column
    - Theme toggle button in header
    - Keyboard shortcut hints (N = new card, Ctrl+Z = undo)
    - NO inline styles, NO inline scripts
    - Use semantic HTML5 elements

    ## TEAMMATE 2: Styling
    Owns: style.css
    Constraints:
    - CSS custom properties for all colors (--bg, --card-bg, --text, --accent, etc.)
    - Light and dark themes via [data-theme="dark"] on body
    - Responsive: works 320px to 1920px
    - Card hover states, drag-over column highlighting
    - Error state styles (.error, .validation-error)
    - Transitions on theme change (0.2s ease)
    - Max 400 lines

    ## TEAMMATE 3: JavaScript Logic
    Owns: app.js
    Constraints:
    - State store pattern: single source of truth object
    - CRUD: add card (title required), edit inline, delete with confirm
    - Drag and drop between columns (HTML5 drag API)
    - localStorage persistence (save on every mutation, load on init)
    - Undo stack (last 10 actions)
    - Keyboard shortcuts: N = new card, Ctrl+Z = undo, Escape = cancel edit
    - Filter/search cards by title
    - No external libraries
    - Max 600 lines

    ## COORDINATION CONTRACT
    - Column IDs: "todo", "in-progress", "done"
    - Card class: ".kanban-card"
    - Card data attributes: data-id="uuid", data-column="todo|in-progress|done"
    - Theme toggle: button#theme-toggle, body[data-theme="light|dark"]
    - New card button: button#add-card
    - Search input: input#search-cards
    - Total budget: <2500 lines across all files
    """
}
