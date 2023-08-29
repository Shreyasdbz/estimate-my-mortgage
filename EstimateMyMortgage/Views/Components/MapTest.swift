//
//  MapTest.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import SwiftUI
import Combine
import CoreLocation
import MapKit

struct MapTest: View {
    @StateObject private var mapSearch = MapSearch()

    func reverseGeo(location: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: location)
        let search = MKLocalSearch(request: searchRequest)
        var coordinateK : CLLocationCoordinate2D?
        search.start { (response, error) in
        if error == nil, let coordinate = response?.mapItems.first?.placemark.coordinate {
            coordinateK = coordinate
        }

        if let c = coordinateK {
            let location = CLLocation(latitude: c.latitude, longitude: c.longitude)
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in

            guard let placemark = placemarks?.first else {
                let errorString = error?.localizedDescription ?? "Unexpected Error"
                print("Unable to reverse geocode the given location. Error: \(errorString)")
                return
            }

            let reversedGeoLocation = ReversedGeoLocation(with: placemark)

            address = "\(reversedGeoLocation.streetNumber) \(reversedGeoLocation.streetName)"
            city = "\(reversedGeoLocation.city)"
            state = "\(reversedGeoLocation.state)"
            zip = "\(reversedGeoLocation.zipCode)"
            mapSearch.searchTerm = address
            isFocused = false

                }
            }
        }
    }

    // Form Variables

    @FocusState private var isFocused: Bool

    @State private var btnHover = false
    @State private var isBtnActive = false

    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""

// Main UI

    var body: some View {

            VStack {
                List {
                    Section {
                        Text("Start typing your street address and you will see a list of possible matches.")
                    } // End Section
                    
                    Section {
                        TextField("Address", text: $mapSearch.searchTerm)

// Show auto-complete results
                        if address != mapSearch.searchTerm && isFocused == false {
                        ForEach(mapSearch.locationResults, id: \.self) { location in
                            Button {
                                reverseGeo(location: location)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(location.title)
                                        .foregroundColor(Color.white)
                                    Text(location.subtitle)
                                        .font(.system(.caption))
                                        .foregroundColor(Color.white)
                                }
                        } // End Label
                        } // End ForEach
                        } // End if
// End show auto-complete results

                        TextField("City", text: $city)
                        TextField("State", text: $state)
                        TextField("Zip", text: $zip)

                    } // End Section
                    .listRowSeparator(.visible)

            } // End List

            } // End Main VStack

    } // End Var Body

} // End Struct


struct MapTest_Previews: PreviewProvider {
    static var previews: some View {
        MapTest()
    }
}
