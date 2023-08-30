//
//  CreateMortgageView.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import SwiftUI
import Combine
import CoreLocation
import MapKit

struct CreateMortgageView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var vm: CreateMortgageViewModel
    
    let geoCoder = CLGeocoder()
    
    @StateObject private var mapSearch = MapSearch()
    @FocusState private var isFocused: Bool
    @FocusState private var focusedField: Field?

    @State private var locationSheetShowing:Bool = false;
    
    let BOTTOM_PADDING:CGFloat = CGFloat(400)
    
    var body: some View {
        List{
            Group {
                TitleInput
                LocationInput
            }
            .onAppear {
                vm.setMaps()
            }
            Group{
                PropertyValueInput
                DownPaymentInput
                InterestRatePercentageInput
                LoanTermInput
                InsuranceInput
                TaxInput
                ClosingCostsInput
                HoaInput
                UpkeepInput
            }
            Group{
                CreateButton
                    .listRowSeparator(.hidden)
                    .padding(.bottom, vm.isNew ? BOTTOM_PADDING : 0)
                if(!vm.isNew){
                    DeleteButton
                        .listRowSeparator(.hidden)
                }
            }
            
        }
        .sheet(isPresented: $locationSheetShowing, content: {
            SheetLocationView
        })
        .ignoresSafeArea(edges: SwiftUI.Edge.Set.bottom)
        .alert(
            vm.errorMessage ?? "Input Error",
            isPresented: $vm.errorPresented,
            actions: {
                Button("OK"){
                    vm.errorPresented = false
                }
            })
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button{
                    dismiss()
                } label: {
                    Text("Cancel")
                }
            }
            if(!vm.isNew){
                ToolbarItem(placement: .confirmationAction) {
                    Button{
                        do{
                            try vm.save()
                            if(!vm.errorPresented){
                                dismiss()
                            }
                        } catch {
                            print("[EMM] -- error -- saving existing value")
                        }
                    } label: {
                        Text("Save")
                    }
                }
            }
        }
        .toolbar {
//            ToolbarItemGroup(placement: .keyboard) {
//                Button(action: focusPreviousField) {
//                    Image(systemName: "chevron.up")
//                }
//                .disabled(!canFocusPreviousField()) // remove this to loop through fields
//                Button(action: focusNextField) {
//                    Image(systemName: "chevron.down")
//                }
//                .disabled(!canFocusNextField()) // remove this to loop through fields
//                Spacer()
//            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle(vm.isNew ? "Create new estimate" : "Update \(vm.mortgage.name)")
    }
    
}

extension CreateMortgageView {
    
    private func InputFieldCaption(captionText: String) -> some View {
        Text(captionText)
            .foregroundColor(.secondary)
            .font(.caption)
            .bold()
    }
    
