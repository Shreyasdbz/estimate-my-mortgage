import SwiftUI

struct NoMortgagesView: View {
    let create: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No estimates yet", systemImage: "house")
        } description: {
            Text("Estimate a monthly payment, then save options to compare.")
        } actions: {
            Button("New Estimate", systemImage: "plus", action: create)
                .buttonStyle(.borderedProminent)
        }
    }
}
