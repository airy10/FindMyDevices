//
//  HomeAssistantSettings.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 11/02/2024.
//

import SwiftUI

struct HomeAssistantSettings {
    @AppStorage("homeassistant_enabled")  var enabled = false
    @AppStorage("homeassistant_endpoint") var endpoint: String = "http://homeassistant.local:8123"
    @AppStorage("homeassistant_token") var token: String = ""
}

struct HomeAssistantSettingsView: View {

    @State
    var settings = HomeAssistantSettings()

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Enabled", isOn: $settings.enabled)
            TextField("http://homeassistant.local:8123", text: $settings.endpoint)
                .textContentType(.URL)
            TextField("<access token>", text: $settings.token)
        }
    }
}

#Preview {
    HomeAssistantSettingsView()
}
