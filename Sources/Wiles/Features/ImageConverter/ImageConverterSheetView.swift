import SwiftUI

struct ImageConverterSheetView: View {
    private static let sheetWidth: CGFloat = 420
    private static let pickerLabelWidth: CGFloat = 130
    private static let labelFontSize: CGFloat = 12
    private static let qualityValueFontSize: CGFloat = 11
    private static let qualityValueWidth: CGFloat = 40
    private static let defaultJPEGQuality: Double = 0.85
    private static let qualitySliderRange: ClosedRange<Double> = 0.1 ... 1.0
    private static let qualitySliderStep: Double = 0.05

    let item: FileItem
    var appState: AppState

    @Environment(\.dismiss)
    private var dismiss
    @State private var targetFormat: ImageFormat = .jpeg
    @State private var preset: ResizePreset = .original
    @State private var cropPreset: CropPreset = .none
    @State private var quality: Double = Self.defaultJPEGQuality

    var body: some View {
        ModalScaffoldView(
            icon: .image(item.icon),
            title: item.name,
            subtitle: item.formattedSize,
            width: Self.sheetWidth,
            primaryButton: ModalFooterButton(title: appState.tr(.convert)) {
                appState.performImageConversion(
                    item: item,
                    targetFormat: targetFormat,
                    preset: preset,
                    cropPreset: cropPreset,
                    quality: quality)
                dismiss()
            },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { settingsSection })
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            formatPickerRow
            cropPickerRow
            resizePickerRow
            if targetFormat == .jpeg || targetFormat == .heic {
                qualitySliderRow
            }
        }
        .padding(20)
    }

    private var formatPickerRow: some View {
        HStack {
            Text(appState.tr(.targetFormat) + ":")
                .font(.system(size: Self.labelFontSize, weight: .semibold))
                .frame(width: Self.pickerLabelWidth, alignment: .leading)
            Picker("", selection: $targetFormat) {
                ForEach(ImageFormat.allCases) { fmt in
                    Text(appState.tr(fmt.l10nKey)).tag(fmt)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var cropPickerRow: some View {
        HStack {
            Text(appState.tr(.cropPreset) + ":")
                .font(.system(size: Self.labelFontSize, weight: .semibold))
                .frame(width: Self.pickerLabelWidth, alignment: .leading)
            Picker("", selection: $cropPreset) {
                ForEach(CropPreset.allCases) { cropOption in
                    Text(appState.tr(cropOption.l10nKey)).tag(cropOption)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var resizePickerRow: some View {
        HStack {
            Text(appState.tr(.resizePreset) + ":")
                .font(.system(size: Self.labelFontSize, weight: .semibold))
                .frame(width: Self.pickerLabelWidth, alignment: .leading)
            Picker("", selection: $preset) {
                ForEach(ResizePreset.allCases) { resizePreset in
                    Text(appState.tr(resizePreset.l10nKey)).tag(resizePreset)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var qualitySliderRow: some View {
        HStack {
            Text(appState.tr(.quality) + ":")
                .font(.system(size: Self.labelFontSize, weight: .semibold))
                .frame(width: Self.pickerLabelWidth, alignment: .leading)
            Slider(value: $quality, in: Self.qualitySliderRange, step: Self.qualitySliderStep)
            Text("\(Int(quality * 100))%")
                .font(.system(size: Self.qualityValueFontSize, design: .monospaced))
                .frame(width: Self.qualityValueWidth)
        }
    }
}
