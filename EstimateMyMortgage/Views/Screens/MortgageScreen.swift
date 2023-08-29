//
//  MortgageScreen.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import SwiftUI
import MapKit

struct MortgageScreen: View {
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: MortgageScreenViewModel
    
    var body: some View {
        ZStack{
            MapLayer
                .ignoresSafeArea()
            VStack{
                Header
                Spacer()
                HStack(alignment: .center){
                    if (!vm.bottomDrawerPresent){
                        ShowDetailsButton
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut){
                    vm.bottomDrawerPresent = true
                }
            }
        }
        .sheet(item: $vm.mortgageToEdit, content: { mortgage in
            NavigationStack{
                CreateMortgageView(vm: .init(provider: vm.provider, mortgage: mortgage))
            }
        })
        .sheet(isPresented: $vm.bottomDrawerPresent) {
            ScrollView{
                SheetView
                    .frame(maxHeight: .infinity)
                Spacer()
            }
            .presentationBackground(Material.thickMaterial)
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(
                .enabled(upThrough: .large)
            )
        }
        .navigationBarBackButtonHidden(true)
    }
}

extension MortgageScreen {
    private var MapLayer: some View {
        Map(coordinateRegion: $vm.mapRegion,
            annotationItems: vm.markers) { mark in
            mark.location
        }
    }
    
    private var Header: some View {
        HStack{
            Button {
                withAnimation(.easeInOut) {
                    vm.bottomDrawerPresent = false
                }
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                    .padding()
            }
            
            Spacer()
            
            Text(vm.mortgage.name)
                .font(.title2)
                .bold()
                .padding()
            if(vm.bottomDrawerPresent != true){
                Spacer()
                Button {
                    withAnimation(.easeInOut) {
                        vm.bottomDrawerPresent = false
                    }
                    vm.mortgageToEdit = vm.mortgage
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                        .padding()
                }
            }
        }
        .background(Material.ultraThin)
        .cornerRadius(10)
        .shadow(radius: 8)
        .padding()
    }
    
    private var ShowDetailsButton: some View {
        Button {
            withAnimation(.easeInOut) {
                vm.bottomDrawerPresent = true
            }
        } label: {
            Text("Show details")
                .font(.title3)
                .bold()
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Material.ultraThick)
                .cornerRadius(10)
                .shadow(radius: 2)
                .padding(.horizontal)
                .padding(.bottom, 15)
        }
    }
    
    private var SheetView: some View {
        VStack{
            HStack{
                Button {
                    withAnimation(.easeInOut){
                        vm.bottomDrawerPresent = false
                    }
                } label: {
                    Text("Dismiss")
                }
                Spacer()
            }
            .padding()
            
            // Montly payment banner
            VStack(spacing: 10) {
                Text("Your monthly payment is: ")
                    .foregroundColor(.primary)
                    .colorInvert()
                    .font(.title3)
                
                Text(vm.mortgage.formattedMonthlyMortgagePayment)
                    .foregroundColor(.primary)
                    .colorInvert()
                    .font(.title2)
                    .bold()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.primary)
            .cornerRadius(10)
            .shadow(radius: 1)
            .padding()
            
            // Details Section
            PropertyDetails
            PaymentDetails
            Spacer()
        }
    }
    
