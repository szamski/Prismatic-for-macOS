import Foundation

enum AppInfo {
    static let name = "Prismatic"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // Update these once the repository is published on GitHub.
    static let repoOwner = "szamski"
    static let repoName = "Prismatic-for-macOS"

    static var repositoryURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)")! }
    static var latestReleaseURL: URL { URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")! }
    static var latestReleaseAPI: URL { URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")! }
}

enum UpdateResult {
    case upToDate
    case updateAvailable(tag: String)
    case failed(String)
}

enum UpdateChecker {
    /// Checks the latest GitHub release and compares it to the running version.
    static func check() async -> UpdateResult {
        var request = URLRequest(url: AppInfo.latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let http = response as? HTTPURLResponse, http.statusCode == 200,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = json["tag_name"] as? String
            else { return .failed("No release information available.") }

            let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            return isNewer(latest, than: AppInfo.version) ? .updateAvailable(tag: tag) : .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Simple dotted-number version comparison (e.g. "1.2.0" vs "1.1.5").
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
