import SwiftUI
import PencilKit

/// レイヤパネル（右下に配置、開閉可能）
struct LayerListView: View {
    // MARK: - Constants

    /// 最大レイヤ数
    private static let maxLayers = 20
    /// パネルの幅
    private static let panelWidth: CGFloat = 200
    /// レイヤリストの最大高さ
    private static let maxListHeight: CGFloat = 200

    // MARK: - Properties

    @ObservedObject var document: IllustrationDocument
    @Binding var isExpanded: Bool
    @State private var editingLayerId: UUID?
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー（タブ部分）
            HStack {
                Text("レイヤ")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                // レイヤ追加ボタン
                Button(action: { document.addLayer() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                }
                .disabled(document.layers.count >= Self.maxLayers)

                // 展開/折りたたみボタン
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))

            if isExpanded {
                // レイヤリスト
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(document.layers.enumerated().reversed()), id: \.element.id) { reversedIndex, layer in
                            let actualIndex = document.layers.count - 1 - reversedIndex
                            LayerRow(
                                layer: binding(for: actualIndex),
                                isActive: document.activeLayerIndex == actualIndex,
                                isEditing: editingLayerId == layer.id,
                                editingName: $editingName,
                                onSelect: {
                                    document.activeLayerIndex = actualIndex
                                },
                                onToggleVisibility: {
                                    document.layers[actualIndex].isVisible.toggle()
                                },
                                onStartEditing: {
                                    editingLayerId = layer.id
                                    editingName = layer.name
                                },
                                onEndEditing: {
                                    if !editingName.isEmpty {
                                        document.layers[actualIndex].name = editingName
                                    }
                                    editingLayerId = nil
                                },
                                onDelete: {
                                    document.deleteLayer(at: actualIndex)
                                }
                            )
                        }
                        .onMove { source, destination in
                            // 逆順表示なので調整が必要
                            let adjustedSource = IndexSet(source.map { document.layers.count - 1 - $0 })
                            let adjustedDestination = document.layers.count - destination
                            document.moveLayer(from: adjustedSource, to: adjustedDestination)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: Self.maxListHeight)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        )
        .frame(width: Self.panelWidth)
    }

    private func binding(for index: Int) -> Binding<Layer> {
        Binding(
            get: { document.layers[index] },
            set: { document.layers[index] = $0 }
        )
    }
}

/// レイヤ行
struct LayerRow: View {
    @Binding var layer: Layer
    let isActive: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // サムネイル
            LayerThumbnail(layer: layer)
                .frame(width: 36, height: 36)
                .cornerRadius(4)

            // レイヤ名
            if isEditing {
                TextField("レイヤ名", text: $editingName, onCommit: onEndEditing)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            } else {
                Text(layer.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
                    .onTapGesture(count: 2) {
                        onStartEditing()
                    }
            }

            Spacer()

            // 表示/非表示
            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 14))
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("名前を変更") {
                onStartEditing()
            }

            Button("削除", role: .destructive) {
                onDelete()
            }
        }
    }
}

/// レイヤサムネイル（キャッシュ機能付き）
struct LayerThumbnail: View {
    let layer: Layer
    @StateObject private var cache: ThumbnailCache
    @State private var currentSize: CGSize = .zero

    init(layer: Layer) {
        self.layer = layer
        _cache = StateObject(wrappedValue: ThumbnailCache(layer: layer))
    }

    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: SizePreferenceKey.self,
                value: geometry.size
            )
            if let image = cache.cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
        }
        .onPreferenceChange(SizePreferenceKey.self) { size in
            currentSize = size
            cache.updateIfNeeded(layer: layer, size: size)
        }
        .onChange(of: layer.version) { _ in
            // レイヤのバージョンが変わったらキャッシュを強制更新
            cache.updateIfNeeded(layer: layer, size: currentSize)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .opacity(layer.isVisible ? layer.opacity : 0.5)
    }
}

// Note: SizePreferenceKey is defined in CanvasScreen.swift and shared across views

/// レイヤサムネイルのキャッシュ管理
private class ThumbnailCache: ObservableObject {
    @Published var cachedImage: UIImage?
    private var cachedVersion: Int = -1
    private var lastSize: CGSize = .zero
    
    init(layer: Layer) {
        // 初期化時に最初のバージョンを記録
        self.cachedVersion = layer.version
    }
    
    func updateIfNeeded(layer: Layer, size: CGSize) {
        // バージョンまたはサイズが変わった場合のみ更新
        guard cachedVersion != layer.version || lastSize != size else { return }
        
        cachedImage = renderThumbnail(layer: layer, size: size)
        cachedVersion = layer.version
        lastSize = size
    }
    
    private func renderThumbnail(layer: Layer, size: CGSize) -> UIImage? {
        let drawing = layer.drawing
        guard !drawing.bounds.isEmpty else { return nil }

        let scale = min(
            size.width / drawing.bounds.width,
            size.height / drawing.bounds.height
        )

        return drawing.image(from: drawing.bounds, scale: scale)
    }
}

// MARK: - Opacity Slider (for future use)

struct LayerOpacitySlider: View {
    @Binding var opacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("不透明度: \(Int(opacity * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)

            Slider(value: $opacity, in: 0.1...1.0)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        HStack {
            Spacer()
            LayerListView(
                document: IllustrationDocument(),
                isExpanded: .constant(true)
            )
            .padding()
        }
    }
    .background(Color(.systemGray4))
}
