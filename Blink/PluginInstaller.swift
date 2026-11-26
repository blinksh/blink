import Foundation

/// GitHub is a transport, not a different plugin format. No git, shell, or build hooks.
struct GitHubPluginSource {
  let owner: String
  let repository: String
  let ref: String?
  let path: String
  var repositoryURL: String { "https://github.com/\(owner)/\(repository)" }

  init(_ input: String) throws {
    guard let url = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
          url.scheme == "https", url.host?.lowercased() == "github.com", url.port == nil,
          url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
      throw PluginPackage.Failure.invalid("Use an HTTPS github.com repository or tree link.")
    }
    let parts = url.path.split(separator: "/").map(String.init)
    guard parts.count == 2 || (parts.count >= 4 && parts[2] == "tree"),
          parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.range(of: "^[A-Za-z0-9_.-]+$", options: .regularExpression) != nil }) else {
      throw PluginPackage.Failure.invalid("Use github.com/owner/repo or /owner/repo/tree/ref/plugin-folder. Use a commit SHA for branch names containing slashes.")
    }
    owner = parts[0]
    repository = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
    guard !repository.isEmpty else { throw PluginPackage.Failure.invalid("Missing repository name") }
    ref = parts.count >= 4 ? parts[3] : nil
    path = parts.count > 4 ? parts.dropFirst(4).joined(separator: "/") : ""
  }
}

struct PreparedPlugin {
  let package: PluginPackage
  let source: GitHubPluginSource
  let commit: String

  /// Refuse ID collisions rather than allowing another repository to take over storage.
  func install(in folder: URL, bundledIDs: Set<String>) throws -> URL {
    let fm = FileManager.default
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    let installed = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    guard !bundledIDs.contains(package.manifest.id),
          !installed.contains(where: { (try? PluginPackage(root: $0).manifest.id) == package.manifest.id }) else {
      throw PluginPackage.Failure.invalid("An app with this ID already exists. Nothing was replaced.")
    }
    let destination = folder.appendingPathComponent(package.manifest.id, isDirectory: true)
    guard !fm.fileExists(atPath: destination.path) else { throw PluginPackage.Failure.invalid("Installation folder already exists") }
    let receipt: [String: String] = ["repository": source.repositoryURL, "path": source.path, "commit": commit,
                                   "ref": source.ref ?? "", "installedAt": ISO8601DateFormatter().string(from: Date())]
    try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
      .write(to: package.root.appendingPathComponent(".wink-source.json"), options: .atomic)
    try fm.moveItem(at: package.root, to: destination)
    return destination
  }
}

/// Updates retain the publisher binding and preserve the previous package for recovery.
extension PreparedPlugin {
  func update(_ current: PluginPackage, receipt: [String: String], backups: URL) throws {
    guard package.manifest.id == current.manifest.id,
          receipt["repository"] == source.repositoryURL, receipt["path"] == source.path else {
      throw PluginPackage.Failure.invalid("Update does not match the installed app's identity and source")
    }
    let fm = FileManager.default
    try fm.createDirectory(at: backups, withIntermediateDirectories: true)
    let backup = backups.appendingPathComponent(current.manifest.id + "-" + UUID().uuidString)
    var next = receipt
    next["commit"] = commit; next["ref"] = source.ref ?? ""
    next["installedAt"] = ISO8601DateFormatter().string(from: Date())
    try JSONSerialization.data(withJSONObject: next, options: [.sortedKeys])
      .write(to: package.root.appendingPathComponent(".wink-source.json"), options: .atomic)
    try fm.moveItem(at: current.root, to: backup)
    do { try fm.moveItem(at: package.root, to: current.root) }
    catch { try fm.moveItem(at: backup, to: current.root); throw error }
  }
}

private final class PluginDownloadRedirects: NSObject, URLSessionTaskDelegate {

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    let url = request.url
    completionHandler(url?.scheme == "https" && ["api.github.com", "raw.githubusercontent.com"].contains(url?.host ?? "") ? request : nil)
  }

}

final class PluginInstaller {
  private let session: URLSession
  init(session: URLSession? = nil) {
    self.session = session ?? URLSession(configuration: .ephemeral, delegate: PluginDownloadRedirects(), delegateQueue: nil)
  }
  deinit { session.invalidateAndCancel() }

