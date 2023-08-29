//
//  MortgageRowView.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import SwiftUI
import MapKit
import CoreLocation

struct MortgageRowView: View {
    
    @ObservedObject var vm: MortgageRowViewViewModel
    
    var body: some View {
        HStack{
            // map view
            MortgageMapView

            // details view
            Spacer()
            MortgageDetailsColumn
                .onAppear {
                    vm.setMap()
                }
                .padding(.vertical, 2)
            Spacer()

            //arow
            Image(systemName: "arrow.forward.circle.fill")
                .font(.title2)
                .padding(.trailing, 10)
        }
        .background(Material.ultraThick)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 2)
    }
}

extension MortgageRowView {
    
    private var MortgageMapView: some View {
                        
        Map(coordinateRegion: $vm.mapRegion,
            annotationItems: vm.markers) { mark in
            mark.location
        }
            .allowsHitTesting(false)
            .frame(maxWidth: 100, maxHeight: 400)
        }
    
    private var MortgageDetailsColumn: some View {
        VStack(alignment: .leading){
            // title
            Text(vm.mortgage.name)
                .font(.title2)
                .fontWeight(.bold)
            
            // details rows
            VStack(spacing: 5) {
                MortgageDetailsRow(key: "Property value", value: vm.mortgage.formattedPropertyValue)
                MortgageDetailsRow(key: "Downpayment", value: vm.mortgage.formattedDownPaymentPercentage)
                MortgageDetailsRow(key: "Loan term", value: vm.mortgage.formattedLoanTerm)
                MortgageDetailsRow(key: "Interest rate", value: vm.mortgage.formattedInterestRate)
            }

            // total row
            Text(vm.mortgage.formattedMonthlyMortgagePayment)
                .font(.title3)
        }
    }
    
    private func MortgageDetailsRow(key: String, value: String) -> some View {
        HStack{
            Text(key)
                .font(.footnote)

            Spacer()

            Text(value)
                .font(.footnote)
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.125))
                .cornerRadius(4)
        }
    }
}

struct MortgageRowView_Previews: PreviewProvider {
    
    static var previews: some View {
        MortgageRowView(vm: .init(mortgage: .preview()))
    }
}
