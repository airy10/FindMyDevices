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
        case mqtt
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
            MQTTSettingsView()
                .tabItem {
                    Label("MQTT", image: "MQTTLogo")
                }
                .tag(Tabs.homeassistant)
        }
        .padding(20)
        .frame(minWidth: 300)
    }
}

#Preview {
    SettingsView()
}
