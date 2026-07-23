import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var queue = DownloadQueueManager()
    @State private var urlText: String = ""
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            FormatPickerView(
                settings: $queue.formatSettings,
                destinationFolder: $queue.destinationFolder,
                onChooseFolder: queue.chooseDestinationFolder
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)

            queueList

            Divider()
            FooterView()
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 620, idealHeight: 720)
        .background(.regularMaterial)
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                Text("EasyYtube")
                    .font(.title2.weight(.bold))
                Spacer()
                Button {
                    queue.updateEngine()
                } label: {
                    Label(
                        queue.isUpdatingEngine ? "Aggiornamento…" : "Aggiorna motore",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(queue.isUpdatingEngine)
            }

            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("Incolla un link YouTube…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .foregroundStyle(urlText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.background.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isDropTargeted ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
            .onDrop(of: [.url, .plainText], isTargeted: $isDropTargeted, perform: handleDrop)
        }
        .padding(20)
    }

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if queue.items.isEmpty {
                    emptyState
                }
                ForEach(queue.items) { item in
                    QueueItemCard(item: item, onReveal: {
                        queue.revealInFinder(item)
                    }, onRetry: {
                        queue.retry(item)
                    })
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Incolla o trascina un link per iniziare")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func submit() {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        queue.addURL(text)
        DispatchQueue.main.async { urlText = "" }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { queue.addURL(url.absoluteString) }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            _ = provider.loadObject(ofClass: NSString.self) { text, _ in
                guard let text = text as? String else { return }
                DispatchQueue.main.async { queue.addURL(text) }
            }
            return true
        }

        return false
    }
}
