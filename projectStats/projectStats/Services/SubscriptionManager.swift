import Foundation
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @AppStorage("subscription.proCode") private var proCode: String = ""
    @AppStorage("subscription.isProActive") private var isProActive: Bool = false

    @Published var validationError: String?

    private init() {
        // Validate stored code on launch
        if !proCode.isEmpty {
            _ = validateCode(proCode)
        }
    }

    // MARK: - Feature Access

    var hasCloudSyncAccess: Bool {
        isProActive || StoreKitManager.shared.isPro
    }

    var hasAIReportsAccess: Bool {
        isProActive || StoreKitManager.shared.isPro
    }

    var hasPrioritySupport: Bool {
        isProActive || StoreKitManager.shared.isPro
    }

    var isPro: Bool {
        isProActive || StoreKitManager.shared.isPro
    }

    // MARK: - Code Validation

    /// Validates a subscription code
    /// For now, uses simple prefix validation
    /// Later: Call 35bird.io API to validate
    func validateCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Valid code formats:
        // - "PRO-XXXX-XXXX-XXXX" (purchased)
        // - "BETA-XXXX-XXXX-XXXX" (beta tester)
        // - "DEV-2026" (developer override)

        let isValid = trimmed.hasPrefix("PRO-") ||
                      trimmed.hasPrefix("BETA-") ||
                      trimmed == "DEV-2026"

        if isValid {
            proCode = trimmed
            isProActive = true
            validationError = nil
            print("[Subscription] Pro activated with code: \(trimmed.prefix(8))...")
        } else {
            isProActive = false
            validationError = "Invalid subscription code"
            print("[Subscription] Invalid code attempted")
        }

        return isValid
    }

    /// Clears subscription
    func deactivate() {
        proCode = ""
        isProActive = false
        validationError = nil
    }

    // MARK: - Future: Server Validation

    /// Validate code against 35bird.io API
    func validateWithServer(_ code: String) async -> Bool {
        // TODO: Implement when 35bird.io backend is ready
        // let url = URL(string: "https://api.35bird.io/v1/validate-code")!
        // POST { "code": code, "device_id": deviceId }
        // Returns { "valid": true, "features": ["cloud_sync", "ai_reports"] }

        // For now, use local validation
        return validateCode(code)
    }
}
