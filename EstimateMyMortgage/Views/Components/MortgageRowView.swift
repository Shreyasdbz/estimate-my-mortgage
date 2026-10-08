import SwiftUI

/// A saved estimate's loan assumptions and total monthly ownership budget.
struct MortgageRowView: View {
    @ObservedObject var mortgage: Mortgage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mortgage.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            if let calculation = mortgage.terms.calculation {
                Text(calculation.monthlyPayment, format: .currency(code: "USD"))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit().fixedSize(horizontal: false, vertical: true)
                Text(calculation.principalValue == 0 ? "per month · all-cash purchase" : "per month · \(mortgage.loanTermYears) years · \(mortgage.interestRatePercentage.formatted())%")
                    .font(.subheadline).foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
            } else {
                Label("Review estimate inputs", systemImage: "exclamationmark.triangle")
                    .font(.subheadline).foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
            }
            Text("Property price: \(mortgage.propertyValue.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                .font(.caption).foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
