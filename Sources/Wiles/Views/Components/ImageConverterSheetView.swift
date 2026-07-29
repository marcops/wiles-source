import SwiftUI

struct ImageConverterSheetView: View {
    let item: FileItem
    var appState: AppState
    
    @Environment(\.dismiss) private var dismiss
    @State private var targetFormat: ImageFormat = .jpeg
    @State private var preset: ResizePreset = .original
    @State private var cropPreset: CropPreset = .none
    @State private var quality: Double = 0.85
    
    @State private var customWidthText: String = ""
    @State private var customHeightText: String = ""
    
    @State private var cropNormX: Double = 0.1
    @State private var cropNormY: Double = 0.1
    @State private var cropNormW: Double = 0.8
    @State private var cropNormH: Double = 0.8
    
    @State private var loadedNSImage: NSImage? = nil
    
    private var customCropRegion: CustomCropRegion {
        CustomCropRegion(normX: cropNormX, normY: cropNormY, normW: cropNormW, normH: cropNormH)
    }
    
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
            
            if cropPreset == .custom, let img = loadedNSImage {
                interactiveCropCanvas(img: img)
            }
            
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
                        ForEach(CropPreset.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text(appState.tr(.resizePreset) + ":")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 130, alignment: .leading)
                    Picker("", selection: $preset) {
                        ForEach(ResizePreset.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if preset == .custom {
                    HStack(spacing: 12) {
                        Spacer().frame(width: 130)
                        TextField("Width (px)", text: $customWidthText)
                            .textFieldStyle(.roundedBorder)
                        Text("x").font(.system(size: 12)).foregroundColor(.secondary)
                        TextField("Height (px)", text: $customHeightText)
                            .textFieldStyle(.roundedBorder)
                    }
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
                    let cw = Int(customWidthText)
                    let ch = Int(customHeightText)
                    appState.performImageConversion(
                        item: item,
                        targetFormat: targetFormat,
                        preset: preset,
                        cropPreset: cropPreset,
                        cropRegion: customCropRegion,
                        customWidth: cw,
                        customHeight: ch,
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
            if let img = NSImage(contentsOf: item.url) {
                self.loadedNSImage = img
            }
        }
    }
    
    @ViewBuilder
    private func interactiveCropCanvas(img: NSImage) -> some View {
        VStack(spacing: 4) {
            Text("Drag to Crop Selection")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                ZStack(alignment: .topLeading) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: w, height: h)
                    
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.2))
                        .frame(width: max(20, w * cropNormW), height: max(20, h * cropNormH))
                        .offset(x: w * cropNormX, y: h * cropNormY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newX = max(0, min(1 - cropNormW, value.location.x / w))
                                    let newY = max(0, min(1 - cropNormH, value.location.y / h))
                                    cropNormX = newX
                                    cropNormY = newY
                                }
                        )
                }
            }
            .frame(height: 140)
            .background(Color.black.opacity(0.1))
            .cornerRadius(6)
        }
    }
}
