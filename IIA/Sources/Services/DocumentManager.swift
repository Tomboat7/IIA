import Foundation
import SwiftUI

/// ドキュメントの保存・読み込み・管理を行うクラス
class DocumentManager: ObservableObject {
    @Published var recentDocuments: [IllustrationDocument] = []

    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    init() {
        // Documents ディレクトリを取得
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IIADocuments", isDirectory: true)

        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        }

        // 保存されているドキュメントを読み込み
        loadAllDocuments()
    }

    // MARK: - Document Management

    /// 新しいドキュメントを追加
    func addDocument(_ document: IllustrationDocument) {
        // 既存の同じIDのドキュメントを削除
        recentDocuments.removeAll { $0.id == document.id }

        // 先頭に追加
        recentDocuments.insert(document, at: 0)

        // 保存
        saveDocument(document)
    }

    /// ドキュメントを保存
    func saveDocument(_ document: IllustrationDocument) {
        let fileURL = documentURL(for: document.id)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)

            // recentDocuments を更新
            if let index = recentDocuments.firstIndex(where: { $0.id == document.id }) {
                recentDocuments[index] = document
            } else {
                recentDocuments.insert(document, at: 0)
            }

            // 更新日時順にソート
            sortDocuments()

            print("Document saved: \(document.name)")
        } catch {
            print("Failed to save document: \(error)")
        }
    }

    /// ドキュメントを読み込み
    func loadDocument(id: UUID) -> IllustrationDocument? {
        let fileURL = documentURL(for: id)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(IllustrationDocument.self, from: data)
            return document
        } catch {
            print("Failed to load document: \(error)")
            return nil
        }
    }

    /// ドキュメントを削除
    func deleteDocument(_ document: IllustrationDocument) {
        let fileURL = documentURL(for: document.id)

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            recentDocuments.removeAll { $0.id == document.id }
            print("Document deleted: \(document.name)")
        } catch {
            print("Failed to delete document: \(error)")
        }
    }

    /// 全てのドキュメントを読み込み
    func loadAllDocuments() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            var documents: [IllustrationDocument] = []

            for fileURL in fileURLs where fileURL.pathExtension == "iia" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let document = try decoder.decode(IllustrationDocument.self, from: data)
                    documents.append(document)
                } catch {
                    print("Failed to load document at \(fileURL): \(error)")
                }
            }

            recentDocuments = documents
            sortDocuments()

        } catch {
            print("Failed to enumerate documents: \(error)")
        }
    }

    // MARK: - Private Methods

    /// ドキュメントの保存先 URL を取得
    private func documentURL(for id: UUID) -> URL {
        documentsDirectory.appendingPathComponent("\(id.uuidString).iia")
    }

    /// ドキュメントを更新日時順にソート
    private func sortDocuments() {
        recentDocuments.sort { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Export

    /// ドキュメントを PNG 画像として書き出し
    func exportAsPNG(document: IllustrationDocument, includeBackground: Bool = true) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: document.canvasSize)

        return renderer.image { context in
            // 背景
            if includeBackground {
                UIColor(document.backgroundColor).setFill()
                context.fill(CGRect(origin: .zero, size: document.canvasSize))
            }

            // 各レイヤを描画
            for layer in document.layers where layer.isVisible {
                let drawing = layer.drawing
                let layerImage = drawing.image(
                    from: CGRect(origin: .zero, size: document.canvasSize),
                    scale: 1.0
                )
                layerImage.draw(
                    in: CGRect(origin: .zero, size: document.canvasSize),
                    blendMode: .normal,
                    alpha: CGFloat(layer.opacity)
                )
            }
        }
    }

    /// 画像を写真ライブラリに保存
    func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        // 注: 実際のアプリでは、保存完了を確認するためのセレクタを使用する
        completion(true, nil)
    }
}

// MARK: - Thumbnail Generation

extension DocumentManager {
    /// サムネイルを生成
    func generateThumbnail(for document: IllustrationDocument, size: CGSize) -> UIImage? {
        let scale = min(
            size.width / document.canvasSize.width,
            size.height / document.canvasSize.height
        )
        let thumbnailSize = CGSize(
            width: document.canvasSize.width * scale,
            height: document.canvasSize.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)

        return renderer.image { context in
            // 背景
            UIColor(document.backgroundColor).setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))

            // 各レイヤを描画
            for layer in document.layers where layer.isVisible {
                let drawing = layer.drawing
                if !drawing.bounds.isEmpty {
                    let layerImage = drawing.image(
                        from: CGRect(origin: .zero, size: document.canvasSize),
                        scale: scale
                    )
                    layerImage.draw(
                        in: CGRect(origin: .zero, size: thumbnailSize),
                        blendMode: .normal,
                        alpha: CGFloat(layer.opacity)
                    )
                }
            }
        }
    }
}
