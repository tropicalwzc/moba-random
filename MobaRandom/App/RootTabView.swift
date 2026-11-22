import SwiftUI
import UIKit

struct RootTabView: View {
    @AppStorage("moba_selected_tab") private var selectedTab = "grouping"

    private var selection: Binding<String> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                // Resign before SwiftUI swaps the tab content. The grouping
                // tab owns a TextEditor, and building the BO3 board while its
                // keyboard is still up triggers a layout loop.
                if newValue == "bo3" {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            Tab("随机", systemImage: "person.3.fill", value: "grouping") {
                ContentView()
            }

            Tab("BO3", systemImage: "flag.2.crossed.fill", value: "bo3") {
                Bo3DraftView()
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .onAppear {
            if selectedTab != "grouping" && selectedTab != "bo3" {
                selectedTab = "grouping"
            }
        }
    }
}
