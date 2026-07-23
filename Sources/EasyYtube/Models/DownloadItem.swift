import Foundation

enum DownloadState: Equatable {
    case pending
    case fetchingInfo
    case downloading(progress: Double, speed: String)
    case completed(fileURL: URL)
    case failed(String)
}

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    var url: URL
    var title: String
    var thumbnailURL: URL?
    var state: DownloadState

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.absoluteString
        self.thumbnailURL = nil
        self.state = .pending
    }
}
