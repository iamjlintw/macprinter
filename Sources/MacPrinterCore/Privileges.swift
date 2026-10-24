import Foundation

/// 後端以 root 執行；寫進使用者資料夾時暫時降成該帳號的權限，
/// 避免使用者在自己的資料夾放 symlink，誘使 root 寫到系統檔案。
public protocol PrivilegeScope {
    /// 資料夾要交給哪個帳號；nil 表示不改擁有者（非 root 執行，例如測試）。
    var owner: (uid: uid_t, gid: gid_t)? { get }
    func asUser<T>(_ body: () throws -> T) throws -> T
}

public struct PrivilegeError: Error, CustomStringConvertible {
    public let description: String
}

/// 不切換身分，給測試與非 root 執行用。
public struct CurrentUserScope: PrivilegeScope {
    public init() {}
    public var owner: (uid: uid_t, gid: gid_t)? { nil }
    public func asUser<T>(_ body: () throws -> T) throws -> T { try body() }
}

/// root 執行時以 setegid／seteuid 暫時切換成送件帳號。
public struct DroppedUserScope: PrivilegeScope {
    public let uid: uid_t
    public let gid: gid_t

    public init(uid: uid_t, gid: gid_t) {
        self.uid = uid
        self.gid = gid
    }

    public var owner: (uid: uid_t, gid: gid_t)? { (uid, gid) }

    public func asUser<T>(_ body: () throws -> T) throws -> T {
        guard setegid(gid) == 0 else { throw PrivilegeError(description: "setegid 失敗：\(String(cString: strerror(errno)))") }
        guard seteuid(uid) == 0 else {
            _ = setegid(0)
            throw PrivilegeError(description: "seteuid 失敗：\(String(cString: strerror(errno)))")
        }
        defer {
            _ = seteuid(0)
            _ = setegid(0)
        }
        return try body()
    }
}
