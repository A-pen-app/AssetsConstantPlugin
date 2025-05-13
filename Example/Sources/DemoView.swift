//
//  DemoView.swift
//  AssetsConstantPlugin
//
//  Created by 李品毅 on 2025/5/13.
//

import SwiftUI

public struct DemoView: View { 
    public var body: some View {
        VStack(spacing: 20) {
            Image(appImage: .checkCircle)
                .resizable()
                .frame(width: 40, height: 40)

            Image(appImage: .close)
                .resizable()
                .frame(width: 40, height: 40)

            Image(appImage: .coins)
                .resizable()
                .frame(width: 40, height: 40)
        }
        .padding()
    }
}

#Preview {
    DemoView()
}

