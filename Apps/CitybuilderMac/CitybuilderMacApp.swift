import SwiftUI

@main
struct CitybuilderMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Citybuilder Mac")
            .font(.largeTitle)
            .padding()
            .frame(minWidth: 800, minHeight: 600)
    }
}
