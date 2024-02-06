//
//  MenuItem.swift
//  VoltixApp
//
//  Created by Mac on 05.02.2024.
//

import SwiftUI

struct MenuItem: View {
    let content: String;
    
    var body: some View {
        HStack {
            Spacer()
            Text(content)
            .font(Font.custom("Menlo", size: 35).weight(.bold))
            .lineSpacing(60)
            .foregroundColor(.black);
            Spacer().frame(width: 20)
            Image(systemName: "chevron.right")
            .resizable()
            .frame(width: 18, height: 27)
        }
        .padding()
        .frame(height: 70)
    }
}

#Preview {
    MenuItem(content: "VAULT RECOVERY")
}