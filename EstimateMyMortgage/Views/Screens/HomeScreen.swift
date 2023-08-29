//
//  HomeScreen.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/24/23.
//

import SwiftUI

struct HomeScreen: View {
    
    @FetchRequest(fetchRequest: Mortgage.all()) private var mortgageList
    @ObservedObject var vm: HomeScreenViewModel
    
    
    var body: some View {
        NavigationStack{
            VStack{
                if mortgageList.isEmpty {
                    NoMortgagesView()
                } else{
                    List {
                        ForEach(mortgageList) { mortgage in
                            ZStack{
                                MortgageRowView(vm: .init(mortgage: mortgage))
                                    .contextMenu{
                                        Button {
                                            withAnimation(.easeInOut){
                                                vm.mortgageToEdit = mortgage
                                            }
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button {
                                            do {
                                                try vm.delete(mortgage)
                                            } catch {
                                                print("[EMM] -- error deleting: \(error)")
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .padding(.bottom, 5)
                                NavigationLink {
                                    MortgageScreen(vm: .init(mortgage: mortgage, provider: vm.provider))
                                } label: {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false, content: {
                                Button {
                                    withAnimation(.easeInOut){
                                        vm.mortgageToEdit = mortgage
                                    }
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                        .tint(Material.thinMaterial)
                                }
                                
                            })
                            .swipeActions(allowsFullSwipe: false){
                                Button(role: .destructive) {
                                    do {
                                        try vm.delete(mortgage)
                                    } catch {
                                        print("[EMM] -- delete error: \(error)")
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button{
                        let newEmpty = Mortgage.empty(context: vm.provider.newContext)
                        withAnimation(.easeInOut){
                            vm.mortgageToEdit = newEmpty
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title)
                    }
                }
            }
            .sheet(item: $vm.mortgageToEdit, onDismiss: {
                withAnimation(.easeInOut){
                    vm.mortgageToEdit = nil
                }
            }, content: { mortgage in
                NavigationStack {
                    CreateMortgageView(vm: .init(provider: vm.provider, mortgage: mortgage))
                }
            })
            .navigationTitle("Mortgage Estimates")
        }
    }
}


extension HomeScreen {
    
    private var AddNewButton: some View {
        Button {
            withAnimation(.easeInOut){
                vm.mortgageToEdit = Mortgage.empty(context: vm.provider.newContext)
            }
        } label: {
            HStack{
                Image(systemName: "plus.circle.fill")
                Text("Create New")
                    .fontWeight(.bold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundColor(.primary)
            .colorInvert()
            .background(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 2)
        }
        
    }
}

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        let preview = MortgagesProvider.shared
        HomeScreen(vm: .init(provider: preview))
            .environment(\.managedObjectContext, preview.viewContext)
            .previewDisplayName("Mortgages with data")
            .onAppear{
                Mortgage.makePreview(count: 10, in: preview.viewContext)
            }
        
        let emptyPreview = MortgagesProvider.shared
        HomeScreen(vm: .init(provider: emptyPreview))
            .environment(\.managedObjectContext, emptyPreview.viewContext)
            .previewDisplayName("Mortgages without data")
    }
}
