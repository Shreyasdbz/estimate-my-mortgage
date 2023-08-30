//
//  Constants.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import Foundation
import MapKit

let DEFAULT_MAP_SPAN = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)

let INITIAL_PROPERTY_VALUE: Decimal = 500000.00
let INITIAL_DOWNPAYMENT_VALUE: Decimal = 100000.00
let INITIAL_HOA_FEES_VALUE: Decimal = 1000.0
let INITIAL_HOME_INSURANCE_VALUE: Decimal = 1500.00
let INITIAL_INTEREST_RATE_PERCENTAGE: Decimal = 5.5
let INITIAL_LOAN_TERM_YEARS:Int16 = 30
let INITIAL_PROPERTY_TAX_VALUE: Decimal = 7500.00
let INITIAL_CLOSING_COSTS_VALUE: Decimal = 8000
let INITIAL_UPKEEP_VALUE: Decimal = 3500.00
let INITIAL_ADDRESS: String = "1600 Pennsylvania Ave"
let INITIAL_CITY: String = "Washington"
let INITIAL_STATE: String = "DC"
let INITIAL_ZIP: String = "20500"

let INITIAL_DOWNPAYMENT_PERCENT_SELECTOR: Double = 20
let INITIAL_PROPERTY_TAX_PERCENT_SELECTOR: Double = 1.5

let INITIAL_LATITUDE: CGFloat = CGFloat(38.8977)
let INITIAL_LONGITUDE: CGFloat = CGFloat(-77.036560)

let RANGE_START_DOWNPAYMENT:Double = 0.1
let RANGE_END_DOWNPAYMENT:Double = 99.9

let RANGE_START_INTEREST_RATE:Double = 0.1
let RANGE_END_INTEREST_RATE:Double = 50

let RANGE_START_LOAN_TERM:Int16 = 1
let RANGE_END_LOAN_TERM:Int16 = 100

let RANGE_START_PROPERTY_TAX:Double = 0.01
let RANGE_END_PROPERTY_TAX:Double = 10

let RANGE_START_HOA_FEES:Double = 0.01
let RANGE_END_HOA_FEES:Double = 20

let RANGE_START_UPKEEP_COSTS:Double = 0.01
let RANGE_END_UPKEEP_COSTS:Double = 20



