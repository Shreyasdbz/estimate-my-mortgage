//
//  NoMortgagesView.swift
//  EstimateMyMortgage
//
//  Created by Shreyas Sane on 8/26/23.
//

import SwiftUI

struct NoMortgagesView: View {
    var body: some View {
        HStack(alignment: .center){
            VStack(spacing: 30){
                VStack{
                    Text("Seems a little empty down here")
                    Text("🥲")
                }
                .font(.title2)
                .fontWeight(.light)
                VStack{
                    Text("Use the '+' button at the top to add")
                    Text("a new mortgage estimate")
                }
                .font(.headline)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 200)
        .frame(maxWidth: .infinity)
    }
}

struct NoMortgagesView_Previews: PreviewProvider {
    static var previews: some View {
        NoMortgagesView()
    }
}
