import SwiftUI

/// About & credits — Writer for iPhone is a port of joelbqz's
/// writer-computer and credits it prominently, per its GPL-3.0 license.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image("AppIconDisplay")
                            .resizable()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        Text("Writer")
                            .font(.title2.bold())
                        Text("Fast, lightweight markdown notes for iPhone")
                            .font(.subheadline)
                            .foregroundStyle(WriterTheme.muted)
                        Text("Version \(version)")
                            .font(.caption)
                            .foregroundStyle(WriterTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(WriterTheme.background)

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Writer for iPhone is based on **Writer**, the local-first desktop markdown editor by **joelbqz**.")
                            .font(.subheadline)

                        Link(destination: URL(string: "https://github.com/joelbqz/writer-computer")!) {
                            Label("joelbqz/writer-computer", systemImage: "link")
                                .font(.subheadline)
                        }
                        .tint(WriterTheme.accent)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Credits")
                }

                Section {
                    Text("Your notes are plain .md files stored on this device — find them in the Files app under “On My iPhone › Writer”.")
                        .font(.subheadline)
                        .foregroundStyle(WriterTheme.muted)
                } header: {
                    Text("Files")
                }

                Section {
                    Text("Released under the GNU General Public License v3.0, like the original Writer.")
                        .font(.subheadline)
                        .foregroundStyle(WriterTheme.muted)
                } header: {
                    Text("License")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WriterTheme.background)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