    private var PropertyDetails: some View {
        VStack{
            HStack{
                Text("Property details")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            VStack(spacing: 10){
                Group{
                    DetailRow(key: "Address", primaryValue: vm.mortgage.address, secondaryValue: "")
                    Divider()
                }
                Group{
                    DetailRow(key: "Property value", primaryValue: vm.mortgage.formattedPropertyValue, secondaryValue: "")
                    Divider()
                    DetailRow(key: "Downpayment", primaryValue: vm.mortgage.formattedDownPaymentValue, secondaryValue: vm.mortgage.formattedDownPaymentPercentage)
                    Divider()
                    DetailRow(key: "Closing costs", primaryValue: vm.mortgage.formattedClosingCostValue, secondaryValue: "")
                    Divider()
                    DetailRow(key: "Interest Rate", primaryValue: vm.mortgage.formattedInterestRate, secondaryValue: "")
                    Divider()
                    DetailRow(key: "Loan Term", primaryValue: vm.mortgage.formattedLoanTerm, secondaryValue: "")
                    Divider()
                }
                Group{
                    DetailRow(key: "Homeowner's insurance", primaryValue: vm.mortgage.formattedInsuranceValue, secondaryValue: "")
                    Divider()
                    DetailRow(key: "Property Tax", primaryValue: vm.mortgage.formattedPropertyTaxValue, secondaryValue: vm.mortgage.formattedPropertyTaxPercentage)
                    Divider()
                    DetailRow(key: "HOA Fees", primaryValue: vm.mortgage.formattedHoaFeesValue, secondaryValue: "")
                    Divider()
                    DetailRow(key: "Upkeep / utilities", primaryValue: vm.mortgage.formattedUpkeepValue, secondaryValue: "")
                }
            }
            .padding(20)
            .background(Color.primary.colorInvert())
            .cornerRadius(10)
        }
        .padding()
    }
    
    private var PaymentDetails: some View {
        VStack (spacing: 12){
            HStack{
                Text("Payment breakdown")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            VStack{
                HStack{
                    Text("Loan")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                VStack{
                    DetailRow(key: "Principle", primaryValue: vm.mortgage.formattedPrincipleValue, secondaryValue: "")
                    Divider()
                    DetailRow(key: "Total interest", primaryValue: vm.mortgage.formattedTotalInterestAccrued, secondaryValue: "")
                    Divider()
                    TotalRow(value: vm.mortgage.formattedTotalLoanValue)
                }
                .padding(20)
                .background(Color.primary.colorInvert())
                .cornerRadius(10)
            }
            VStack{
                HStack{
                    Text("Purchase price")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                VStack{
                    DetailRow(key: "Downpayment", primaryValue: vm.mortgage.formattedDownPaymentValue, secondaryValue: "")
                    Divider()
                    DetailRow(key: "Closing costs", primaryValue: vm.mortgage.formattedClosingCostValue, secondaryValue: "")
                    Divider()
                    TotalRow(value: vm.mortgage.formattedPurchasePrice)
                }
                .padding(20)
                .background(Color.primary.colorInvert())
                .cornerRadius(10)
            }
            VStack{
                HStack{
                    Text("Monthly payment (avg)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                VStack{
                    Group{
                        DetailRow(key: "Principle", primaryValue: vm.mortgage.formattedMonthlyPrincipleValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Interest", primaryValue: vm.mortgage.formattedMonthlyInterestValue, secondaryValue: "")
                        Divider()
                    }
                    Group{
                        DetailRow(key: "Property tax", primaryValue: vm.mortgage.formattedMonthlyTaxValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Homeowner's insurance", primaryValue: vm.mortgage.formattedMonthlyInsuranceValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Hoa fees", primaryValue: vm.mortgage.formattedMonthlyHoaFeesValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Upkeep & utilities", primaryValue: vm.mortgage.formattedMonthlyUpkeepValue, secondaryValue: "")
                        Divider()
                        TotalRow(value: vm.mortgage.formattedMonthlyMortgagePayment)
                    }
                }
                .padding(20)
                .background(Color.primary.colorInvert())
                .cornerRadius(10)
            }
            VStack{
                HStack{
                    Text("Yearly cost")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                VStack{
                    Group{
                        DetailRow(key: "Principle", primaryValue: vm.mortgage.formattedYearlyPrincipleValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Interest", primaryValue: vm.mortgage.formattedYearlyInterestValue, secondaryValue: "")
                        Divider()
                    }
                    Group{
                        DetailRow(key: "Property tax", primaryValue: vm.mortgage.formattedYearlyTaxValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Homeowner's insurance", primaryValue: vm.mortgage.formattedYearlyInsuranceValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Hoa fees", primaryValue: vm.mortgage.formattedYearlyHoaFeesValue, secondaryValue: "")
                        Divider()
                        DetailRow(key: "Upkeep & utilities", primaryValue: vm.mortgage.formattedYearlyUpkeepValue, secondaryValue: "")
                        Divider()
                        TotalRow(value: vm.mortgage.formattedYearlyMortgagePayment)
                    }
                }
                .padding(20)
                .background(Color.primary.colorInvert())
                .cornerRadius(10)
            }
        }
        .padding()
    }
}


extension MortgageScreen {
    
    private func DetailRow(key: String, primaryValue: String, secondaryValue: String) -> some View {
        HStack{
            Text(key)
                .fontWeight(.light)
            Spacer()
            HStack{
                if(secondaryValue != ""){
                    Text("(" + secondaryValue + ")")
                        .foregroundColor(.secondary)
                }
                Text(primaryValue)
                    .fontWeight(.medium)
            }
        }
    }
    
    private func TotalRow(value: String) -> some View {
        HStack{
            Text("Total")
                .fontWeight(.bold)
            Spacer()
            Text(value)
                .fontWeight(.bold)
        }
    }
}

struct MortgageScreen_Previews: PreviewProvider {
    static var previews: some View {
        let preview = MortgagesProvider.shared
        MortgageScreen(vm: .init(mortgage: .preview(), provider: preview))
            .environment(\.managedObjectContext, preview.viewContext)
            .onAppear{
                Mortgage.makePreview(count: 1, in: preview.viewContext)
            }
    }
}
