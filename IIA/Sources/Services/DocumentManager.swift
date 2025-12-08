import Foundation
import SwiftUI

/// ドキュメントの保存・読み込み・管理を行うクラス
class DocumentManager: NSObject, ObservableObject {
    @Published var recentDocuments: [IllustrationDocument] = []

    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private var saveToPhotoLibraryCompletion: ((Bool, Error?) -> Void)?
    
    // サムネイルキャッシュ
    private var thumbnailCache: [UUID: UIImage] = [:]
    private let thumbnailSize = CGSize(width: 120, height: 120)

    override init() {
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
    
    enum ExportFormat {
        case png
        case jpeg(quality: CGFloat)
    }

    /// ドキュメントを画像として書き出し
    func exportAsImage(document: IllustrationDocument, format: ExportFormat, includeBackground: Bool = true) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: document.canvasSize)

        let image = renderer.image { context in
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
        
        // フォーマットに応じてデータを生成
        switch format {
        case .png:
            return image.pngData()
        case .jpeg(let quality):
            return image.jpegData(compressionQuality: quality)
        }
    }
    
    /// ドキュメントを UIImage として書き出し（共有用）
    func exportAsUIImage(document: IllustrationDocument, includeBackground: Bool = true) -> UIImage? {
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
        saveToPhotoLibraryCompletion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            saveToPhotoLibraryCompletion?(false, error)
        } else {
            saveToPhotoLibraryCompletion?(true, nil)
        }
        saveToPhotoLibraryCompletion = nil
    }
    
    // MARK: - Thumbnail
    
    /// ドキュメントのサムネイルを生成（キャッシュあり）
    func generateThumbnail(for document: IllustrationDocument) -> UIImage? {
        // キャッシュをチェック
        if let cached = thumbnailCache[document.id] {
            return cached
        }
        
        // サムネイルを生成
        let scale = min(
            thumbnailSize.width / document.canvasSize.width,
            thumbnailSize.height / document.canvasSize.height
        )
        let size = CGSize(
            width: document.canvasSize.width * scale,
            height: document.canvasSize.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { context in
            // 背景色
            UIColor(document.backgroundColor).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 各レイヤを描画
            for layer in document.layers where layer.isVisible {
                let drawing = layer.drawing
                let layerImage = drawing.image(
                    from: CGRect(origin: .zero, size: document.canvasSize),
                    scale: scale
                )
                layerImage.draw(
                    in: CGRect(origin: .zero, size: size),
                    blendMode: .normal,
                    alpha: CGFloat(layer.opacity)
                )
            }
        }
        
        // キャッシュに保存
        thumbnailCache[document.id] = thumbnail
        return thumbnail
    }
    
    /// サムネイルキャッシュを無効化
    func invalidateThumbnail(for documentId: UUID) {
        thumbnailCache.removeValue(forKey: documentId)
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
