//
//  AddressInput.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import SwiftUI
import Combine
import CoreLocation
import MapKit

struct AddressInput: View {
    
    @StateObject private var mapSearch = MapSearch()
    
    @FocusState private var isFocused: Bool
    
    @State private var btnHover = false
    @State private var isBtnActive = false
    
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    
    var body: some View {
        List{
            Section{
                TextField("Address", text: $mapSearch.searchTerm)
                
                // auto-complete results
                if address != mapSearch.searchTerm && isFocused == false {
                    ForEach(mapSearch.locationResults, id: \.self) { location in
                        Button {
                            reverseGeoSearch(location: location)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(location.title)
                                    .font(.footnote)
                                    .foregroundColor(.primary.opacity(0.7))
                                Text(location.subtitle)
                                    .font(.footnote)
                                    .foregroundColor(.primary.opacity(0.5))
                            }
                        }
                        
                    }
                }
                
                // rest of the fields
                TextField("City", text: $city)
                TextField("State", text: $state)
                TextField("Zip", text: $zip)
                
            }
        }
    }
}

extension AddressInput {
    
    /**
     Performs a reverse search on the given address
     */
    private func reverseGeoSearch(location: MKLocalSearchCompletion) {
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
}

struct AddressInput_Previews: PreviewProvider {
    static var previews: some View {
        AddressInput()
    }
}
