import Foundation

final class SecurityScopedBookmarkStore {
    static let shared = SecurityScopedBookmarkStore()

    private let defaults = UserDefaults.standard
    private let bookmarksKey = "securityScopedBookmarks"
    private let queue = DispatchQueue(label: "SecurityScopedBookmarkStore")

    private init() {}

    func saveBookmark(for url: URL) {
        queue.sync {
            do {
                let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                var bookmarks = loadBookmarks()
                bookmarks[url.path] = data
                defaults.set(bookmarks, forKey: bookmarksKey)
            } catch {
                print("Failed to save security scoped bookmark: \(error)")
            }
        }
    }

    func resolveURL(forPath path: String) -> URL? {
        queue.sync {
            let bookmarks = loadBookmarks()
            if let exact = bookmarks[path] {
                return resolveURL(from: exact, forPath: path)
            }

            let bestKey = bookmarks.keys
                .filter { path.hasPrefix($0) }
                .sorted { $0.count > $1.count }
                .first

            guard let key = bestKey, let data = bookmarks[key] else { return nil }
            return resolveURL(from: data, forPath: key)
        }
    }

    private func loadBookmarks() -> [String: Data] {
        guard let raw = defaults.dictionary(forKey: bookmarksKey) else { return [:] }
        var result: [String: Data] = [:]
        for (key, value) in raw {
            if let data = value as? Data {
                result[key] = data
            }
        }
        return result
    }

    private func resolveURL(from data: Data, forPath path: String) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                saveBookmark(for: url)
            }

            return url
        } catch {
            print("Failed to resolve security scoped bookmark: \(error)")
            return nil
        }
    }
}
