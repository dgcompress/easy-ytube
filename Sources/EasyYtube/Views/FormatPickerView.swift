import SwiftUI

struct FormatPickerView: View {
    @Binding var settings: AudioFormatSettings
    @Binding var destinationFolder: URL
    var onChooseFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FORMATO D'USCITA")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(OutputContainer.allCases) { container in
                    ContainerOptionButton(
                        container: container,
                        isSelected: settings.container == container
                    ) {
                        settings.container = container
                    }
                }
            }

            if settings.container == .mp3 {
                Picker("", selection: $settings.encodingMode) {
                    ForEach(EncodingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 16) {
                    if settings.encodingMode == .bitrate {
                        LabeledPicker(label: "Codifica") {
                            Picker("", selection: $settings.bitrateKbps) {
                                ForEach(AudioFormatSettings.availableBitrates, id: \.self) { kbps in
                                    Text("\(kbps) Kbps").tag(kbps)
                                }
                            }
                            .labelsHidden()
                        }
                    } else {
                        LabeledPicker(label: "Qualità") {
                            Picker("", selection: $settings.vbrQuality) {
                                ForEach(0...9, id: \.self) { level in
                                    Text("\(level)").tag(level)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    Spacer()

                    LabeledPicker(label: "Frequenza") {
                        Picker("", selection: $settings.sampleRate) {
                            ForEach(AudioFormatSettings.availableSampleRates, id: \.self) { rate in
                                Text("\(rate) Hz").tag(rate)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }

            if settings.container == .mp4 {
                LabeledPicker(label: "Qualità video") {
                    Picker("", selection: $settings.videoQuality) {
                        ForEach(VideoQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .labelsHidden()
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(destinationFolder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Cambia…", action: onChooseFolder)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.background.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator))
    }
}

private struct ContainerOptionButton: View {
    let container: OutputContainer
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(container.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Text(container.caption)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct LabeledPicker<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content
                .frame(width: 120)
        }
    }
}
