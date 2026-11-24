import Foundation
import AppKit
import CoreGraphics
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
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
            switch fileURL.pathExtension.lowercased() {
            case "csv":
                return "CSV 数据表"
            case "tsv":
                return "TSV 数据表"
            default:
                return "\(pageCount) 个工作表"
            }
        }
    }

    /// 相对于给定参考时间的简短打开时间文案
    public func relativeLastOpenedText(relativeTo referenceDate: Date = Date()) -> String {
        let elapsed = max(0, referenceDate.timeIntervalSince(lastOpenedAt))
        if elapsed < 60 {
            return "刚刚"
        }
        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return "\(minutes) 分钟前"
        }
        let hours = Int(elapsed / 3600)
        if hours < 24 {
            return "\(hours) 小时前"
        }
        let calendar = Calendar.current
        let refDay = calendar.startOfDay(for: referenceDate)
        let targetDay = calendar.startOfDay(for: lastOpenedAt)
        if let dayDiff = calendar.dateComponents([.day], from: targetDay, to: refDay).day, dayDiff == 1 {
            return "昨天"
        }
        let days = Int(elapsed / 86_400)
        if days < 7 {
            return "\(days) 天前"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = calendar.isDate(lastOpenedAt, equalTo: referenceDate, toGranularity: .year)
            ? "M月d日"
            : "yyyy/M/d"
        return formatter.string(from: lastOpenedAt)
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

/// 限制封面缩略图同时离屏渲染的并发数量，避免启动时抢占主预览或打满线程池
private actor ThumbnailRenderGate {
    private let limit: Int
    private var activeCount: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int = 3) {
        self.limit = max(1, limit)
    }

    func withPermit<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        if activeCount < limit {
            activeCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
        } else {
            activeCount = max(0, activeCount - 1)
        }
    }
}

/// 最近打开文档管理器（支持 JSON 持久化、磁盘缩略图缓存、格式过滤、搜索及并发受控异步缩略图生成）
@MainActor
public final class RecentFilesStore: ObservableObject {
    @Published public private(set) var records: [RecentFileRecord] = [] {
        didSet {
            recomputeCounts()
            recomputeFilteredRecords()
        }
    }
    @Published public private(set) var filteredRecords: [RecentFileRecord] = []
    public var pinnedFilteredRecords: [RecentFileRecord] {
        filteredRecords.filter(\.isPinned)
    }
    public var unpinnedFilteredRecords: [RecentFileRecord] {
        filteredRecords.filter { !$0.isPinned }
    }
    @Published public private(set) var docxCount: Int = 0
    @Published public private(set) var pptxCount: Int = 0
    @Published public private(set) var xlsxCount: Int = 0
    @Published public private(set) var thumbnails: [String: NSImage] = [:]
    @Published public var searchQuery: String = "" {
        didSet {
            recomputeFilteredRecords()
        }
    }
    @Published public var selectedFormatFilter: OfficeKind? = nil {
        didSet {
            recomputeFilteredRecords()
        }
    }

    private let storageURL: URL
    public let thumbnailCacheDirectory: URL
    private let maxRecords: Int
    private let renderGate = ThumbnailRenderGate(limit: 3)
    private var thumbnailTasks: [String: (token: UUID, task: Task<Void, Never>)] = [:]
    private var cacheURLByRecordID: [String: URL] = [:]

