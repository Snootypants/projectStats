import Foundation
import SQLite3

struct SearchResult: Identifiable {
    var id: String { path }
    let path: String
    let score: Double
    let snippet: String
}

@MainActor
final class CodeVectorDB: ObservableObject {
    static let shared = CodeVectorDB()

    @Published var isIndexing = false
    @Published var indexedFileCount = 0

    private var db: OpaquePointer?
    private var memoryCache: [String: [Float]] = [:]
    private var chunkCache: [String: String] = [:]

    private init() {
        openDatabase()
        createTables()
        loadIntoMemory()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let dbPath = getDBPath()
        if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
            print("[VectorDB] Failed to open database at \(dbPath)")
        }
    }

    private func getDBPath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.calebbelshe.projectStats", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("vectordb.sqlite")
    }

    private func createTables() {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS embeddings (
            key TEXT PRIMARY KEY,
            file_path TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            embedding BLOB NOT NULL,
            chunk_text TEXT NOT NULL,
            file_hash TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_file_path ON embeddings(file_path);
        CREATE INDEX IF NOT EXISTS idx_file_hash ON embeddings(file_hash);
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createSQL, nil, nil, &errMsg) != SQLITE_OK {
            print("[VectorDB] Create table error: \(String(cString: errMsg!))")
            sqlite3_free(errMsg)
        }
    }

    private func loadIntoMemory() {
        memoryCache.removeAll()
        chunkCache.removeAll()

        let sql = "SELECT key, embedding, chunk_text FROM embeddings"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let key = String(cString: sqlite3_column_text(stmt, 0))
                if let blobPtr = sqlite3_column_blob(stmt, 1) {
                    let blobSize = Int(sqlite3_column_bytes(stmt, 1))
                    let floatCount = blobSize / MemoryLayout<Float>.size
                    let buffer = blobPtr.assumingMemoryBound(to: Float.self)
                    memoryCache[key] = Array(UnsafeBufferPointer(start: buffer, count: floatCount))
                }
                let chunk = String(cString: sqlite3_column_text(stmt, 2))
                chunkCache[key] = chunk
            }
        }
        sqlite3_finalize(stmt)
        indexedFileCount = memoryCache.count
    }

    // MARK: - Indexing

    func indexDirectory(_ directory: URL) async {
        isIndexing = true
        let files = findAllCodeFiles(in: directory)
        var processedCount = 0

        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let fileHash = content.hashValue.description

            // Skip if file hasn't changed
            if !needsReindex(filePath: file.path, hash: fileHash) {
                continue
            }

            // Remove old embeddings for this file
            deleteEmbeddings(forFile: file.path)

            let chunks = chunkCode(content, maxTokens: 500)
            for (index, chunk) in chunks.enumerated() {
                let embedding = await AIService.shared.embed(text: chunk)
                guard !embedding.isEmpty else { continue }

                let key = "\(file.path):\(index)"
                saveEmbedding(key: key, filePath: file.path, chunkIndex: index,
                              embedding: embedding, chunk: chunk, fileHash: fileHash)
                memoryCache[key] = embedding
                chunkCache[key] = chunk
            }
            processedCount += 1
        }

        indexedFileCount = memoryCache.count
        isIndexing = false
    }

    private func needsReindex(filePath: String, hash: String) -> Bool {
        let sql = "SELECT file_hash FROM embeddings WHERE file_path = ? LIMIT 1"
        var stmt: OpaquePointer?
        var needsReindex = true

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, filePath, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let existingHash = String(cString: sqlite3_column_text(stmt, 0))
                needsReindex = existingHash != hash
            }
        }
        sqlite3_finalize(stmt)
        return needsReindex
    }

    private func deleteEmbeddings(forFile filePath: String) {
        let sql = "DELETE FROM embeddings WHERE file_path = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, filePath, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Remove from memory cache too
        memoryCache = memoryCache.filter { !$0.key.hasPrefix(filePath + ":") }
        chunkCache = chunkCache.filter { !$0.key.hasPrefix(filePath + ":") }
    }

    private func saveEmbedding(key: String, filePath: String, chunkIndex: Int,
                               embedding: [Float], chunk: String, fileHash: String) {
        let sql = """
        INSERT OR REPLACE INTO embeddings (key, file_path, chunk_index, embedding, chunk_text, file_hash, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, key, -1, nil)
            sqlite3_bind_text(stmt, 2, filePath, -1, nil)
            sqlite3_bind_int(stmt, 3, Int32(chunkIndex))

            embedding.withUnsafeBufferPointer { buffer in
                sqlite3_bind_blob(stmt, 4, buffer.baseAddress, Int32(buffer.count * MemoryLayout<Float>.size), nil)
            }

            sqlite3_bind_text(stmt, 5, chunk, -1, nil)
            sqlite3_bind_text(stmt, 6, fileHash, -1, nil)
            sqlite3_bind_double(stmt, 7, Date().timeIntervalSince1970)

            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[VectorDB] Insert error")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Search

    func search(query: String, topK: Int = 5) async -> [SearchResult] {
        let queryEmbedding = await AIService.shared.embed(text: query)
        guard !queryEmbedding.isEmpty else { return [] }

        var results: [(String, Double)] = []

        for (key, embedding) in memoryCache {
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            results.append((key, similarity))
        }

        return results
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { key, score in
                SearchResult(path: key, score: score, snippet: chunkCache[key] ?? "")
            }
    }

    // MARK: - Maintenance

    func clearAllEmbeddings() {
        let sql = "DELETE FROM embeddings"
        var errMsg: UnsafeMutablePointer<CChar>?
        sqlite3_exec(db, sql, nil, nil, &errMsg)
        memoryCache.removeAll()
        chunkCache.removeAll()
        indexedFileCount = 0
    }

    func getStats() -> (fileCount: Int, chunkCount: Int, dbSize: Int64) {
        let files = Set(memoryCache.keys.compactMap { $0.components(separatedBy: ":").first })
        let dbPath = getDBPath()
        let size = (try? FileManager.default.attributesOfItem(atPath: dbPath.path)[.size] as? Int64) ?? 0
        return (files.count, memoryCache.count, size)
    }

    // MARK: - Helpers

    private func findAllCodeFiles(in directory: URL) -> [URL] {
        let allowed = ["swift", "ts", "tsx", "js", "jsx", "py", "go", "rs", "java", "kt", "cpp", "c", "h", "md"]
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        var files: [URL] = []
        while let file = enumerator?.nextObject() as? URL {
            if allowed.contains(file.pathExtension.lowercased()) {
                files.append(file)
            }
        }
        return files
    }

    private func chunkCode(_ content: String, maxTokens: Int) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var chunks: [String] = []
        var current: [String] = []
        var count = 0

        for line in lines {
            current.append(line)
            count += max(1, line.count / 4)
            if count >= maxTokens {
                chunks.append(current.joined(separator: "\n"))
                current = []
                count = 0
            }
        }

        if !current.isEmpty {
            chunks.append(current.joined(separator: "\n"))
        }

        return chunks
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var magA: Float = 0
        var magB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        guard magA > 0, magB > 0 else { return 0 }
        return Double(dot / (sqrt(magA) * sqrt(magB)))
    }
}
