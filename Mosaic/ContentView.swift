//
//  ContentView.swift
//  Mosaic
//
//  Created by Sheldon Xu on 11/05/2025.
//

import SwiftUI

struct ContentView: View {
    // Remove the empty init()
    var body: some View {
        ScanningView()
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello Preview Test")
    }
}
#endif