    private func TextInputField(placeholderText: String, binding: Binding<String>, showError: Bool, focusField: Field) -> some View {
        TextField(placeholderText, text: binding)
            .bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.075))
            .overlay(showError == true ?
                     RoundedRectangle(cornerRadius: 6)
                .stroke(.red, lineWidth: 1)
                     : nil
            )
            .cornerRadius(6)
            .keyboardType(.default)
            .focused($focusedField, equals: focusField)
            .onSubmit {
                focusNextField()
            }
    }
    
    private func DoubleNumberInputField(placeholderText: String, binding: Binding<Double>, showError: Bool, focusField: Field) -> some View {
        TextField(placeholderText, value: binding, format: .number)
            .font(.subheadline)
            .bold()
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.075))
            .overlay(showError == true ?
                     RoundedRectangle(cornerRadius: 6)
                .stroke(.red, lineWidth: 1)
                     : nil
            )
            .cornerRadius(6)
            .keyboardType(.decimalPad)
            .frame(width: 120)
            .focused($focusedField, equals: focusField)
            .onSubmit {
                focusNextField()
            }
    }
    private func DoubleNumberInputFieldMedium(placeholderText: String, binding: Binding<Double>, showError: Bool, focusField: Field) -> some View {
        TextField(placeholderText, value: binding, format: .number)
            .font(.subheadline)
            .bold()
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.075))
            .overlay(showError == true ?
                     RoundedRectangle(cornerRadius: 6)
                .stroke(.red, lineWidth: 1)
                     : nil
            )
            .cornerRadius(6)
            .keyboardType(.decimalPad)
            .frame(width: 100)
            .focused($focusedField, equals: focusField)
            .onSubmit {
                focusNextField()
            }
    }
    private func DoubleNumberInputFieldSmall(placeholderText: String, binding: Binding<Double>, showError: Bool, focusField: Field) -> some View {
        TextField(placeholderText, value: binding, format: .number)
            .font(.subheadline)
            .bold()
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.075))
            .overlay(showError == true ?
                     RoundedRectangle(cornerRadius: 6)
                .stroke(.red, lineWidth: 1)
                     : nil
            )
            .cornerRadius(6)
            .keyboardType(.decimalPad)
            .frame(width: 80)
            .focused($focusedField, equals: focusField)
            .onSubmit {
                focusNextField()
            }
    }
    
    private func SmallNumberInputField(placeholderText: String, binding: Binding<Int16>, showError: Bool, focusField: Field) -> some View {
        TextField(placeholderText, value: binding, format: .number)
            .font(.subheadline)
            .bold()
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.075))
            .overlay(showError == true ?
                     RoundedRectangle(cornerRadius: 6)
                .stroke(.red, lineWidth: 1)
                     : nil
            )
            .cornerRadius(6)
            .keyboardType(.numberPad)
            .frame(width: 50)
            .focused($focusedField, equals: focusField)
            .onSubmit {
                focusNextField()
            }
    }
    
    
    private var TitleInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "TITLE")
            TextInputField(placeholderText: "Give your mortgage a name *", binding: $vm.mortgage.name, showError: vm.nameInputError, focusField: .name)
        }
    }
    
    private var SheetLocationView: some View {
        VStack{
            HStack{
                Button {
                    locationSheetShowing = false
                } label: {
                    Text("Dismiss")
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }.padding(.vertical)
            HStack{
                Text("Address input")
                    .font(.title3)
                    .fontWeight(.medium)
                Spacer()
            }
            HStack{
                Text("Enter the address for your property then pick one of the suggested options")
                    .font(.headline)
                    .fontWeight(.light)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            TextInputField(placeholderText: "Locate your property", binding: $mapSearch.searchTerm, showError: vm.addressInputError, focusField: .address)
                .padding(.vertical)
            
            // auto-complete results
            if vm.mortgage.address != mapSearch.searchTerm {
                List{
                    ForEach(mapSearch.locationResults, id: \.self) { location in
                        Button {
                            performReverseGeoSearch(location: location)
                            locationSheetShowing = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.title)
                                    .font(.footnote)
                                    .foregroundColor(.primary.opacity(0.7))
                                Text(location.subtitle)
                                    .font(.footnote)
                                    .foregroundColor(.primary.opacity(0.5))
                            }
                            //                            .padding(.vertical, 3)
                            //                            .padding(.horizontal, 2)
                            //                            .frame(maxWidth: .infinity, alignment: .leading)
                            //                            .cornerRadius(4)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            Spacer()
        }
        .padding()
    }
    
    private var LocationInput: some View {
        VStack(alignment: .leading) {
            InputFieldCaption(captionText: "ADDRESS")
            
            Map(coordinateRegion: $vm.mapRegion,
                showsUserLocation: true,
                annotationItems: vm.markers) { marker in
                marker.location
            }
                .onAppear{
                    mapSearch.searchTerm = vm.mortgage.address
                }
                .aspectRatio(2, contentMode: ContentMode.fill)
                .frame(maxHeight: 200)
                .cornerRadius(10)
            
            if(vm.mortgage.address != ""){
                Text(vm.mortgage.formattedAddressString)
                    .font(.footnote)
            }
            
            HStack{
                Spacer()
                HStack{
                    Button {
                        locationSheetShowing = true
                    } label: {
                        HStack{
                            Text("Set the location")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }
                }
                .foregroundColor(.primary)
                .colorInvert()
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Color.primary)
                .cornerRadius(10)
                Spacer()
            }
        }
        .padding()
    }
    
    private var PropertyValueInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "PROPERTY VALUE")
            HStack{
                HStack{
                    Text("Enter the home value: ")
                }
                Spacer()
                HStack{
                    Text("$")
                        .font(.subheadline)
                    DoubleNumberInputField(placeholderText: "", binding: $vm.mortgage.propertyValue, showError: vm.propertyValueError, focusField: .propertyValue)
                }
            }
        }
    }
    
    private var DownPaymentInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "DOWN PAYMENT")
            VStack{
                HStack{
                    HStack{
                        Text("Choose the downpayment: ")
                    }
                    Spacer()
                    HStack{
                        Text("$")
                            .font(.subheadline)
                        DoubleNumberInputField(placeholderText: "", binding: $vm.mortgage.downpaymentValue, showError: vm.downpaymentValueError, focusField: .downpaymentValue)
                    }
                }
                HStack{
                    Slider(
                        value: $vm.downpaymentPercentageSelector,
                        in: RANGE_START_DOWNPAYMENT...RANGE_END_DOWNPAYMENT,
                        step: 0.1
                    )
                    Spacer()
                    DoubleNumberInputFieldSmall(placeholderText: "", binding: $vm.downpaymentPercentageSelector, showError: vm.downpaymentPercentError, focusField: .downpaymentPercentage)
                    Text("%")
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var InterestRatePercentageInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "INTEREST RATE")
            VStack{
                HStack{
                    HStack{
                        Text("Select the interest rate: ")
                            .padding(.top)
                    }
                    Spacer()
                }
                HStack{
                    Slider(
                        value: $vm.mortgage.interestRatePercentage,
                        in: RANGE_START_INTEREST_RATE...RANGE_END_INTEREST_RATE,
                        step: 0.01
                    )
                    Spacer()
                    DoubleNumberInputFieldSmall(placeholderText: "", binding: $vm.mortgage.interestRatePercentage, showError: vm.interestRatePercentageError, focusField: .interestRate)
                    Text("%")
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var LoanTermInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "LOAN TERM")
            HStack{
                HStack{
                    Text("Set the term of the loan: ")
                }
                Spacer()
                HStack{
                    SmallNumberInputField(placeholderText: "", binding: $vm.mortgage.loanTermYears, showError: vm.loanTermValueError, focusField: .loanTerm)
                    Text("years")
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var InsuranceInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "INSURANCE (Annual)")
            HStack{
                HStack{
                    Text("Add home owner's insurance: ")
                }
                Spacer()
                HStack{
                    Text("$")
                        .font(.subheadline)
                    DoubleNumberInputFieldSmall(placeholderText: "", binding: $vm.mortgage.homeInsuranceValue, showError: false, focusField: .homeInsurance)
                }
            }
        }
    }
    
    private var TaxInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "TAX (Annual)")
            VStack{
                HStack{
                    HStack{
                        Text("Factor in property tax: ")
                    }
                    Spacer()
                    HStack{
                        Text("$")
                            .font(.subheadline)
                        DoubleNumberInputField(placeholderText: "", binding: $vm.mortgage.propertyTaxValue, showError: false, focusField: .propertyTaxValue)
                    }
                }
                HStack{
                    Slider(
                        value: $vm.propertyTaxPercentageSelector,
                        in: RANGE_START_PROPERTY_TAX...RANGE_END_PROPERTY_TAX,
                        step: 0.01
                    )
                    Spacer()
                    DoubleNumberInputFieldSmall(placeholderText: "", binding: $vm.propertyTaxPercentageSelector, showError: false, focusField: .propertyTaxPercentage)
                    Text("%")
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var ClosingCostsInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "CLOSING COSTS")
            HStack{
                HStack{
                    Text("Consider any closing costs: ")
                }
                Spacer()
                HStack{
                    Text("$")
                        .font(.subheadline)
                    DoubleNumberInputFieldMedium(placeholderText: "", binding: $vm.mortgage.closingCostValue, showError: false, focusField: .closingCost)
                }
            }
        }
    }
    
    private var HoaInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "HOA (Annual)")
            VStack{
                HStack{
                    HStack{
                        Text("Tally up HOA fees: ")
                    }
                    Spacer()
                    HStack{
                        Text("$")
                            .font(.subheadline)
                        DoubleNumberInputField(placeholderText: "", binding: $vm.mortgage.hoaFeesValue, showError: false, focusField: .hoaFees)
                    }
                }
            }
        }
    }
    
    private var UpkeepInput: some View {
        VStack(alignment: .leading){
            InputFieldCaption(captionText: "UPKEEP (Annual)")
            VStack{
                HStack{
                    HStack{
                        Text("Include upkeep costs: ")
                    }
                    Spacer()
                    HStack{
                        Text("$")
                            .font(.subheadline)
                        DoubleNumberInputField(placeholderText: "", binding: $vm.mortgage.upkeepValue, showError: false, focusField: .upkeepCost)
                    }
                }
            }
        }
    }
    
    private var CreateButton: some View {
        Button {
            do{
                try vm.save()
                if(!vm.errorPresented){
                    dismiss()
                }
            } catch {
                print("[EMM] -- saving mortgage -- error: \(error)")
            }
        } label: {
            HStack(alignment: .center){
                Spacer()
                Image(systemName: vm.isNew ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.headline)
                    .bold()
                Text(vm.isNew ? "Create" : "Save")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            .padding()
            .background(Material.thin)
            .cornerRadius(10)
            .shadow(radius: 1)
        }
    }
    
    private var DeleteButton: some View {
        Button {
            do{
                // TODO: Pop to home navigation view
                dismiss()
                dismiss()
                try vm.delete()
            } catch {
                print("[EMM] -- error deleting -- \(error)")
            }
        } label: {
            HStack(alignment: .center){
                Spacer()
                Image(systemName: "trash")
                    .foregroundColor(.primary)
                    .colorInvert()
                    .font(.headline)
                    .bold()
                Text("Delete")
                    .foregroundColor(.primary)
                    .colorInvert()
                    .font(.title3)
                    .bold()
                Spacer()
            }
            .padding()
            .background(Color.red)
            .cornerRadius(10)
            .shadow(radius: 1)
        }
        .padding(.bottom, BOTTOM_PADDING)
    }
}

