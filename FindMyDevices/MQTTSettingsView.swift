//
//  MQTTSettingsView.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 14/02/2024.
//

import SwiftUI

struct MQTTSettings {
    @AppStorage("mqtt_enabled") var enabled = false
    @AppStorage("mqtt_server") var server: String = ""
    @AppStorage("mqtt_port") var port: Int = 1883
    @AppStorage("mqtt_user") var user: String = ""
    @AppStorage("mqtt_password") var password: String = ""
}


struct MQTTSettingsView: View {
    @State
    var settings = MQTTSettings()

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Enabled", isOn: $settings.enabled)
            TextField("192.168.1.200", text: $settings.server)
            TextField("1883", value: $settings.port, formatter: NumberFormatter())
            TextField("user", text: $settings.user)
                .textContentType(.username)
            SecureField("password", text: $settings.password)
                .textContentType(.password)
        }
    }
}

#Preview {
    MQTTSettingsView()
}
