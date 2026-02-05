import SwiftUI

/// V5 Project Activity - Horizontal bars showing time per project
struct V5ProjectActivity: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    private var projectData: [(project: Project, percentage: Double)] {
        // Get recent projects and estimate activity based on lines
        let recent = viewModel.homeProjects.prefix(5)
        let totalLines = recent.reduce(0) { $0 + ($1.lineCount ?? 0) }

        guard totalLines > 0 else {
            return recent.map { ($0, 1.0 / Double(max(recent.count, 1))) }
        }

        return recent.map { project in
            let percentage = Double(project.lineCount ?? 0) / Double(totalLines)
            return (project, percentage)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PROJECT ACTIVITY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(projectData, id: \.project.id) { item in
                projectBar(project: item.project, percentage: item.percentage)
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func projectBar(project: Project, percentage: Double) -> some View {
        HStack(spacing: 12) {
            Text(project.name)
                .font(.caption.bold())
                .lineLimit(1)
                .frame(width: 120, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentColor)
                        .frame(width: max(4, geo.size.width * percentage))
                }
            }
            .frame(height: 16)

            Text("\(Int(percentage * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Color Hex Extension

private extension Color {
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        return Color(red: r, green: g, blue: b)
    }
}

#Preview {
    V5ProjectActivity()
        .environmentObject(DashboardViewModel.shared)
        .padding()
}
