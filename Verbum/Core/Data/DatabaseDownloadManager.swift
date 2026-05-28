import Foundation
import Combine

/// Optional over-the-air download path for the word database.
/// NOTE: The 1,000-word DB now ships bundled in the app (see WordDatabase.seedFromBundleIfNeeded),
/// so this manager is dormant — `startIfNeeded()` no-ops because the DB is already available.
/// Kept as a future hook for OTA word updates; wire up `remoteURL` to a real CDN to enable it.
@MainActor
final class DatabaseDownloadManager: NSObject, ObservableObject {
    static let shared = DatabaseDownloadManager()

    // MARK: - Replace with real CDN URL when database is ready
    static let remoteURL = URL(string: "https://cdn.verbum.app/words_v1.db")!

    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case installing
        case done
        case failed(String)

        var isActive: Bool {
            switch self {
            case .downloading, .installing: return true
            default: return false
            }
        }
    }

    @Published var state: State = .idle

    private var session: URLSession!
    private var downloadTask: URLSessionDownloadTask?

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.verbum.app.dbdownload"
        )
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        if WordDatabase.shared.isAvailable { state = .done }
    }

    // MARK: - Public

    func startIfNeeded() {
        // DB is bundled, so this guard returns early in normal operation.
        guard !WordDatabase.shared.isAvailable, state == .idle else { return }
        state = .downloading(progress: 0)
        downloadTask = session.downloadTask(with: Self.remoteURL)
        downloadTask?.resume()
    }

    func retry() {
        state = .idle
        startIfNeeded()
    }

    func cancel() {
        downloadTask?.cancel()
        state = .idle
    }

    // MARK: - Internal state setters (called from delegate Tasks)

    fileprivate func setState(_ newState: State) {
        state = newState
    }

    fileprivate func handleDownloadFinished(from location: URL) {
        state = .installing
        do {
            try WordDatabase.shared.install(from: location)
            WordRepository.shared.reloadFromDatabase()
            state = .done
            NotificationCenter.default.post(name: .wordDatabaseInstalled, object: nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DatabaseDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData _: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in self.setState(.downloading(progress: pct)) }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // Copy file synchronously here on the delegate queue — the temp file is gone after this returns.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("verbum_download_\(UUID().uuidString).db")
        try? FileManager.default.copyItem(at: location, to: tmp)
        Task { @MainActor in
            self.handleDownloadFinished(from: tmp)
            try? FileManager.default.removeItem(at: tmp)
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsErr = error as NSError
        guard nsErr.code != NSURLErrorCancelled else { return }
        Task { @MainActor in self.setState(.failed(error.localizedDescription)) }
    }
}

extension Notification.Name {
    static let wordDatabaseInstalled = Notification.Name("wordDatabaseInstalled")
}
