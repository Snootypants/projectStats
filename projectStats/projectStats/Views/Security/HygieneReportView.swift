import SwiftUI

struct HygieneReportView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Code Hygiene Report")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Security")
                    .font(.subheadline)
                Text("✅ No secrets detected")
                Text("✅ .env in .gitignore")
                Text("⚠️ 2 dependencies with known vulnerabilities")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Code Quality")
                    .font(.subheadline)
                Text("✅ SwiftLint: 0 errors, 12 warnings")
                Text("⚠️ TODO comments: 7 found")
                Text("⚠️ FIXME comments: 3 found")
            }

            HStack {
                Button("Fix All Auto-fixable") {}
                Button("Generate Detailed Report") {}
            }
        }
        .padding()
    }
}

#Preview {
    HygieneReportView()
}
