import Foundation

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func appendingPathComponentIfExists(_ component: String) -> URL? {
        let url = appendingPathComponent(component)
        return url.exists ? url : nil
    }

    var parentDirectory: URL {
        deletingLastPathComponent()
    }

    var fileName: String {
        lastPathComponent
    }

    var fileExtensionLower: String {
        pathExtension.lowercased()
    }
}

extension FileManager {
    func directoryContents(at url: URL) -> [URL] {
        (try? contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
    }

    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
