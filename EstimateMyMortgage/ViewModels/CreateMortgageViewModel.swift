//
//  CreateMortgageViewModel.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import Foundation
import CoreData
import MapKit
import SwiftUI

@MainActor
final class CreateMortgageViewModel: ObservableObject {

    @Published private var provider: MortgagesProvider
    @Published var mortgage: Mortgage
    @Published var mapRegion: MKCoordinateRegion
    @Published var markers: [PlaceMark]
    
    @Published var nameInputError: Bool = false
    @Published var addressInputError: Bool = false
    @Published var propertyValueError: Bool = false
    @Published var downpaymentValueError: Bool = false
    @Published var downpaymentPercentError: Bool = false
    @Published var interestRatePercentageError: Bool = false
    @Published var loanTermValueError: Bool = false
    @Published var propertyTaxValue: Bool = false
    @Published var propertyTaxPercentage: Bool = false
    
    @Published var errorMessage: String?
    @Published var errorPresented: Bool = false
    
    // Derived values
    @Published var downpaymentPercentageSelector: Double {
        didSet {
            self.mortgage.downpaymentValue = self.downpaymentPercentageSelector * self.mortgage.propertyValue / 100
        }
    }
    @Published var propertyTaxPercentageSelector: Double {
        didSet{
            self.mortgage.propertyTaxValue = self.propertyTaxPercentageSelector * self.mortgage.propertyValue / 100
        }
    }
    

    let isNew: Bool
    private let context: NSManagedObjectContext
    
    init(provider: MortgagesProvider, mortgage: Mortgage? = nil) {
        self.provider = provider
        self.context = provider.newContext
        if let mortgage,
           let existingMortgageCopy = try? context.existingObject(with: mortgage.objectID) as? Mortgage {
            self.mortgage = existingMortgageCopy
            self.isNew = false
            // set maps
            self.mapRegion = getMapRegionForAddress(formattedAddress: existingMortgageCopy.formattedAddressString)
            self.markers = getMapMarkerForAddress(formattedAddress: existingMortgageCopy.formattedAddressString)
            self.downpaymentPercentageSelector = (mortgage.downpaymentValue / mortgage.propertyValue) * 100
            self.propertyTaxPercentageSelector = (mortgage.propertyTaxValue / mortgage.propertyValue) * 100
        } else {
            self.mortgage = Mortgage(context: self.context)
            self.isNew = true
            // set maps
            self.mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: CLLocationDegrees(INITIAL_LATITUDE), longitude: CLLocationDegrees(INITIAL_LONGITUDE)),
                span: DEFAULT_MAP_SPAN
            )
            self.markers = [PlaceMark(
                location: MapMarker(
                    coordinate: CLLocationCoordinate2D(latitude: CLLocationDegrees(INITIAL_LATITUDE), longitude: CLLocationDegrees(INITIAL_LONGITUDE)),
                    tint: .red
                )
            )]
            self.downpaymentPercentageSelector = INITIAL_DOWNPAYMENT_PERCENT_SELECTOR
            self.propertyTaxPercentageSelector = INITIAL_PROPERTY_TAX_PERCENT_SELECTOR
        }
    }
    
    /**
     Validates all the inputs in create / edit mortgage screen then sets an appropriate error message
     */
    private func validateOnSave() -> Bool {
        guard validateNameInput(value: mortgage.name) else {
            nameInputError = true
            errorPresented = true
            errorMessage = "Please enter an appropriate name for the estimate"
            return false
        }
        nameInputError = false
        
        guard validatePropertyValue(value: mortgage.propertyValue) else {
            propertyValueError = true
            errorPresented = true
            errorMessage = "Please enter an appropriate property value"
            return false
        }
        propertyValueError = false

        guard validateDownpaymentValue(downpaymentValue: mortgage.downpaymentValue, propertyValue: mortgage.propertyValue) else {
            downpaymentValueError = true
            errorPresented = true
            errorMessage = "Please enter an appropriate downpayment value"
            return false
        }
        downpaymentValueError = false

        guard validateDownPaymentPercent(value: downpaymentPercentageSelector) else {
            downpaymentPercentError = true
            errorPresented = true
            errorMessage = "Please enter an appropriate downpayment %"
            return false
        }
        downpaymentPercentError = false

        guard validateInterestRateValue(value: mortgage.interestRatePercentage) else {
            interestRatePercentageError = true
            errorPresented = true
            errorMessage = "Please enter an appropriate interest rate"
            return false
        }
        interestRatePercentageError = false
        
        guard validateLoanTermValue(value: mortgage.loanTermYears) else {
            loanTermValueError = true
            errorPresented = true
            errorMessage = "Please enter an appropriate loan term"
            return false
        }
        loanTermValueError = false

        errorPresented = false
        errorMessage = nil
        return true
    }
    
    func save() throws {
        guard validateOnSave() else { return }
        if context.hasChanges {
            try context.save()
        }
    }
    
    func setMaps(){
        let geoCoder = CLGeocoder()
        
        geoCoder.geocodeAddressString(self.mortgage.formattedAddressString) { placemarks, error in
            guard let placemark = placemarks?.first?.location else {
                print("[EMM] -- vm -- updateMap -- COULD NOT FIND PLACEMARK")
                return
            }
            self.mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude),
                span: DEFAULT_MAP_SPAN
            )
            self.markers = [PlaceMark(
                location: MapMarker(
                    coordinate: CLLocationCoordinate2D(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude),
                    tint: .red
                )
            )]
        }
        
        
    }
    
    func updateMap(){
        let geoCoder = CLGeocoder()
        
        geoCoder.geocodeAddressString(mortgage.formattedAddressString) { placemarks, error in

            guard let placemark = placemarks?.first?.location else {
                print("[EMM] -- vm -- updateMap -- COULD NOT FIND PLACEMARK")
                return
            }
            self.mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude),
                span: DEFAULT_MAP_SPAN
            )
            self.markers = [PlaceMark(
                location: MapMarker(
                    coordinate: CLLocationCoordinate2D(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude),
                    tint: .red
                )
            )]
        }
    }
    
    func delete() throws {
        let context = provider.viewContext
        let existingMortgage = try context.existingObject(with: mortgage.objectID)
        context.delete(existingMortgage)
        Task(priority: .background) {
            try await context.perform {
                try context.save()
            }
        }
    }
}
