import Foundation
import SwiftUI

// MARK: - Future Improvements
// TODO: テストコードの追加 - 保存/読み込み機能、サムネイル生成のユニットテスト
// TODO: 大規模リファクタリング時にファイル分割を検討（Export機能、Thumbnail機能を別クラスに）
// Note: print文によるログ出力は個人利用アプリのため許容。将来的にはos.logへの移行を検討

/// ドキュメントの保存・読み込み・管理を行うクラス
class DocumentManager: NSObject, ObservableObject {
    @Published var recentDocuments: [IllustrationDocument] = []

    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    /// 写真ライブラリ保存時のコールバック（@objcメソッドで使用するため保持）
    /// Note: UIImageWriteToSavedPhotosAlbumのコールバックがselfを参照するため、
    /// 完了時にnilにセットすることでメモリリークを防止
    private var saveToPhotoLibraryCompletion: ((Bool, Error?) -> Void)?

    // MARK: - Constants

    /// サムネイルキャッシュ (NSCache で自動的にメモリ管理)
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private static let thumbnailWidth: CGFloat = 120
    private static let thumbnailHeight: CGFloat = 120
    /// 最近のドキュメント最大保持数
    private static let maxRecentDocuments = 50

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

    /// ドキュメントを更新日時順にソートし、上限を超えたドキュメントを削除
    private func sortDocuments() {
        recentDocuments.sort { $0.updatedAt > $1.updatedAt }

        // 上限を超えた古いドキュメントを削除
        if recentDocuments.count > Self.maxRecentDocuments {
            let documentsToRemove = recentDocuments[Self.maxRecentDocuments...]
            for doc in documentsToRemove {
                let fileURL = documentURL(for: doc.id)
                try? fileManager.removeItem(at: fileURL)
            }
            recentDocuments = Array(recentDocuments.prefix(Self.maxRecentDocuments))
        }
    }

    // MARK: - Export

    enum ExportFormat {
        case png
        case jpeg(quality: CGFloat)
    }

    /// ドキュメントを画像としてレンダリング（共通処理）
    private func renderDocument(_ document: IllustrationDocument, includeBackground: Bool, scale: CGFloat = 1.0) -> UIImage {
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
                    scale: scale
                )
                layerImage.draw(
                    in: CGRect(origin: .zero, size: document.canvasSize),
                    blendMode: .normal,
                    alpha: CGFloat(layer.opacity)
                )
            }
        }
    }

    /// ドキュメントを画像として書き出し
    func exportAsImage(document: IllustrationDocument, format: ExportFormat, includeBackground: Bool = true) -> Data? {
        let image = renderDocument(document, includeBackground: includeBackground)

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
        return renderDocument(document, includeBackground: includeBackground)
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
        let cacheKey = document.id.uuidString as NSString

        // キャッシュをチェック
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        // サムネイルを生成
        let scale = min(
            Self.thumbnailWidth / document.canvasSize.width,
            Self.thumbnailHeight / document.canvasSize.height
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
        thumbnailCache.setObject(thumbnail, forKey: cacheKey)
        return thumbnail
    }
    
    /// サムネイルキャッシュを無効化
    func invalidateThumbnail(for documentId: UUID) {
        thumbnailCache.removeObject(forKey: documentId.uuidString as NSString)
    }
}
