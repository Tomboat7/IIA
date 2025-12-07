import Foundation
import PencilKit

/// レイヤを表すモデル
/// 各レイヤは描画内容と表示状態を持つ
struct Layer: Identifiable, Codable {
    let id: UUID
    var name: String
    var isVisible: Bool
    var opacity: Double
    var drawingData: Data // PKDrawing をエンコードしたデータ

    init(
        id: UUID = UUID(),
        name: String = "レイヤ",
        isVisible: Bool = true,
        opacity: Double = 1.0,
        drawing: PKDrawing = PKDrawing()
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.opacity = opacity
        self.drawingData = drawing.dataRepresentation()
    }

    /// PKDrawing を取得
    var drawing: PKDrawing {
        get {
            (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        }
        set {
            drawingData = newValue.dataRepresentation()
        }
    }

    // Codable 用のカスタムキー
    enum CodingKeys: String, CodingKey {
        case id, name, isVisible, opacity, drawingData
    }
}
