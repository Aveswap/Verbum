import Foundation
import Combine

/// Downloads the full 1,000-word SQLite database in a URLSession background task.
/// Replace `remoteURL` with your CDN URL once the database is ready.
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
}

// MARK: - URLSessionDownloadDelegate

extension DatabaseDownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData _: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.state = .downloading(progress: pct) }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async { self.state = .installing }
        do {
            try WordDatabase.shared.install(from: location)
            WordRepository.shared.reloadFromDatabase()
            DispatchQueue.main.async {
                self.state = .done
                NotificationCenter.default.post(name: .wordDatabaseInstalled, object: nil)
            }
        } catch {
            DispatchQueue.main.async {
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsErr = error as NSError
        // Ignore cancellation
        guard nsErr.code != NSURLErrorCancelled else { return }
        DispatchQueue.main.async {
            self.state = .failed(error.localizedDescription)
        }
    }
}

extension Notification.Name {
    static let wordDatabaseInstalled = Notification.Name("wordDatabaseInstalled")
}
