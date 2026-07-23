import Foundation
import AppKit
import UserNotifications

@MainActor
final class DownloadQueueManager: ObservableObject {
    static let shared = DownloadQueueManager()

    @Published var items: [DownloadItem] = []
    @Published var formatSettings = AudioFormatSettings()
    @Published var destinationFolder: URL
    @Published var isUpdatingEngine = false

    private let service = YtDlpService()
    private let maxConcurrent = 2
    private var runningCount = 0
    private var downloadedVideoIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "downloadedVideoIDs") ?? [])

    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = downloads.appendingPathComponent("EasyYtube")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.destinationFolder = folder

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func addURL(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              host.contains("youtu") else { return }

        let item = DownloadItem(url: url)
        items.append(item)
        Task { await resolveInfo(itemID: item.id) }
    }

    func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationFolder
        if panel.runModal() == .OK, let url = panel.url {
            destinationFolder = url
        }
    }

    func openDestinationFolder() {
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(destinationFolder)
    }

    func updateEngine() {
        guard !isUpdatingEngine else { return }
        isUpdatingEngine = true
        Task {
            try? await service.selfUpdate()
            isUpdatingEngine = false
        }
    }

    func revealInFinder(_ item: DownloadItem) {
        guard case .completed(let fileURL) = item.state else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            showFileMissingAlert()
        }
    }

    func retry(_ item: DownloadItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }),
              case .failed = items[idx].state else { return }
        items[idx].state = .pending
        processQueue()
    }

    /// Cancels a pending/in-flight download and removes it from the queue —
    /// used when the user started a download by mistake.
    func cancel(_ item: DownloadItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if case .downloading = items[idx].state {
            service.cancelDownload(id: item.id)
        }
        items.remove(at: idx)
    }

    // MARK: - Internals

    private func resolveInfo(itemID: UUID) async {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].state = .fetchingInfo
        let requestedURL = items[idx].url

        do {
            let infos = try await service.fetchInfo(for: requestedURL)

            guard let currentIdx = items.firstIndex(where: { $0.id == itemID }) else { return }

            // Solo il brano del link inserito, mai l'intera playlist anche se l'URL la referenzia.
            if let info = infos.first {
                items[currentIdx].url = info.webpageURL
                items[currentIdx].videoID = info.id
                items[currentIdx].title = info.title
                items[currentIdx].thumbnailURL = info.thumbnailURL

                if confirmRedownloadIfNeeded(id: info.id, title: info.title) {
                    items[currentIdx].state = .pending
                } else {
                    items.removeAll { $0.id == itemID }
                }
            }
        } catch {
            if let currentIdx = items.firstIndex(where: { $0.id == itemID }) {
                items[currentIdx].state = .failed(error.localizedDescription)
            }
        }

        processQueue()
    }

    private func processQueue() {
        while runningCount < maxConcurrent {
            guard let idx = items.firstIndex(where: {
                if case .pending = $0.state { return true }
                return false
            }) else { return }

            let itemID = items[idx].id
            let url = items[idx].url
            items[idx].state = .downloading(progress: 0, speed: "")
            runningCount += 1

            let settings = formatSettings
            let destination = destinationFolder

            Task {
                do {
                    let fileURL = try await service.download(
                        id: itemID,
                        url: url,
                        settings: settings,
                        destination: destination
                    ) { [weak self] progress, speed in
                        Task { @MainActor in
                            self?.updateProgress(itemID: itemID, progress: progress, speed: speed)
                        }
                    }
                    await MainActor.run {
                        self.finishDownload(itemID: itemID, result: .success(fileURL))
                    }
                } catch {
                    await MainActor.run {
                        self.finishDownload(itemID: itemID, result: .failure(error))
                    }
                }
            }
        }
    }

    private func updateProgress(itemID: UUID, progress: Double, speed: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].state = .downloading(progress: progress, speed: speed)
    }

    private func finishDownload(itemID: UUID, result: Result<URL, Error>) {
        runningCount = max(0, runningCount - 1)

        guard let idx = items.firstIndex(where: { $0.id == itemID }) else {
            processQueue()
            return
        }

        switch result {
        case .success(let fileURL):
            items[idx].state = .completed(fileURL: fileURL)
            if let videoID = items[idx].videoID {
                downloadedVideoIDs.insert(videoID)
                UserDefaults.standard.set(Array(downloadedVideoIDs), forKey: "downloadedVideoIDs")
            }
            notifyCompletion(title: items[idx].title)
        case .failure(let error):
            items[idx].state = .failed(error.localizedDescription)
        }

        processQueue()
    }

    private func confirmRedownloadIfNeeded(id: String, title: String) -> Bool {
        guard downloadedVideoIDs.contains(id) else { return true }

        let alert = NSAlert()
        alert.messageText = L("Hai già scaricato questo brano")
        alert.informativeText = String(format: L("\"%@\" risulta già scaricato in precedenza. Vuoi scaricarlo di nuovo?"), title)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("Scarica comunque"))
        alert.addButton(withTitle: L("Annulla"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showFileMissingAlert() {
        let alert = NSAlert()
        alert.messageText = L("File non trovato")
        alert.informativeText = L("Il file non è più presente nella cartella di destinazione. Potrebbe essere stato spostato o eliminato.")
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func notifyCompletion(title: String) {
        let content = UNMutableNotificationContent()
        content.title = L("Download completato")
        content.body = title
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

}
