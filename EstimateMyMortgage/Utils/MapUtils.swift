//
//  MapUtils.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

func getGeoCodePlacemarkLocation(address: String) -> CLLocationCoordinate2D {

    var finalCoordinates: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: CLLocationDegrees(INITIAL_LATITUDE), longitude: CLLocationDegrees(INITIAL_LONGITUDE))

    let geoCoder = CLGeocoder()

    geoCoder.geocodeAddressString(address) { placemarks, error in

        guard let placemark = placemarks?.first?.location else {
            print("[EMM] -- getGeoCodePlacemarkLocation -- COULD NOT FIND PLACEMARK")
            return
        }        
        finalCoordinates = placemark.coordinate
    }

    return finalCoordinates
}


func getMapRegionForAddress(formattedAddress: String) -> MKCoordinateRegion {

    let geoCoder = CLGeocoder()
    var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: CLLocationDegrees(INITIAL_LATITUDE), longitude: CLLocationDegrees(INITIAL_LONGITUDE)),
        span: DEFAULT_MAP_SPAN
    )
    
    geoCoder.geocodeAddressString(formattedAddress) { placemarks, error in
        guard let placemark = placemarks?.first?.location else {
            print("[EMM] -- vm -- updateMap -- COULD NOT FIND PLACEMARK")
            return
        }
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude),
            span: DEFAULT_MAP_SPAN
        )
    }
    return mapRegion
}

func getMapMarkerForAddress(formattedAddress: String) -> [PlaceMark] {

    let geoCoder = CLGeocoder()
    var markers = [PlaceMark(
        location: MapMarker(
            coordinate: CLLocationCoordinate2D(latitude: CLLocationDegrees(INITIAL_LATITUDE), longitude: CLLocationDegrees(INITIAL_LONGITUDE)),
            tint: .red
        )
    )]
    
    geoCoder.geocodeAddressString(formattedAddress) { placemarks, error in
        guard let placemark = placemarks?.first?.location else {
            print("[EMM] -- vm -- updateMap -- COULD NOT FIND PLACEMARK")
            return
        }
        markers = [PlaceMark(
            location: MapMarker(
                coordinate: CLLocationCoordinate2D(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude),
                tint: .red
            )
        )]
    }
    return markers
}