  private func fetch(_ url: URL) async throws -> Data {
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
    request.setValue("Blink-Plugin-Installer/1", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw PluginPackage.Failure.invalid("GitHub download failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)). Check the link; private repositories are not supported, and GitHub rate limits may apply.")
    }
    guard data.count <= 8 * 1024 * 1024 else { throw PluginPackage.Failure.invalid("GitHub response exceeds 8 MiB") }
    return data
  }

  func prepare(_ source: GitHubPluginSource, staging: URL) async throws -> PreparedPlugin {
    func api(_ suffix: String) -> URL { URL(string: "https://api.github.com/repos/\(source.owner)/\(source.repository)" + (suffix.isEmpty ? "" : "/" + suffix))! }
    struct Repo: Decodable { let default_branch: String }
    struct Commit: Decodable { let sha: String; let commit: Body; struct Body: Decodable { let tree: Tree }; struct Tree: Decodable { let sha: String } }
    struct GitTree: Decodable {
      let truncated: Bool
      let tree: [Entry]
      struct Entry: Decodable { let path: String; let mode: String; let type: String; let size: Int? }
    }
    let ref: String
    if let specified = source.ref { ref = specified }
    else { ref = try JSONDecoder().decode(Repo.self, from: await fetch(api(""))).default_branch }
    guard let encodedRef = ref.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { throw PluginPackage.Failure.invalid("Invalid reference") }
    let commit = try JSONDecoder().decode(Commit.self, from: await fetch(api("commits/" + encodedRef)))
    guard commit.sha.range(of: "^[a-f0-9]{40}$", options: .regularExpression) != nil,
          commit.commit.tree.sha.range(of: "^[a-f0-9]{40}$", options: .regularExpression) != nil else { throw PluginPackage.Failure.invalid("Invalid GitHub commit") }
    let tree = try JSONDecoder().decode(GitTree.self, from: await fetch(api("git/trees/\(commit.commit.tree.sha)?recursive=1")))
    guard !tree.truncated else { throw PluginPackage.Failure.invalid("Repository tree is too large. Use a smaller plugin repository.") }
    let prefix = source.path.isEmpty ? "" : source.path + "/"
    let entries = tree.tree.filter { $0.path.hasPrefix(prefix) && $0.type != "tree" }
    guard !entries.isEmpty, entries.count <= 256 else { throw PluginPackage.Failure.invalid("Plugin must contain 1–256 files") }
    var total = 0
    for entry in entries {
      let relative = String(entry.path.dropFirst(prefix.count))
      guard entry.type == "blob", ["100644", "100755"].contains(entry.mode),
            let size = entry.size, size >= 0, size <= 8 * 1024 * 1024,
            !relative.isEmpty, !relative.hasPrefix("/"), !relative.contains("\\"),
            !relative.split(separator: "/").contains(where: { $0 == ".." || $0 == "." }),
            relative != ".wink-source.json" else { throw PluginPackage.Failure.invalid("Unsafe or unsupported package file") }
      total += size
      guard total <= 32 * 1024 * 1024 else { throw PluginPackage.Failure.invalid("Plugin exceeds 32 MiB") }
    }
    guard entries.contains(where: { $0.path == prefix + "manifest.json" && ($0.size ?? Int.max) <= 65536 }) else {
      throw PluginPackage.Failure.invalid("No manifest.json in this folder. Link to the plugin folder using a GitHub tree URL.")
    }
    let root = staging.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    // Download the manifest first; nothing in the staged package is executed.
    let ordered = entries.sorted { ($0.path == prefix + "manifest.json" ? 0 : 1) < ($1.path == prefix + "manifest.json" ? 0 : 1) }
    for entry in ordered {
      try Task.checkCancellation()
      var components = URLComponents()
      components.scheme = "https"; components.host = "raw.githubusercontent.com"
      components.path = "/\(source.owner)/\(source.repository)/\(commit.sha)/\(entry.path)"
      guard let url = components.url else { throw PluginPackage.Failure.invalid("Invalid file URL") }
      let data = try await fetch(url)
      guard data.count == entry.size else { throw PluginPackage.Failure.invalid("Downloaded file size differs from pinned commit") }
      let file = root.appendingPathComponent(String(entry.path.dropFirst(prefix.count)))
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: file, options: .withoutOverwriting)
    }
    return PreparedPlugin(package: try PluginPackage(root: root), source: source, commit: commit.sha)
  }
}
