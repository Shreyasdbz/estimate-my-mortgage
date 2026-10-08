import SwiftUI

/// A saved estimate's loan assumptions and total monthly ownership budget.
struct MortgageRowView: View {
    @ObservedObject var mortgage: Mortgage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mortgage.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            if let monthlyCost = mortgage.terms.monthlyCostPreview {
                Text(monthlyCost, format: .currency(code: "USD"))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit().fixedSize(horizontal: false, vertical: true)
                Text(mortgage.propertyValue == mortgage.downpaymentValue ? "per month · all-cash purchase" : "per month · \(mortgage.loanTermYears) years · \(mortgage.interestRatePercentage.formatted())%")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            } else {
                Label("Review estimate inputs", systemImage: "exclamationmark.triangle")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            Text("Property price: \(mortgage.propertyValue.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
