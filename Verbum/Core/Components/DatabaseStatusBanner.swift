import SwiftUI

/// Compact banner shown in SettingsView (and during active download as a toast).
struct DatabaseStatusBanner: View {
    @ObservedObject private var manager = DatabaseDownloadManager.shared

    var body: some View {
        switch manager.state {
        case .idle:
            downloadPrompt
        case .downloading(let pct):
            progressRow(pct)
        case .installing:
            statusRow(icon: "arrow.triangle.2.circlepath",
                      text: "Installing dictionary…",
                      color: AppColors.accent)
        case .done:
            statusRow(icon: "checkmark.circle.fill",
                      text: "Full dictionary ready (\(WordDatabase.shared.totalCount().formatted()) words)",
                      color: .green)
        case .failed:
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Download failed")
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Retry") { manager.retry() }
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    // MARK: - Sub-views

    private var downloadPrompt: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Full Dictionary")
                    .foregroundColor(AppColors.textPrimary)
                Text("Download 50,000 words for offline use")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Button("Download") { manager.startIfNeeded() }
                .foregroundColor(AppColors.accent)
        }
    }

    private func progressRow(_ pct: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Downloading dictionary…")
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(Int(pct * 100))%")
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
                Button("Cancel") { manager.cancel() }
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
            ProgressView(value: pct)
                .tint(AppColors.accent)
        }
    }

    private func statusRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).foregroundColor(AppColors.textPrimary)
        }
    }
}
