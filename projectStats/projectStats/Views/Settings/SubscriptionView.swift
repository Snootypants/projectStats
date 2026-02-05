import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    @State private var codeInput: String = ""
    @State private var isValidating = false

    var body: some View {
        Form {
            // Status Section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(subscription.isPro ? "Pro Active" : "Free Plan")
                            .font(.headline)
                        Text(subscription.isPro ? "All features unlocked" : "Upgrade to unlock cloud sync & more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if subscription.isPro {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Pro Features
            Section("Pro Features") {
                FeatureRow(
                    icon: "icloud",
                    title: "iCloud Sync",
                    description: "Sync across all your devices",
                    isUnlocked: subscription.hasCloudSyncAccess
                )

                FeatureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "AI-Powered Reports",
                    description: "Smart project summaries with Haiku",
                    isUnlocked: subscription.hasAIReportsAccess
                )

                FeatureRow(
                    icon: "envelope",
                    title: "Priority Support",
                    description: "Direct access to the developer",
                    isUnlocked: subscription.hasPrioritySupport
                )
            }

            // StoreKit Products
            if !store.products.isEmpty && !subscription.isPro {
                Section("Upgrade via App Store") {
                    ForEach(store.products, id: \.id) { product in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(product.displayPrice) {
                                Task { _ = try? await store.purchase(product) }
                            }
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                }
            }

            // Code Entry
            Section("Subscription Code") {
                HStack {
                    TextField("Enter code (e.g., PRO-XXXX-XXXX-XXXX)", text: $codeInput)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.uppercase)
                        .disabled(isValidating)

                    Button(isValidating ? "..." : "Activate") {
                        activateCode()
                    }
                    .disabled(codeInput.isEmpty || isValidating)
                }

                if let error = subscription.validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if subscription.isPro {
                    Button("Deactivate", role: .destructive) {
                        subscription.deactivate()
                        codeInput = ""
                    }
                }
            }

            // Purchase Link
            Section {
                Link(destination: URL(string: "https://35bird.io/projectstats/pro")!) {
                    HStack {
                        Text("Get Pro — $25")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Subscription")
    }

    private func activateCode() {
        isValidating = true

        Task {
            _ = await subscription.validateWithServer(codeInput)
            isValidating = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(isUnlocked ? .blue : .secondary)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                // Lock badge with "Pro" label for locked features
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("Pro")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(6)
            }
        }
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
}

#Preview {
    SubscriptionView()
        .frame(width: 500, height: 700)
}
