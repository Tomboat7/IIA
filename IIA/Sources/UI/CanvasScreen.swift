import SwiftUI
import PencilKit

/// キャンバス画面（メインの描画画面）
/// UX_Design.md に従い、横画面時は左にツールバー、下にフッター＆レイヤパネル
struct CanvasScreen: View {
    @ObservedObject var document: IllustrationDocument
    @StateObject private var brushSettings = BrushSettings()
    @EnvironmentObject var documentManager: DocumentManager

    @State private var selectedTool: SelectedTool = .brush
    @State private var isLayerPanelExpanded = true
    @State private var showExportSheet = false
    @State private var showRenameAlert = false
    @State private var newDocumentName = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .onDisappear {
            // 画面を離れる時に自動保存
            documentManager.saveDocument(document)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(document: document)
        }
        .alert("ドキュメント名の変更", isPresented: $showRenameAlert) {
            TextField("ドキュメント名", text: $newDocumentName)
            Button("キャンセル", role: .cancel) {}
            Button("変更") {
                if !newDocumentName.isEmpty {
                    document.name = newDocumentName
                }
            }
        }
    }

    // MARK: - Landscape Layout

    /// 横画面レイアウト
    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            // 左側: ツールバー
            ToolbarView(
                brushSettings: brushSettings,
                document: document,
                selectedTool: $selectedTool
            )
            .padding(.leading, 12)
            .padding(.vertical, 12)

            // 中央: キャンバス
            VStack(spacing: 0) {
                canvasArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 下部: フッター
                footerView
            }

            // 右下: レイヤパネル
            VStack {
                Spacer()
                LayerListView(
                    document: document,
                    isExpanded: $isLayerPanelExpanded
                )
                .padding(.trailing, 12)
                .padding(.bottom, 60) // フッターの高さ分
            }
        }
    }

    // MARK: - Portrait Layout

    /// 縦画面レイアウト（横画面と同じ配置を維持）
    private var portraitLayout: some View {
        HStack(spacing: 0) {
            // 左側: サイドバー（戻る、ファイル名など）とレイヤパネル
            VStack(spacing: 8) {
                // 戻るボタン
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                }

                Divider()
                    .frame(width: 30)

                // ドキュメント名（縦書き風に省略表示）
                Text(document.name)
                    .font(.caption)
                    .lineLimit(1)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 100)

                Spacer()

                // レイヤパネル
                LayerListView(
                    document: document,
                    isExpanded: $isLayerPanelExpanded
                )
            }
            .padding(.leading, 8)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.9))

            // メイン領域
            VStack(spacing: 0) {
                // 上部: ツールバー（横向きに配置）
                HStack(spacing: 12) {
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

                    Divider().frame(height: 30)

                    // カラー
                    ColorPicker("", selection: $brushSettings.color)
                        .labelsHidden()
                        .frame(width: 32, height: 32)

                    Spacer()

                    // Undo/Redo
                    ToolButton(
                        systemName: "arrow.uturn.backward",
                        isEnabled: document.canUndo,
                        action: { document.undo() }
                    )

                    ToolButton(
                        systemName: "arrow.uturn.forward",
                        isEnabled: document.canRedo,
                        action: { document.redo() }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                )

                // キャンバス
                canvasArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // フッター
                footerView
            }
        }
    }

    // MARK: - Canvas Area

    /// キャンバスエリア（全レイヤを表示）
    private var canvasArea: some View {
        ZStack {
            // 背景色
            Rectangle()
                .fill(document.backgroundColor)

            // 非アクティブレイヤを画像として表示
            ForEach(Array(document.layers.enumerated()), id: \.element.id) { index, layer in
                if layer.isVisible && index != document.activeLayerIndex {
                    LayerImageView(layer: layer, canvasSize: document.canvasSize)
                        .opacity(layer.opacity)
                }
            }

            // アクティブレイヤ（PencilKit）
            if let activeLayer = document.activeLayer, activeLayer.isVisible {
                CanvasView(
                    document: document,
                    brushSettings: brushSettings,
                    isUsingEraser: Binding(
                        get: { selectedTool == .eraser },
                        set: { if $0 { selectedTool = .eraser } else { selectedTool = .brush } }
                    )
                )
                .opacity(activeLayer.opacity)
            }
        }
    }

    // MARK: - Footer

    /// フッター
    private var footerView: some View {
        HStack(spacing: 16) {
            // 戻るボタン
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("ホーム")
                }
                .font(.subheadline)
            }

            Spacer()

            // ドキュメント名（タップでリネーム）
            Button(action: {
                newDocumentName = document.name
                showRenameAlert = true
            }) {
                Text(document.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            Spacer()

            // エクスポートボタン
            Button(action: { showExportSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 2, y: -2)
        )
    }
}

/// レイヤを画像として表示するビュー
struct LayerImageView: View {
    let layer: Layer
    let canvasSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            if let image = renderImage(size: geometry.size) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }

    private func renderImage(size: CGSize) -> UIImage? {
        let drawing = layer.drawing
        guard !drawing.bounds.isEmpty else { return nil }

        let scale = min(
            size.width / canvasSize.width,
            size.height / canvasSize.height
        )

        return drawing.image(
            from: CGRect(origin: .zero, size: canvasSize),
            scale: scale
        )
    }
}

/// エクスポートシート
struct ExportSheet: View {
    let document: IllustrationDocument
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var documentManager: DocumentManager
    @State private var exportFormat: ExportFormat = .png
    @State private var includeBackground = true
    @State private var showShareSheet = false
    @State private var exportedImage: UIImage?

    enum ExportFormat: String, CaseIterable {
        case png = "PNG"
        case jpeg = "JPEG"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("フォーマット") {
                    Picker("形式", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("オプション") {
                    Toggle("背景を含める", isOn: $includeBackground)
                }

                Section("サイズ") {
                    HStack {
                        Text("出力サイズ")
                        Spacer()
                        Text("\(Int(document.canvasSize.width)) x \(Int(document.canvasSize.height)) px")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("エクスポート") {
                        exportImage()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("エクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = exportedImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    private func exportImage() {
        // DocumentManager のエクスポート機能を使用
        exportedImage = documentManager.exportAsUIImage(document: document, includeBackground: includeBackground)
        showShareSheet = true
    }
}

/// 共有シート
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    CanvasScreen(document: IllustrationDocument())
        .environmentObject(DocumentManager())
}
