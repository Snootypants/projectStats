import Foundation

struct SearchResult: Identifiable {
    var id: String { path }
    let path: String
    let score: Double
    let snippet: String
}

@MainActor
final class CodeVectorDB: ObservableObject {
    static let shared = CodeVectorDB()

    private(set) var embeddings: [String: [Float]] = [:]
    private var chunks: [String: String] = [:]

    private init() {}

    func indexDirectory(_ directory: URL) async {
        let files = findAllCodeFiles(in: directory)
        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let chunks = chunkCode(content, maxTokens: 500)
            for (index, chunk) in chunks.enumerated() {
                let embedding = await AIService.shared.embed(text: chunk)
                let key = "\(file.path):\(index)"
                embeddings[key] = embedding
                self.chunks[key] = chunk
            }
        }
    }

    func search(query: String, topK: Int = 5) async -> [SearchResult] {
        let queryEmbedding = await AIService.shared.embed(text: query)
        var results: [(String, Double)] = []

        for (key, embedding) in embeddings {
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            results.append((key, similarity))
        }

        return results
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { key, score in
                SearchResult(path: key, score: score, snippet: chunks[key] ?? "")
            }
    }

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
