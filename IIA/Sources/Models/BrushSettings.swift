import Foundation
import SwiftUI
import PencilKit

/// ブラシの種類
enum BrushType: String, CaseIterable, Codable {
    case pen = "ペン"
    case pencil = "鉛筆"
    case marker = "マーカー"

    /// PencilKit の InkType に変換
    var inkType: PKInkingTool.InkType {
        switch self {
        case .pen:
            return .pen
        case .pencil:
            return .pencil
        case .marker:
            return .marker
        }
    }
}

/// ブラシ設定を管理するモデル
class BrushSettings: ObservableObject {
    @Published var brushType: BrushType = .pen
    @Published var brushSize: CGFloat = 5.0
    @Published var opacity: Double = 1.0
    @Published var color: Color = .black

    /// 最小・最大サイズ
    static let minBrushSize: CGFloat = 1.0
    static let maxBrushSize: CGFloat = 100.0

    /// 現在の設定から PKInkingTool を生成
    func createInkingTool() -> PKInkingTool {
        let uiColor = UIColor(color).withAlphaComponent(CGFloat(opacity))
        return PKInkingTool(brushType.inkType, color: uiColor, width: brushSize)
    }

    /// 消しゴムツールを生成
    func createEraserTool() -> PKEraserTool {
        return PKEraserTool(.vector)
    }
}
