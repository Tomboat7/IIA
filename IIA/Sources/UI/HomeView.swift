import SwiftUI

// MARK: - Future Improvements
// TODO: 大規模リファクタリング時にサブビューを別ファイルに分割（CanvasSizeSelectionSheet.swift, RecentDocumentsSheet.swift）
// Note: UI要素のサイズ（padding、corner radius等）はApple HIGに沿った標準値のため定数化せず維持

/// ホーム画面
/// 新規作成・続きから描く・インポート・エクスポートなどの起点
struct HomeView: View {
    // MARK: - Constants

    /// ホーム画面に表示する最近のドキュメント数
    private static let recentDocumentsDisplayCount = 5

    // MARK: - Properties

    @EnvironmentObject var documentManager: DocumentManager
    @State private var showCanvasSizeSheet = false
    @State private var selectedDocument: IllustrationDocument?
    @State private var navigateToCanvas = false
    @State private var showRecentDocuments = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // アプリタイトル
                Text("IIA")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.top, 40)

                Text("iPad Illustration App")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // メインアクションボタン
                VStack(spacing: 16) {
                    HomeActionButton(
                        title: "新規作成",
                        systemImage: "plus.square",
                        color: .accentColor
                    ) {
                        showCanvasSizeSheet = true
                    }

                    HomeActionButton(
                        title: "続きから描く",
                        systemImage: "clock.arrow.circlepath",
                        color: .green
                    ) {
                        showRecentDocuments = true
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // 最近のドキュメント
                if !documentManager.recentDocuments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近の作品")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(documentManager.recentDocuments.prefix(Self.recentDocumentsDisplayCount)) { doc in
                                    RecentDocumentCard(document: doc) {
                                        selectedDocument = doc
                                        navigateToCanvas = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $navigateToCanvas) {
                if let document = selectedDocument {
                    CanvasScreen(document: document)
                }
            }
            .sheet(isPresented: $showCanvasSizeSheet) {
                CanvasSizeSelectionSheet(
                    onSelect: { size in
                        let newDoc = IllustrationDocument(canvasSize: size)
                        documentManager.addDocument(newDoc)
                        selectedDocument = newDoc
                        showCanvasSizeSheet = false
                        navigateToCanvas = true
                    }
                )
            }
            .sheet(isPresented: $showRecentDocuments) {
                RecentDocumentsSheet(
                    documents: documentManager.recentDocuments,
                    onSelect: { doc in
                        selectedDocument = doc
                        showRecentDocuments = false
                        navigateToCanvas = true
                    },
                    onDelete: { doc in
                        documentManager.deleteDocument(doc)
                    }
                )
            }
        }
    }
}

/// ホーム画面のアクションボタン
struct HomeActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
            )
        }
    }
}

/// 最近のドキュメントカード
struct RecentDocumentCard: View {
    let document: IllustrationDocument
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // サムネイル
                DocumentThumbnail(document: document)
                    .frame(width: 120, height: 120)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)

                // ドキュメント名
                Text(document.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                // 更新日時
                Text(document.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// ドキュメントサムネイル
struct DocumentThumbnail: View {
    let document: IllustrationDocument
    @EnvironmentObject var documentManager: DocumentManager

    var body: some View {
        if let thumbnail = documentManager.generateThumbnail(for: document) {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // サムネイル生成に失敗した場合は背景色のみ表示
            Rectangle()
                .fill(document.backgroundColor)
        }
    }
}

/// キャンバスサイズ選択シート
struct CanvasSizeSelectionSheet: View {
    let onSelect: (CGSize) -> Void
    @Environment(\.dismiss) private var dismiss

    // プリセットサイズ
    private let presets: [(name: String, size: CGSize)] = [
        ("正方形 (2048x2048)", CGSize(width: 2048, height: 2048)),
        ("A4 縦 (2480x3508)", CGSize(width: 2480, height: 3508)),
        ("A4 横 (3508x2480)", CGSize(width: 3508, height: 2480)),
        ("16:9 横 (1920x1080)", CGSize(width: 1920, height: 1080)),
        ("16:9 縦 (1080x1920)", CGSize(width: 1080, height: 1920)),
        ("4:3 横 (2048x1536)", CGSize(width: 2048, height: 1536)),
        ("iPad 画面 (2732x2048)", CGSize(width: 2732, height: 2048)),
    ]

    @State private var customWidth: String = "2048"
    @State private var customHeight: String = "2048"

    var body: some View {
        NavigationStack {
            List {
                Section("プリセット") {
                    ForEach(presets, id: \.name) { preset in
                        Button(action: {
                            onSelect(preset.size)
                        }) {
                            HStack {
                                Text(preset.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(Int(preset.size.width)) x \(Int(preset.size.height))")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section("カスタムサイズ") {
                    HStack {
                        TextField("幅", text: $customWidth)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)

                        Text("x")

                        TextField("高さ", text: $customHeight)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)

                        Text("px")
                            .foregroundColor(.secondary)
                    }

                    Button("作成") {
                        if let width = Double(customWidth),
                           let height = Double(customHeight),
                           width > 0 && height > 0 {
                            onSelect(CGSize(width: width, height: height))
                        }
                    }
                    .disabled(
                        (Double(customWidth) ?? 0) <= 0 ||
                        (Double(customHeight) ?? 0) <= 0
                    )
                }
            }
            .navigationTitle("キャンバスサイズ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 最近のドキュメント一覧シート
struct RecentDocumentsSheet: View {
    let documents: [IllustrationDocument]
    let onSelect: (IllustrationDocument) -> Void
    let onDelete: (IllustrationDocument) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if documents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("ドキュメントがありません")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(documents) { doc in
                        Button(action: { onSelect(doc) }) {
                            HStack(spacing: 12) {
                                DocumentThumbnail(document: doc)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(doc.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("\(Int(doc.canvasSize.width)) x \(Int(doc.canvasSize.height))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Text(doc.updatedAt.formatted())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(doc)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("最近の作品")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(DocumentManager())
}
