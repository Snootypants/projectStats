import SwiftData
import os.log

extension ModelContext {
    /// Save with error logging instead of silent failure.
    /// Use this instead of `try? context.save()` to avoid swallowing errors.
    func safeSave(caller: String = #function) {
        do {
            try save()
        } catch {
            Log.data.error("[SafeSave] Save failed in \(caller): \(error)")
        }
    }
}
