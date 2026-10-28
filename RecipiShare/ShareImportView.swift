import SwiftUI

struct ShareImportView: View {
    let model: ShareImportModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch model.state {
                case .importing:
                    ProgressView()
                    Text("Saving recipe…")
                case .saved(let title):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("Saved \(title)")
                        .multilineTextAlignment(.center)
                case .failed(let message):
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(message)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("recipi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { model.close() }
                }
            }
        }
    }
}
