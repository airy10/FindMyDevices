//
//  FindMyDevicesApp.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 07/02/2024.
//

import SwiftUI
import Foundation

@main
struct FindMyDevicesApp: App {

    let devicesManager = DevicesManager()

    var body: some Scene {
        WindowGroup {
            ContentView(devicesManager: devicesManager)
        }
        Settings {
            SettingsView()
        }
    }
}
