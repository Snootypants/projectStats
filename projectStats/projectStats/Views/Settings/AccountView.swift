import SwiftUI

struct AccountView: View {
    @StateObject private var store = StoreKitManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("App License")
                    Spacer()
                    Text("Purchased")
                        .foregroundStyle(.green)
                }
                HStack {
                    Text("Subscription")
                    Spacer()
                    Text(store.isPro ? "Pro" : "Free")
                        .foregroundStyle(store.isPro ? .green : .secondary)
                }
            }

            Section {
                Toggle("iCloud Sync", isOn: .constant(true))
                    .disabled(true)
                Toggle("35bird Cloud Sync", isOn: .constant(store.isPro))
                    .disabled(true)
            } header: {
                Text("Services")
            } footer: {
                Text(store.isPro ? "Cloud sync enabled." : "Upgrade to Pro to enable 35bird cloud sync.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    AccountView()
}
