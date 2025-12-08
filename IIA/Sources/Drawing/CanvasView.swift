import SwiftUI
import PencilKit

/// PencilKit の PKCanvasView を SwiftUI でラップしたビュー
struct CanvasView: UIViewRepresentable {
    // MARK: - Constants

    /// 最小ズームスケール
    private static let minZoomScale: CGFloat = 0.5
    /// 最大ズームスケール
    private static let maxZoomScale: CGFloat = 5.0
    /// 描画変更のデバウンス遅延（秒）
    private static let drawingDebounceDelay: TimeInterval = 0.1

    // MARK: - Properties

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
        canvasView.minimumZoomScale = Self.minZoomScale
        canvasView.maximumZoomScale = Self.maxZoomScale
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
        // バージョン比較でパフォーマンスを改善
        if !context.coordinator.isDrawing {
            if let activeLayer = document.activeLayer {
                if context.coordinator.lastLayerVersion != activeLayer.version {
                    canvasView.drawing = activeLayer.drawing
                    context.coordinator.lastLayerVersion = activeLayer.version
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
        var lastLayerVersion: Int = -1
        private var drawingChangedWorkItem: DispatchWorkItem?

        init(_ parent: CanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Debounce the onDrawingChanged callback to avoid excessive updates
            drawingChangedWorkItem?.cancel()
            let drawing = canvasView.drawing
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.parent.onDrawingChanged?(drawing)
            }
            drawingChangedWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + CanvasView.drawingDebounceDelay, execute: workItem)
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isDrawing = false
            // 描画終了時に Undo 状態を保存
            parent.document.saveUndoState()
            parent.document.updateActiveLayerDrawing(canvasView.drawing)
            
            // バージョンを更新
            if let activeLayer = parent.document.activeLayer {
                lastLayerVersion = activeLayer.version
            }
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
