//
//  HomeAssistantSettings.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 11/02/2024.
//

import SwiftUI

struct HomeAssistantSettingsView: View {

    @AppStorage("homeassistant_enabled") private var trackerEnabled = false
    @AppStorage("homeassistant_endpoint") var endpoint: String = "http://homeassistant.local:8123"
    @AppStorage("homeassistant_token") var token: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Enabled", isOn: $trackerEnabled)
            TextField("http://homeassistant.local:8123", text: $endpoint)
            TextField("<access token>", text: $token)
        }
    }
}

#Preview {
    HomeAssistantSettingsView()
}
