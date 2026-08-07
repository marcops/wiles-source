import SwiftUI

struct ImageConverterSheetView: View {
    let item: FileItem
    var appState: AppState

    @Environment(\.dismiss)
    private var dismiss
    @State private var targetFormat: ImageFormat = .jpeg
    @State private var preset: ResizePreset = .original
    @State private var cropPreset: CropPreset = .none
    @State private var quality: Double = 0.85

    @State private var loadedNSImage: NSImage?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Text(item.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(appState.tr(.targetFormat) + ":")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 130, alignment: .leading)
                    Picker("", selection: $targetFormat) {
                        ForEach(ImageFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text(appState.tr(.cropPreset) + ":")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 130, alignment: .leading)
                    Picker("", selection: $cropPreset) {
                        ForEach(CropPreset.allCases) { cropOption in
                            Text(cropOption.displayName).tag(cropOption)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text(appState.tr(.resizePreset) + ":")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 130, alignment: .leading)
                    Picker("", selection: $preset) {
                        ForEach(ResizePreset.allCases) { resizePreset in
                            Text(resizePreset.displayName).tag(resizePreset)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if targetFormat == .jpeg || targetFormat == .heic {
                    HStack {
                        Text(appState.tr(.quality) + ":")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 130, alignment: .leading)
                        Slider(value: $quality, in: 0.1...1.0, step: 0.05)
                        Text("\(Int(quality * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 40)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Spacer()
                Button(appState.tr(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button(appState.tr(.convert)) {
                    appState.performImageConversion(
                        item: item,
                        targetFormat: targetFormat,
                        preset: preset,
                        cropPreset: cropPreset,
                        quality: quality
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            let url = item.url
            Task.detached(priority: .userInitiated) {
                let img = NSImage(contentsOf: url)
                await MainActor.run {
                    self.loadedNSImage = img
                }
            }
        }
    }
}
