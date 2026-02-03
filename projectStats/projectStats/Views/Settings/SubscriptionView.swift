import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var store = StoreKitManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Subscription")
                    Spacer()
                    if store.isPro {
                        Text("Pro")
                            .foregroundStyle(.green)
                    } else {
                        Text("Free")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
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
            } header: {
                Text("Upgrade to Pro")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SubscriptionView()
}
