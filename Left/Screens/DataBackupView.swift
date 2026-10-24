#if DEBUG
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportURL: URL?
    @State private var isChoosingImport = false
    @State private var pendingImport: PendingLeftImport?
    @State private var message: StatusMessage?

    private struct StatusMessage: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    var body: some View {
        List {
            Section {
                Button {
                    exportData()
                } label: {
                    Label("Create JSON export", systemImage: "square.and.arrow.up")
                }

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share \(exportURL.lastPathComponent)", systemImage: "airplayaudio")
                    }
                }
            } header: {
                Text("Export")
            } footer: {
                Text("Exports every record with stable IDs and relationships. Money is stored as decimal strings.")
            }

            Section {
                Button {
                    isChoosingImport = true
                } label: {
                    Label("Choose JSON backup", image: "IconDownload")
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Existing records with matching IDs are updated. Changes are saved only after the complete backup is valid.")
            }
        }
        .navigationTitle("Data backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isChoosingImport,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            chooseImport(result)
        }
        .alert("Import this backup?", isPresented: Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingImport = nil }
            Button("Import") { performImport(monthConflictPolicy: .fail) }
            Button("Overwrite existing months", role: .destructive) {
                performImport(monthConflictPolicy: .overwrite)
            }
        } message: {
            if let pendingImport {
                Text(countSummary(pendingImport.counts))
            }
        }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.detail), dismissButton: .default(Text("OK")))
        }
    }

    private func exportData() {
        do {
            exportURL = try LeftDataTransfer.export(from: modelContext)
        } catch {
            message = StatusMessage(title: "Export failed", detail: readable(error))
        }
    }

    private func chooseImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            pendingImport = try LeftDataTransfer.decodeImport(at: url)
        } catch {
            message = StatusMessage(title: "Couldn’t read backup", detail: readable(error))
        }
    }

    private func performImport(monthConflictPolicy: MonthConflictPolicy) {
        guard let pendingImport else { return }
        self.pendingImport = nil
        do {
            try LeftDataTransfer.importEnvelope(pendingImport.envelope,
                                                into: modelContext,
                                                monthConflictPolicy: monthConflictPolicy)
            message = StatusMessage(title: "Import complete",
                                    detail: countSummary(pendingImport.counts))
        } catch {
            message = StatusMessage(title: "Import failed", detail: readable(error))
        }
    }

    private func countSummary(_ counts: ImportCounts) -> String {
        counts.rows.map { "\($0.0): \($0.1)" }.joined(separator: "\n")
    }

    private func readable(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
#endif
