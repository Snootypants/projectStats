import Foundation
import StoreKit
import os.log

enum ProductID: String {
    case proMonthly = "com.35bird.projectstats.pro.monthly"
    case proYearly = "com.35bird.projectstats.pro.yearly"
}

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed

    enum SubscriptionStatus {
        case notSubscribed
        case subscribed(expirationDate: Date)
        case expired
    }

    var isPro: Bool {
        if case .subscribed = subscriptionStatus { return true }
        return false
    }

    private init() {
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                ProductID.proMonthly.rawValue,
                ProductID.proYearly.rawValue
            ])
        } catch {
            Log.subscription.error("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == ProductID.proMonthly.rawValue ||
                    transaction.productID == ProductID.proYearly.rawValue {
                    subscriptionStatus = .subscribed(expirationDate: transaction.expirationDate ?? Date.distantFuture)
                    return
                }
            }
        }
        subscriptionStatus = .notSubscribed
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }
}

enum StoreError: Error {
    case failedVerification
}
