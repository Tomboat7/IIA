import Foundation
import SwiftUI
import PencilKit

// MARK: - Future Improvements
// TODO: テストコードの追加 - Undo/Redo ロジック、Codable 実装のユニットテスト
// Note: 日本語文字列はCLAUDE.mdの方針により多言語対応は不要、ハードコードを維持

/// イラストドキュメント全体を表すモデル
/// キャンバスの状態、レイヤ、設定などを管理
class IllustrationDocument: ObservableObject, Identifiable, Codable {
    // MARK: - Constants

    /// 最大Undo回数
    static let maxUndoCount = 50
    /// デフォルトキャンバスサイズ
    static let defaultCanvasSize = CGSize(width: 2048, height: 2048)
    /// デフォルト新規ドキュメント名
    static let defaultDocumentName = "新規イラスト"
    /// デフォルトレイヤ名
    static let defaultLayerName = "レイヤ"

    // MARK: - Properties

    let id: UUID
    @Published var name: String
    @Published var canvasSize: CGSize
    @Published var backgroundColor: Color
    @Published var layers: [Layer]
    @Published var activeLayerIndex: Int
    var createdAt: Date
    @Published var updatedAt: Date

    // Undo/Redo 管理
    private struct DocumentState {
        let layers: [Layer]
        let activeLayerIndex: Int
    }

    private var undoStack: [DocumentState] = []
    private var redoStack: [DocumentState] = []

    init(
        id: UUID = UUID(),
        name: String = Self.defaultDocumentName,
        canvasSize: CGSize = Self.defaultCanvasSize,
        backgroundColor: Color = .white
    ) {
        self.id = id
        self.name = name
        self.canvasSize = canvasSize
        self.backgroundColor = backgroundColor
        self.layers = [Layer(name: "\(Self.defaultLayerName) 1")]
        self.activeLayerIndex = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, canvasWidth, canvasHeight
        case backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha
        case layers, activeLayerIndex, createdAt, updatedAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let width = try container.decode(CGFloat.self, forKey: .canvasWidth)
        let height = try container.decode(CGFloat.self, forKey: .canvasHeight)
        canvasSize = CGSize(width: width, height: height)

        let red = try container.decode(Double.self, forKey: .backgroundColorRed)
        let green = try container.decode(Double.self, forKey: .backgroundColorGreen)
        let blue = try container.decode(Double.self, forKey: .backgroundColorBlue)
        let alpha = try container.decode(Double.self, forKey: .backgroundColorAlpha)
        backgroundColor = Color(red: red, green: green, blue: blue, opacity: alpha)

        layers = try container.decode([Layer].self, forKey: .layers)
        activeLayerIndex = try container.decode(Int.self, forKey: .activeLayerIndex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(canvasSize.width, forKey: .canvasWidth)
        try container.encode(canvasSize.height, forKey: .canvasHeight)

        let uiColor = UIColor(backgroundColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        // getRed は色空間によっては失敗する可能性があるが、その場合はデフォルト値（0）を使用
        // Note: SwiftUI Color → UIColor の変換では通常成功する
        _ = uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // 有効範囲（0.0-1.0）内にクランプ
        try container.encode(Double(max(0, min(1, red))), forKey: .backgroundColorRed)
        try container.encode(Double(max(0, min(1, green))), forKey: .backgroundColorGreen)
        try container.encode(Double(max(0, min(1, blue))), forKey: .backgroundColorBlue)
        try container.encode(Double(max(0, min(1, alpha))), forKey: .backgroundColorAlpha)

        try container.encode(layers, forKey: .layers)
        try container.encode(activeLayerIndex, forKey: .activeLayerIndex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Layer Management

    /// アクティブレイヤを取得
    var activeLayer: Layer? {
        guard activeLayerIndex >= 0 && activeLayerIndex < layers.count else { return nil }
        return layers[activeLayerIndex]
    }

    /// 新しいレイヤを追加
    func addLayer() {
        saveUndoState()
        let newLayer = Layer(name: "\(Self.defaultLayerName) \(layers.count + 1)")
        layers.insert(newLayer, at: activeLayerIndex + 1)
        activeLayerIndex += 1
        updatedAt = Date()
    }

    /// レイヤを削除
    func deleteLayer(at index: Int) {
        guard layers.count > 1, index >= 0 && index < layers.count else { return }
        saveUndoState()
        layers.remove(at: index)
        if activeLayerIndex >= layers.count {
            activeLayerIndex = layers.count - 1
        }
        updatedAt = Date()
    }

    /// レイヤの順序を変更
    func moveLayer(from source: IndexSet, to destination: Int) {
        saveUndoState()
        layers.move(fromOffsets: source, toOffset: destination)
        updatedAt = Date()
    }

    /// アクティブレイヤの描画を更新
    func updateActiveLayerDrawing(_ drawing: PKDrawing) {
        guard activeLayerIndex >= 0 && activeLayerIndex < layers.count else { return }
        layers[activeLayerIndex].updateDrawing(drawing)
        updatedAt = Date()
    }

    // MARK: - Undo/Redo

    /// 現在の状態を Undo スタックに保存
    func saveUndoState() {
        undoStack.append(DocumentState(layers: layers, activeLayerIndex: activeLayerIndex))
        if undoStack.count > Self.maxUndoCount {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Undo を実行
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(DocumentState(layers: layers, activeLayerIndex: activeLayerIndex))
        layers = previousState.layers
        // 空配列の場合は0、それ以外は有効範囲内に収める
        if layers.isEmpty {
            activeLayerIndex = 0
        } else {
            activeLayerIndex = min(max(0, previousState.activeLayerIndex), layers.count - 1)
        }
        updatedAt = Date()
    }

    /// Redo を実行
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(DocumentState(layers: layers, activeLayerIndex: activeLayerIndex))
        layers = nextState.layers
        // 空配列の場合は0、それ以外は有効範囲内に収める
        if layers.isEmpty {
            activeLayerIndex = 0
        } else {
            activeLayerIndex = min(max(0, nextState.activeLayerIndex), layers.count - 1)
        }
        updatedAt = Date()
    }

    /// Undo が可能か
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Redo が可能か
    var canRedo: Bool {
        !redoStack.isEmpty
    }
}
