import SwiftUI

struct QueueItemCard: View {
    let item: DownloadItem
    var onReveal: () -> Void
    var onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                statusView
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
        .animation(.easeInOut(duration: 0.2), value: item.state)
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
            if let url = item.thumbnailURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.state {
        case .pending:
            Text("In coda")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .fetchingInfo:
            Text("Recupero informazioni…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .downloading(let progress, let speed):
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text(speed.isEmpty ? "\(Int(progress * 100))%" : "\(Int(progress * 100))% · \(speed)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .completed:
            Label("Completato", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch item.state {
        case .downloading:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Button(action: onReveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
        case .failed:
            Button(action: onRetry) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        default:
            EmptyView()
        }
    }
}
