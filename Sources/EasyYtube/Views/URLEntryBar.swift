import SwiftUI
import UniformTypeIdentifiers

struct URLEntryBar: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Binding var urlText: String
    var destinationFolder: URL
    var onSubmit: () -> Void
    var onOpenFolder: () -> Void
    var allowDrop: Bool = true
    var compactButton: Bool = false

    @State private var isDropTargeted = false

    private var isSubmitDisabled: Bool {
        urlText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)

            TextField(L("Incolla un link YouTube…"), text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .onSubmit(onSubmit)

            Button(action: onOpenFolder) {
                Image(systemName: "folder")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(destinationFolder.path)

            if compactButton {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSubmitDisabled ? Color.secondary : Color.accentColor)
                .disabled(isSubmitDisabled)
            } else {
                Button(action: onSubmit) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .bold))
                        Text(L("Scarica"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(isSubmitDisabled ? Color.secondary.opacity(0.25) : Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitDisabled)
            }
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
        .onDrop(of: allowDrop ? [.url, .plainText] : [], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    urlText = url.absoluteString
                    onSubmit()
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            _ = provider.loadObject(ofClass: NSString.self) { text, _ in
                guard let text = text as? String else { return }
                DispatchQueue.main.async {
                    urlText = text
                    onSubmit()
                }
            }
            return true
        }

        return false
    }
}
