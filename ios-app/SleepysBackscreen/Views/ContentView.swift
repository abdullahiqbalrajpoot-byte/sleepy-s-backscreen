import SwiftUI

struct ContentView: View {
    @ObservedObject var bleManager = BLEManager.shared

    var body: some View {
        ZStack {
            Color(red: 0.024, green: 0.024, blue: 0.059)
                .ignoresSafeArea()

            WebViewContainer()
                .ignoresSafeArea(.all, edges: .bottom)
        }
        .preferredColorScheme(.dark)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
