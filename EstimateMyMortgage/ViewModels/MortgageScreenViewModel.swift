//
//  MortgageScreenViewModel.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/25/23.
//

import Foundation
import MapKit
import SwiftUI

@MainActor
final class MortgageScreenViewModel: ObservableObject {
    
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: CLLocationDegrees(INITIAL_LATITUDE), longitude: CLLocationDegrees(INITIAL_LONGITUDE)),
        span: DEFAULT_MAP_SPAN
    )
    @Published var markers = [PlaceMark(
        location: MapMarker(
            coordinate: CLLocationCoordinate2D(latitude: CLLocationDegrees(INITIAL_LATITUDE), longitude: CLLocationDegrees(INITIAL_LONGITUDE)),
            tint: .red
        )
    )]
    
    var provider = MortgagesProvider.shared
    var mortgage: Mortgage
    @Published var mortgageToEdit: Mortgage? = nil
    @Published var bottomDrawerPresent: Bool = false;
    
    init(mortgage: Mortgage, provider: MortgagesProvider){
        self.provider = provider
        self.mortgage = mortgage
        self.setMap()
    }
    
    func setMap() {
        let geoCoder = CLGeocoder()
        
        geoCoder.geocodeAddressString(mortgage.formattedAddressString) { placemarks, error in
            guard let placemark = placemarks?.first?.location else {
                print("[EMM] -- mortgage screen vm -- setMap -- COULD NOT FIND PLACEMARK")
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
}
