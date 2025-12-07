import SwiftUI

/// 選択中のツール
enum SelectedTool: Equatable {
    case brush
    case eraser
}

/// 縦方向のツールバー（横画面時は左側、縦画面時は上部に配置）
struct ToolbarView: View {
    @ObservedObject var brushSettings: BrushSettings
    @ObservedObject var document: IllustrationDocument
    @Binding var selectedTool: SelectedTool
    @State private var showColorPicker = false
    @State private var showBrushSettings = false

    var body: some View {
        VStack(spacing: 12) {
            // ブラシ
            ToolButton(
                systemName: "paintbrush.pointed.fill",
                isSelected: selectedTool == .brush,
                action: { selectedTool = .brush }
            )

            // 消しゴム
            ToolButton(
                systemName: "eraser.fill",
                isSelected: selectedTool == .eraser,
                action: { selectedTool = .eraser }
            )

            Divider()
                .frame(width: 30)
                .background(Color.gray.opacity(0.5))

            // カラーピッカー
            Button(action: { showColorPicker = true }) {
                Circle()
                    .fill(brushSettings.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    )
            }
            .popover(isPresented: $showColorPicker) {
                ColorPickerPopover(selectedColor: $brushSettings.color)
            }

            // ブラシ設定
            ToolButton(
                systemName: "slider.horizontal.3",
                isSelected: showBrushSettings,
                action: { showBrushSettings = true }
            )
            .popover(isPresented: $showBrushSettings) {
                BrushSettingsPopover(brushSettings: brushSettings)
            }

            Spacer()

            // Undo
            ToolButton(
                systemName: "arrow.uturn.backward",
                isSelected: false,
                isEnabled: document.canUndo,
                action: { document.undo() }
            )

            // Redo
            ToolButton(
                systemName: "arrow.uturn.forward",
                isSelected: false,
                isEnabled: document.canRedo,
                action: { document.redo() }
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

/// ツールバーのボタン
struct ToolButton: View {
    let systemName: String
    var isSelected: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundColor(
                    isEnabled
                        ? (isSelected ? .accentColor : .primary)
                        : .gray.opacity(0.5)
                )
                .frame(width: 44, height: 44)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
                .cornerRadius(8)
        }
        .disabled(!isEnabled)
    }
}

/// カラーピッカーのポップオーバー
struct ColorPickerPopover: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss

    // プリセットカラー
    private let presetColors: [Color] = [
        .black, .gray, .white,
        .red, .orange, .yellow,
        .green, .blue, .purple,
        .pink, .brown, .cyan
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("カラー")
                .font(.headline)

            // プリセットカラーグリッド
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 4), spacing: 8) {
                ForEach(presetColors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedColor == color ? Color.accentColor : Color.gray.opacity(0.3),
                                        lineWidth: selectedColor == color ? 3 : 1
                                    )
                            )
                    }
                }
            }

            Divider()

            // iOS 標準のカラーピッカー
            ColorPicker("カスタムカラー", selection: $selectedColor)
                .labelsHidden()

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 220)
    }
}

/// ブラシ設定のポップオーバー
struct BrushSettingsPopover: View {
    @ObservedObject var brushSettings: BrushSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("ブラシ設定")
                .font(.headline)

            // ブラシタイプ
            VStack(alignment: .leading, spacing: 8) {
                Text("ブラシの種類")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("ブラシの種類", selection: $brushSettings.brushType) {
                    ForEach(BrushType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            // ブラシサイズ
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("サイズ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(brushSettings.brushSize)) px")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $brushSettings.brushSize,
                    in: BrushSettings.minBrushSize...BrushSettings.maxBrushSize
                )
            }

            // 不透明度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("不透明度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(brushSettings.opacity * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $brushSettings.opacity,
                    in: 0.1...1.0
                )
            }

            // プレビュー
            BrushPreview(brushSettings: brushSettings)
                .frame(height: 60)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 260)
    }
}

/// ブラシのプレビュー
struct BrushPreview: View {
    @ObservedObject var brushSettings: BrushSettings

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                path.move(to: CGPoint(x: 20, y: height / 2))
                path.addCurve(
                    to: CGPoint(x: width - 20, y: height / 2),
                    control1: CGPoint(x: width * 0.3, y: height * 0.2),
                    control2: CGPoint(x: width * 0.7, y: height * 0.8)
                )
            }
            .stroke(
                brushSettings.color.opacity(brushSettings.opacity),
                style: StrokeStyle(
                    lineWidth: brushSettings.brushSize,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    HStack {
        ToolbarView(
            brushSettings: BrushSettings(),
            document: IllustrationDocument(),
            selectedTool: .constant(.brush)
        )
        .padding()

        Spacer()
    }
    .frame(height: 500)
    .background(Color(.systemGray5))
}
