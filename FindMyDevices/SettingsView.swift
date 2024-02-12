//
//  SettingsView.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 11/02/2024.
//

import SwiftUI

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general
        case homeassistant
    }

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            HomeAssistantSettingsView()
                .tabItem {
                    Label("Home Assistant", image: "HALogo")
                    }
                .tag(Tabs.homeassistant)
        }
        .padding(20)
        .frame(minWidth: 350, minHeight: 100)
    }
}

#Preview {
    SettingsView()
}
