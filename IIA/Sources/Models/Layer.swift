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
    var version: Int // 描画データの更新を追跡するためのバージョン

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
        self.version = 0
    }

    /// PKDrawing を取得
    var drawing: PKDrawing {
        get {
            (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        }
        set {
            drawingData = newValue.dataRepresentation()
            version += 1
        }
    }

    // Codable 用のカスタムキー
    enum CodingKeys: String, CodingKey {
        case id, name, isVisible, opacity, drawingData, version
    }
    
    // Codable の実装（バージョンがない古いデータに対応）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        opacity = try container.decode(Double.self, forKey: .opacity)
        drawingData = try container.decode(Data.self, forKey: .drawingData)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
    }
}
