import SwiftUI

struct ContentView: View {
    @ObservedObject private var queue = DownloadQueueManager.shared
    @StateObject private var updateChecker = UpdateChecker()
    @State private var urlText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            UpdateBannerView(checker: updateChecker)
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
        .animation(.easeInOut(duration: 0.25), value: updateChecker.isAvailable)
        .task {
            updateChecker.check()
        }
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

            URLEntryBar(
                urlText: $urlText,
                destinationFolder: queue.destinationFolder,
                onSubmit: submit,
                onChooseFolder: queue.chooseDestinationFolder
            )
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
}
