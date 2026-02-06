import Foundation

/// Service for managing Agent Teams (Swarm) per-project state and SKILL.md deployment
enum AgentTeamsService {

    // MARK: - Per-Project Swarm State (stored in .projectstats/config.json)

    static func isSwarmEnabled(for projectPath: String) -> Bool {
        let configURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".projectstats")
            .appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let enabled = json["swarmEnabled"] as? Bool else {
            // Fallback: check legacy UserDefaults
            return UserDefaults.standard.bool(forKey: "swarm.enabled.\(projectPath)")
        }
        return enabled
    }

    static func setSwarmEnabled(_ enabled: Bool, for projectPath: String) {
        let dirURL = URL(fileURLWithPath: projectPath).appendingPathComponent(".projectstats")
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let configURL = dirURL.appendingPathComponent("config.json")

        // Read existing config or start fresh
        var config: [String: Any] = [:]
        if let data = try? Data(contentsOf: configURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            config = existing
        }
        config["swarmEnabled"] = enabled

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try? data.write(to: configURL)
        }

        // Also update legacy UserDefaults for backwards compat
        UserDefaults.standard.set(enabled, forKey: "swarm.enabled.\(projectPath)")
    }

    // MARK: - SKILL.md Deployment (to .claude/skills/)

    static func deploySkillMd(to projectRoot: URL, projectName: String) throws {
        let skillsDir = projectRoot
            .appendingPathComponent(".claude")
            .appendingPathComponent("skills")
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        let skillURL = skillsDir.appendingPathComponent("swarm-orchestration-SKILL.md")
        let content = skillMdContent(projectName: projectName)
        try content.write(to: skillURL, atomically: true, encoding: .utf8)
    }

    /// Swarm OFF does NOT delete files — SKILL.md remains as valid documentation
    static func removeSkillMd(from projectRoot: URL) {
        // Intentionally empty — files are NOT deleted when swarm is toggled off
    }

    // MARK: - Global Settings (~/.claude/settings.json)

    static var agentTeamsGlobalEnabled: Bool {
        guard let data = try? Data(contentsOf: globalSettingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = json["env"] as? [String: Any],
              let value = env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] as? String else {
            return false
        }
        return value == "1"
    }

    static func setAgentTeamsGlobal(_ enabled: Bool) {
        let fm = FileManager.default
        let url = globalSettingsURL

        // Read existing or create new
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        var env = json["env"] as? [String: Any] ?? [:]

        if enabled {
            env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        } else {
            env.removeValue(forKey: "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS")
        }

        json["env"] = env

        // Ensure ~/.claude/ exists
        let claudeDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        try? fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }

    private static var globalSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
    }

    // MARK: - SKILL.md Content

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