extension CreateMortgageView {
    
    private enum Field: Int, CaseIterable {
        case name, address, propertyValue, downpaymentValue, downpaymentPercentage, interestRate, loanTerm, homeInsurance, propertyTaxValue, propertyTaxPercentage, closingCost, hoaFees, upkeepCost
    }
    
    private func focusPreviousField(){
        focusedField = focusedField.map {
            Field(rawValue: $0.rawValue - 1) ?? .upkeepCost
        }
    }
    private func focusNextField(){
        focusedField = focusedField.map {
            Field(rawValue: $0.rawValue + 1) ?? .name
        }
    }
    
    private func canFocusPreviousField() -> Bool {
        guard let currentFocusedField = focusedField else {
            return false
        }
        return currentFocusedField.rawValue > 0
    }
    private func canFocusNextField() -> Bool {
        guard let currentFocusedField = focusedField else {
            return false
        }
        return currentFocusedField.rawValue < Field.allCases.count - 1
    }
    
    private func performReverseGeoSearch(location: MKLocalSearchCompletion) -> Void {
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
                    
                    vm.mortgage.address = "\(reversedGeoLocation.streetNumber) \(reversedGeoLocation.streetName)"
                    vm.mortgage.city = "\(reversedGeoLocation.city)"
                    vm.mortgage.state = "\(reversedGeoLocation.state)"
                    vm.mortgage.zip = "\(reversedGeoLocation.zipCode)"
                    
                    mapSearch.searchTerm = vm.mortgage.address
                    vm.updateMap()
                }
            }
        }
    }
}


struct CreateMortgageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack{
            let preview = MortgagesProvider.shared
            CreateMortgageView(vm: .init(provider: preview))
                .environment(\.managedObjectContext, preview.viewContext)
        }
    }
}
