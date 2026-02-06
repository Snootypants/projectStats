import Foundation

/// Service for managing Agent Teams (Swarm) per-project state and SKILL.md deployment
enum AgentTeamsService {

    // MARK: - Per-Project Swarm State

    static func isSwarmEnabled(for projectPath: String) -> Bool {
        UserDefaults.standard.bool(forKey: "swarm.enabled.\(projectPath)")
    }

    static func setSwarmEnabled(_ enabled: Bool, for projectPath: String) {
        UserDefaults.standard.set(enabled, forKey: "swarm.enabled.\(projectPath)")
    }

    // MARK: - SKILL.md Deployment

    static func deploySkillMd(to projectRoot: URL, projectName: String) throws {
        let content = skillMdContent(projectName: projectName)
        let skillURL = projectRoot.appendingPathComponent("SKILL.md")
        try content.write(to: skillURL, atomically: true, encoding: .utf8)
    }

    static func removeSkillMd(from projectRoot: URL) {
        let skillURL = projectRoot.appendingPathComponent("SKILL.md")
        try? FileManager.default.removeItem(at: skillURL)
    }

    static func skillMdContent(projectName: String) -> String {
        """
        # SKILL.md — \(projectName) Agent Teams (Swarm) Configuration

        ## Purpose
        This file coordinates multi-agent swarm mode for \(projectName).
        When swarm mode is active, multiple Claude Code agents can work in parallel
        on different parts of the codebase.

        ## Coordination Rules

        ### File Ownership
        - Each agent claims files it is actively editing
        - No two agents should edit the same file simultaneously
        - Agents must check this file before modifying shared resources

        ### Communication Protocol
        - Agents report progress by updating their section below
        - Blocked agents should note what they're waiting for
        - Completed agents mark their section as DONE

        ### Conflict Prevention
        - Always pull latest before starting work
        - Use feature branches when possible
        - Coordinate through commit messages with [SWARM] prefix

        ## Active Agents
        <!-- Agents register here when working -->

        | Agent | Task | Files | Status |
        |-------|------|-------|--------|
        | — | — | — | Idle |

        ## Shared State Warnings
        - Database migrations must be sequential
        - Package.swift / package.json changes need coordination
        - CI/CD config changes require team review
        """
    }
}
