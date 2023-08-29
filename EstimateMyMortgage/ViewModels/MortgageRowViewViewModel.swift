//
//  MortgageRowViewViewModel.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/26/23.
//

import Foundation
import SwiftUI
import MapKit

@MainActor 
final class MortgageRowViewViewModel: ObservableObject {
    
    @Published var mapRegion: MKCoordinateRegion
    @Published var markers: [PlaceMark]
    
    var mortgage: Mortgage
    
    init(mortgage: Mortgage){
        self.mortgage = mortgage

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
        
        self.setMap()
        
    }
    
    func setMap() {
        let geoCoder = CLGeocoder()
        
        geoCoder.geocodeAddressString(self.mortgage.formattedAddressString) { placemarks, error in
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
