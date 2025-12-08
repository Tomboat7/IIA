import SwiftUI
import PencilKit

/// レイヤパネル（右下に配置、開閉可能）
struct LayerListView: View {
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
                .disabled(document.layers.count >= 20) // 最大20レイヤ

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
                        ForEach(Array(document.layers.enumerated().reversed()), id: \.element.id) { index, layer in
                            LayerRow(
                                layer: binding(for: index),
                                isActive: document.activeLayerIndex == index,
                                isEditing: editingLayerId == layer.id,
                                editingName: $editingName,
                                onSelect: {
                                    document.activeLayerIndex = index
                                },
                                onToggleVisibility: {
                                    document.layers[index].isVisible.toggle()
                                },
                                onStartEditing: {
                                    editingLayerId = layer.id
                                    editingName = layer.name
                                },
                                onEndEditing: {
                                    if !editingName.isEmpty {
                                        document.layers[index].name = editingName
                                    }
                                    editingLayerId = nil
                                },
                                onDelete: {
                                    document.deleteLayer(at: index)
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
                .frame(maxHeight: 200)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        )
        .frame(width: 200)
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

            Button("複製") {
                // TODO: 複製機能
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
    @State private var cachedImage: UIImage?
    @State private var cachedVersion: Int = -1

    var body: some View {
        GeometryReader { geometry in
            if let image = getThumbnail(size: geometry.size) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .opacity(layer.isVisible ? layer.opacity : 0.5)
    }

    private func getThumbnail(size: CGSize) -> UIImage? {
        // バージョンが変わっていない場合はキャッシュを使用
        if cachedVersion == layer.version, let cached = cachedImage {
            return cached
        }
        
        // サムネイルを生成
        let thumbnail = renderThumbnail(size: size)
        cachedImage = thumbnail
        cachedVersion = layer.version
        return thumbnail
    }

    private func renderThumbnail(size: CGSize) -> UIImage? {
        let drawing = layer.drawing
        guard !drawing.bounds.isEmpty else { return nil }

        let scale = min(
            size.width / drawing.bounds.width,
            size.height / drawing.bounds.height
        )
        let thumbnailSize = CGSize(
            width: drawing.bounds.width * scale,
            height: drawing.bounds.height * scale
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
