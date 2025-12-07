import SwiftUI
import PencilKit

/// PencilKit の PKCanvasView を SwiftUI でラップしたビュー
struct CanvasView: UIViewRepresentable {
    @ObservedObject var document: IllustrationDocument
    @ObservedObject var brushSettings: BrushSettings
    @Binding var isUsingEraser: Bool

    /// 描画変更時のコールバック
    var onDrawingChanged: ((PKDrawing) -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = UIColor(document.backgroundColor)
        canvasView.drawingPolicy = .anyInput // Apple Pencil と指の両方を許可
        canvasView.minimumZoomScale = 0.5
        canvasView.maximumZoomScale = 5.0
        canvasView.isOpaque = false

        // 初期ツールを設定
        updateTool(canvasView)

        // アクティブレイヤの描画を設定
        if let activeLayer = document.activeLayer {
            canvasView.drawing = activeLayer.drawing
        }

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // ツールを更新
        updateTool(canvasView)

        // 背景色を更新
        canvasView.backgroundColor = UIColor(document.backgroundColor)

        // レイヤが変更された場合、描画を更新
        // 注意: 描画中の更新は避ける
        if !context.coordinator.isDrawing {
            if let activeLayer = document.activeLayer {
                if canvasView.drawing.dataRepresentation() != activeLayer.drawingData {
                    canvasView.drawing = activeLayer.drawing
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// ツールを更新
    private func updateTool(_ canvasView: PKCanvasView) {
        if isUsingEraser {
            canvasView.tool = brushSettings.createEraserTool()
        } else {
            canvasView.tool = brushSettings.createInkingTool()
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        var isDrawing = false

        init(_ parent: CanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChanged?(canvasView.drawing)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = false
            // 描画終了時に Undo 状態を保存
            parent.document.saveUndoState()
            parent.document.updateActiveLayerDrawing(canvasView.drawing)
        }
    }
}

// MARK: - Preview

#Preview {
    CanvasView(
        document: IllustrationDocument(),
        brushSettings: BrushSettings(),
        isUsingEraser: .constant(false)
    )
}
