//
//  CalculationUtils.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import Foundation

/**
 Returns a random number between a given range
 */
func randomBetween(_ firstNum: CGFloat, _ secondNum: CGFloat) -> CGFloat{
    return CGFloat(arc4random()) / CGFloat(UINT32_MAX) * abs(firstNum - secondNum) + min(firstNum, secondNum)
}

/**
 Makes sure name / title input isn't empty
 */
func validateNameInput(value: String) -> Bool {
    guard !value.isEmpty else { return false }
    return true
}

/**
 Checks that the passed property value is valid.
 Valid if: > 0
 */
func validatePropertyValue(value: Double) -> Bool {
    guard value > 0 else { return false }
    return true
}

/**
 Validates that the passed downpayment is valid
 Is valid if:  lower than propertyValue AND greater than or equal to 0
 */
func validateDownpaymentValue(downpaymentValue: Double, propertyValue: Double) -> Bool {
    guard downpaymentValue < propertyValue else { return false }
    guard downpaymentValue >= 0 else { return false }
    return true
}

/**
 Validates that downpayment is between 0 and 100 %
 */
func validateDownPaymentPercent(value: Double) -> Bool {
    guard value >= 0 && value <= 100 else { return false }
    return true
}

/**
 Interest rate must be within bounds
 Interest rate cannot be zero
 */
func validateInterestRateValue(value: Double) -> Bool {
    guard value >= RANGE_START_INTEREST_RATE && value <= RANGE_END_INTEREST_RATE else { return false }
    return true
}

/**
 Loan term must be within bounds
 Loan term cannot be zero
 */
func validateLoanTermValue(value: Int16) -> Bool {
    guard value >= RANGE_START_LOAN_TERM && value <= RANGE_END_LOAN_TERM else { return false }
    return true
}



/**
 Calculates the monthly payment value for a given set of parameters
 */
func calculateMonthlyPaymentValue(
    principleValue: Double,
    annualInterestRate: Double,
    loanTerm: Int16,
    propertyTaxValue: Double,
    insuranceValue: Double,
    hoaFeesValue: Double,
    upkeepValue: Double
) -> Double {
    /**
     Formula:
     M = P * ( r * ( 1 + r)^n ) / ( (( 1 + r )^n ) - 1  )
     Where:
     M = total monthly payment
     P = principle loan amount
     r = monthly interest rate
     n = number of payments over the loan's lifetime
     */
    
    let r = Double((annualInterestRate / 100) / 12)
    let n = Double(loanTerm * 12)
    
    let topPart = r * pow((1 + r), n)
    let bottomPart = pow((1 + r), n) - 1

    let baseMonthlyPayment = principleValue * (topPart / bottomPart)    
    let additionalPayments = (propertyTaxValue + insuranceValue + upkeepValue + hoaFeesValue) / 12
    
    return baseMonthlyPayment + additionalPayments
}
