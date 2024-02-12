//
//  Device.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 07/02/2024.
//

import Foundation
import SwiftUI

class Device :  CustomStringConvertible, Hashable, Identifiable, ObservableObject {
    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    let identifier : String

    var id : String {
        return self.identifier
    }

    // From OwnedBeacon
    @Published var model: String?
    @Published var pairingDate : Date? = nil

    // From BeaconProductInfoRecord
    @Published var manufacturerName : String? = nil
    @Published var modelName : String? = nil
    @Published var version : String? = nil
    @Published var iconPath: URL? = nil

    // From BeaconNamingRecord
    @Published var name : String? = nil
    @Published var emoji : String? = nil

    // From BeaconEstimatedLocation
    @Published var horizontalAccuracy: Double? = nil
    @Published var longitude: Double? = nil
    @Published var latitude: Double? = nil
    @Published var timestamp: Date? = nil
    @Published var scanDate: Date? = nil

    @Published var battery: Double? = nil

    var label: String {
        if emoji != nil {
            emoji! + " " + (name ?? (model ?? identifier))
        } else {
            name ?? (model ?? identifier)
        }
    }

    var icon: Image? = nil

    init(identifier: String, model: String?, pairingDate: Date?, manufacturerName: String? = nil, modelName: String? = nil, version: String? = nil, iconPath: URL? = nil, name: String? = nil, emoji: String? = nil, horizontalAccuracy: Double? = nil, longitude: Double? = nil, latitude: Double? = nil, timestamp: Date? = nil, scanDate: Date? = nil, icon: Image? = nil) {
        self.identifier = identifier
        self.model = model
        self.pairingDate = pairingDate
        self.manufacturerName = manufacturerName
        self.modelName = modelName
        self.version = version
        self.iconPath = iconPath
        self.name = name
        self.emoji = emoji
        self.horizontalAccuracy = horizontalAccuracy
        self.longitude = longitude
        self.latitude = latitude
        self.timestamp = timestamp
        self.scanDate = scanDate
        self.icon = icon
    }

    var description: String {
        return "Device \(identifier) model: \(model ?? "") name: \(name  ?? "") emoji: \(emoji  ?? "") manufacturerName: \(manufacturerName  ?? "") modelName: \(modelName  ?? "") latitude: \(latitude  ?? 0) longitude: \(longitude  ?? 0) timestamp : \(String(describing: timestamp)) scanDate : \(String(describing: scanDate))"
    }
}
