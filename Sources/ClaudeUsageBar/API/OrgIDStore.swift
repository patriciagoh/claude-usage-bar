import Foundation

enum OrgIDStore {
    private static let idKey  = "com.patriciagoh.ClaudeUsageBar.orgID"
    private static let tsKey  = "com.patriciagoh.ClaudeUsageBar.orgID.savedAt"
    private static let ttl: TimeInterval = 24 * 60 * 60  // 24 hours

    static var orgID: String? {
        get {
            guard let savedAt = UserDefaults.standard.object(forKey: tsKey) as? Date,
                  Date().timeIntervalSince(savedAt) < ttl,
                  let id = UserDefaults.standard.string(forKey: idKey),
                  !id.isEmpty
            else {
                invalidate()
                return nil
            }
            return id
        }
        set {
            if let id = newValue, !id.isEmpty {
                UserDefaults.standard.set(id, forKey: idKey)
                UserDefaults.standard.set(Date(), forKey: tsKey)
            } else {
                invalidate()
            }
        }
    }

    static func invalidate() {
        UserDefaults.standard.removeObject(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: tsKey)
    }
}
