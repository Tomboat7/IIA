import Foundation
import SwiftUI
import PencilKit

/// イラストドキュメント全体を表すモデル
/// キャンバスの状態、レイヤ、設定などを管理
class IllustrationDocument: ObservableObject, Identifiable, Codable {
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
    private let maxUndoCount = 50

    init(
        id: UUID = UUID(),
        name: String = "新規イラスト",
        canvasSize: CGSize = CGSize(width: 2048, height: 2048),
        backgroundColor: Color = .white
    ) {
        self.id = id
        self.name = name
        self.canvasSize = canvasSize
        self.backgroundColor = backgroundColor
        self.layers = [Layer(name: "レイヤ 1")]
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
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        try container.encode(Double(red), forKey: .backgroundColorRed)
        try container.encode(Double(green), forKey: .backgroundColorGreen)
        try container.encode(Double(blue), forKey: .backgroundColorBlue)
        try container.encode(Double(alpha), forKey: .backgroundColorAlpha)

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
        let newLayer = Layer(name: "レイヤ \(layers.count + 1)")
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
        if undoStack.count > maxUndoCount {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Undo を実行
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(DocumentState(layers: layers, activeLayerIndex: activeLayerIndex))
        layers = previousState.layers
        activeLayerIndex = min(max(0, previousState.activeLayerIndex), max(0, layers.count - 1))
        updatedAt = Date()
    }

    /// Redo を実行
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(DocumentState(layers: layers, activeLayerIndex: activeLayerIndex))
        layers = nextState.layers
        activeLayerIndex = min(max(0, nextState.activeLayerIndex), max(0, layers.count - 1))
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