    public init(
        storageURL: URL? = nil,
        thumbnailCacheDirectory: URL? = nil,
        maxRecords: Int = 40
    ) {
        if let storageURL {
            self.storageURL = storageURL
            self.thumbnailCacheDirectory = thumbnailCacheDirectory
                ?? storageURL.deletingLastPathComponent().appendingPathComponent("thumbnails", isDirectory: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = appSupport.appendingPathComponent("OfficePeek", isDirectory: true)
            self.storageURL = dir.appendingPathComponent("recent_files.json")

            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.thumbnailCacheDirectory = thumbnailCacheDirectory
                ?? caches.appendingPathComponent("OfficePeek/Thumbnails", isDirectory: true)
        }
        self.maxRecords = maxRecords
        loadFromDisk()
    }

    private func recomputeCounts() {
        var docx = 0
        var pptx = 0
        var xlsx = 0
        for record in records {
            switch record.format {
            case .docx: docx += 1
            case .pptx: pptx += 1
            case .xlsx: xlsx += 1
            }
        }
        docxCount = docx
        pptxCount = pptx
        xlsxCount = xlsx
    }

    private func recomputeFilteredRecords() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter = selectedFormatFilter
        filteredRecords = records
            .filter { record in
                if let filter, record.format != filter {
                    return false
                }
                if !query.isEmpty {
                    return record.displayName.localizedCaseInsensitiveContains(query)
                        || record.path.localizedCaseInsensitiveContains(query)
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

    /// 批量预热当前列表中所有记录的缩略图（受并发上限与磁盘缓存约束）
    public func refreshThumbnails() {
        for item in records {
            Task(priority: .utility) { [weak self] in
                await self?.loadThumbnailIfNeeded(for: item)
            }
        }
    }

    public func loadThumbnailIfNeeded(for record: RecentFileRecord, forceRefresh: Bool = false) async {
        if !forceRefresh && thumbnails[record.id] != nil {
            return
        }
        if !forceRefresh, let existing = thumbnailTasks[record.id] {
            await existing.task.value
            return
        }
        if forceRefresh, let existing = thumbnailTasks[record.id] {
            existing.task.cancel()
            thumbnailTasks.removeValue(forKey: record.id)
        }

        let token = UUID()
        let recordID = record.id
        let fileURL = record.fileURL
        let cacheDir = thumbnailCacheDirectory
        let gate = renderGate
        let previousCacheURL = cacheURLByRecordID[recordID]

        let task = Task { [weak self] in
            defer {
                if let self, self.thumbnailTasks[recordID]?.token == token {
                    self.thumbnailTasks.removeValue(forKey: recordID)
                }
            }

            let loaded = await Self.loadOrRenderThumbnail(
                fileURL: fileURL,
                cacheDirectory: cacheDir,
                forceRefresh: forceRefresh,
                previousCacheURL: previousCacheURL,
                renderGate: gate
            )
            guard !Task.isCancelled, let self, let loaded else { return }

            self.cacheURLByRecordID[recordID] = loaded.cacheURL
            self.thumbnails[recordID] = NSImage(
                cgImage: loaded.cgImage,
                size: NSSize(width: loaded.cgImage.width, height: loaded.cgImage.height)
            )
        }

        thumbnailTasks[recordID] = (token: token, task: task)
        await task.value
    }

    private struct LoadedThumbnail: Sendable {
        let cgImage: CGImage
        let cacheURL: URL
    }

    private nonisolated static func loadOrRenderThumbnail(
        fileURL: URL,
        cacheDirectory: URL,
        forceRefresh: Bool,
        previousCacheURL: URL?,
        renderGate: ThumbnailRenderGate
    ) async -> LoadedThumbnail? {
        await Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return nil }
            let path = fileURL.path
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
                return nil
            }
            let fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let modDate = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let cacheURL = thumbnailCacheFileURL(
                forPath: path,
                fileSize: fileSize,
                modificationTimestamp: modDate,
                in: cacheDirectory
            )

            if !forceRefresh, let cached = readCachedCGImage(at: cacheURL) {
                return LoadedThumbnail(cgImage: cached, cacheURL: cacheURL)
            }

            let rendered: CGImage? = try? await renderGate.withPermit {
                guard !Task.isCancelled else { return nil }
                return try OfficeThumbnail.renderCGImage(
                    from: fileURL,
                    maxSize: CGSize(width: 360, height: 260)
                )
            }
            guard !Task.isCancelled, let cgImage = rendered else {
                return nil
            }

            if let previousCacheURL, previousCacheURL != cacheURL {
                try? FileManager.default.removeItem(at: previousCacheURL)
            }
            writeCachedCGImage(cgImage, to: cacheURL)
            return LoadedThumbnail(cgImage: cgImage, cacheURL: cacheURL)
        }.value
    }

    private nonisolated static func thumbnailCacheFileURL(
        forPath path: String,
        fileSize: Int64,
        modificationTimestamp: TimeInterval,
        in directory: URL
    ) -> URL {
        let mtimeNanos = Int64((modificationTimestamp * 1_000_000_000).rounded())
        let key = "\(path)|\(fileSize)|\(mtimeNanos)"
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(hex).png")
    }

    private nonisolated static func readCachedCGImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private nonisolated static func writeCachedCGImage(_ image: CGImage, to url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tempURL = dir.appendingPathComponent("\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        guard let dest = CGImageDestinationCreateWithURL(
            tempURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tempURL)
            return
        }
        _ = try? FileManager.default.replaceItemAt(url, withItemAt: tempURL)
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
        thumbnailTasks[id]?.task.cancel()
        thumbnailTasks.removeValue(forKey: id)
        if let cacheURL = cacheURLByRecordID.removeValue(forKey: id) {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        records.removeAll { $0.id == id }
        thumbnails.removeValue(forKey: id)
        saveToDisk()
    }

    public func pruneMissingFiles() {
        let missingIDs = Set(
            records
                .filter { !FileManager.default.fileExists(atPath: $0.path) }
                .map(\.id)
        )
        guard !missingIDs.isEmpty else { return }
        for id in missingIDs {
            thumbnailTasks[id]?.task.cancel()
            thumbnailTasks.removeValue(forKey: id)
            thumbnails.removeValue(forKey: id)
            if let cacheURL = cacheURLByRecordID.removeValue(forKey: id) {
                try? FileManager.default.removeItem(at: cacheURL)
            }
        }
        records.removeAll { missingIDs.contains($0.id) }
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
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
