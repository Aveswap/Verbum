import SwiftUI
import UIKit

/// Renders `ShareableWordCard` to a UIImage at presentation time, then offers iOS share
/// affordances (ShareLink + a "Save Image" button).
struct WordShareSheet: View {
    let word: Word
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?
    // Default to the vertical Story/Reel format — TikTok/Reels/Stories are the primary
    // content-funnel channels. Square stays one tap away for the IG feed / carousels.
    @State private var format: ShareCardFormat = .story

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        formatPicker
                        previewCard
                        actions
                        Text("Sharing brings new learners to Verbum — thanks for the assist 🎯")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Share Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await renderImage() }
        .onChange(of: format) { _ in
            renderedImage = nil
            Task { await renderImage() }
        }
    }

    private var formatPicker: some View {
        Picker("Format", selection: $format) {
            ForEach(ShareCardFormat.allCases) { fmt in
                Text(fmt.displayName).tag(fmt)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.md)
    }

    private var previewCard: some View {
        Group {
            if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(format.aspectRatio, contentMode: .fit)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            } else {
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                    .fill(AppColors.surface)
                    .aspectRatio(format.aspectRatio, contentMode: .fit)
                    .overlay {
                        ProgressView().tint(AppColors.accent)
                    }
            }
        }
        // Cap the story preview's height so the tall 9:16 card doesn't dominate the sheet.
        .frame(maxHeight: 460)
        .padding(.horizontal, AppSpacing.md)
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.md) {
            if let image = renderedImage {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(
                        "Verbum: \(word.text)",
                        image: Image(uiImage: image)
                    )
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.accentButton)
                        .clipShape(Capsule())
                }

                Button {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    HapticManager.success()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surface)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }

    @MainActor
    private func renderImage() async {
        let renderer = ImageRenderer(content: ShareableWordCard(word: word, format: format))
        renderer.scale = 1
        renderedImage = renderer.uiImage
    }
}
