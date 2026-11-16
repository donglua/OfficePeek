import Foundation
import AppKit
import JZOffice

/// 最近打开的 Office 文档记录项
public struct RecentFileRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: String { path }
    public let path: String
    public var displayName: String
    public var format: OfficeKind
    public var pageCount: Int
    public var sheetNames: [String]
    public var fileSizeBytes: Int64
    public var lastOpenedAt: Date
    public var isPinned: Bool

    public var fileURL: URL {
        URL(fileURLWithPath: path)
    }

    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    public var pageSummary: String {
        switch format {
        case .docx:
            return "连续流式文档"
        case .pptx:
            return "\(pageCount) 张幻灯片"
        case .xlsx:
            return "\(pageCount) 个工作表"
        }
    }

    public init(
        path: String,
        displayName: String,
        format: OfficeKind,
        pageCount: Int,
        sheetNames: [String],
        fileSizeBytes: Int64,
        lastOpenedAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.path = path
        self.displayName = displayName
        self.format = format
        self.pageCount = pageCount
        self.sheetNames = sheetNames
        self.fileSizeBytes = fileSizeBytes
        self.lastOpenedAt = lastOpenedAt
        self.isPinned = isPinned
    }
}

/// 最近打开文档管理器（支持 JSON 持久化、格式过滤、搜索及异步缩略图生成）
@MainActor
public final class RecentFilesStore: ObservableObject {
    @Published public private(set) var records: [RecentFileRecord] = []
    @Published public private(set) var thumbnails: [String: NSImage] = [:]
    @Published public var searchQuery: String = ""
    @Published public var selectedFormatFilter: OfficeKind? = nil

    private let storageURL: URL
    private let maxRecords: Int

    public init(storageURL: URL? = nil, maxRecords: Int = 40) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = appSupport.appendingPathComponent("OfficePeek", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("recent_files.json")
        }
        self.maxRecords = maxRecords
        loadFromDisk()
    }

    public var filteredRecords: [RecentFileRecord] {
        records
            .filter { record in
                if let filter = selectedFormatFilter, record.format != filter {
                    return false
                }
                let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty {
                    return record.displayName.localizedCaseInsensitiveContains(q)
                        || record.path.localizedCaseInsensitiveContains(q)
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.lastOpenedAt > rhs.lastOpenedAt
            }
    }

    /// 登记自定义记录项并持久化
    public func register(record: RecentFileRecord) {
        upsert(record)
        saveToDisk()
    }

    /// 同步登记打开的文档并提取元数据（便于测试与即时刷新）
    @discardableResult
    public func recordOpenedSync(url: URL, now: Date = Date()) throws -> RecentFileRecord {
        let stdURL = url.standardizedFileURL
        let meta = try OfficeMetadata.read(from: stdURL)
        return commitOpenedRecord(url: stdURL, meta: meta, size: Self.fileSize(atPath: stdURL.path), now: now)
    }

    /// 异步读取轻量元数据并登记打开的文档，同时生成或刷新首页缩略图
    @discardableResult
    public func recordOpened(url: URL, now: Date = Date()) async -> RecentFileRecord? {
        let stdURL = url.standardizedFileURL
        guard let meta = try? await OfficeMetadata.readAsync(from: stdURL) else { return nil }
        let size = Self.fileSize(atPath: stdURL.path)
        let item = commitOpenedRecord(url: stdURL, meta: meta, size: size, now: now)
        await loadThumbnailIfNeeded(for: item, forceRefresh: true)
        return item
    }

    /// 批量预热当前列表中所有记录的缩略图
    public func refreshThumbnails() {
        for item in records {
            Task {
                await loadThumbnailIfNeeded(for: item)
            }
        }
    }

    public func loadThumbnailIfNeeded(for record: RecentFileRecord, forceRefresh: Bool = false) async {
        if !forceRefresh && thumbnails[record.id] != nil { return }
        guard FileManager.default.fileExists(atPath: record.path) else { return }
        if let image = try? await OfficeThumbnail.renderAsync(
            from: record.fileURL,
            maxSize: CGSize(width: 360, height: 260)
        ) {
            thumbnails[record.id] = image
        }
    }

    private func commitOpenedRecord(
        url stdURL: URL,
        meta: OfficeMetadata,
        size: Int64,
        now: Date
    ) -> RecentFileRecord {
        let path = stdURL.path
        let existingPin = records.first(where: { $0.path == path })?.isPinned ?? false
        let item = RecentFileRecord(
            path: path,
            displayName: stdURL.lastPathComponent,
            format: meta.format,
            pageCount: meta.pageCount,
            sheetNames: meta.sheetNames,
            fileSizeBytes: size,
            lastOpenedAt: now,
            isPinned: existingPin
        )
        upsert(item)
        saveToDisk()
        return item
    }

    private static func fileSize(atPath path: String) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    public func togglePin(for id: String) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].isPinned.toggle()
        saveToDisk()
    }

    public func remove(id: String) {
        records.removeAll { $0.id == id }
        thumbnails.removeValue(forKey: id)
        saveToDisk()
    }

    public func pruneMissingFiles() {
        records.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
        saveToDisk()
    }

    private func upsert(_ item: RecentFileRecord) {
        records.removeAll { $0.path == item.path }
        records.insert(item, at: 0)
        if records.count > maxRecords {
            let pinned = records.filter(\.isPinned)
            let unpinned = records.filter { !$0.isPinned }
            records = Array((pinned + unpinned).prefix(maxRecords))
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([RecentFileRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
