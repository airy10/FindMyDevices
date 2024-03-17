//
//  DevicesManager.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 07/02/2024.
//

import Foundation
import CryptoKit
import SwiftUI
import MQTTNIO
import NIOCore

class DevicesManager : ObservableObject {

    @State
    var homeassistantSettings = HomeAssistantSettings()

    @State
    var mqttSettings = MQTTSettings() {
        didSet {
            mqttSettingsDidChange()
        }
    }

    var disableNotification = true

    var mqttClient : MQTTClient? = nil

    enum Error: Swift.Error {
        case invalidFileFormat
        case invalidPlistFormat
        case invalidDecryptedData
        case noPassword
        case invalidItem
        case keychainError(status: OSStatus)
    }

    static private let RootRecordDirURL : URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("com.apple.icloud.searchpartyd")
    }()
    static private let OwnedBeaconsDir =  "OwnedBeacons"
    static private let BeaconProductInfoRecordDir =  "BeaconProductInfoRecord"
    static private let BeaconEstimatedLocationDir =  "BeaconEstimatedLocation"
    static private let BeaconNamingRecordDir =  "BeaconNamingRecord"

    static private let OwnedBeaconsDirURL : URL = {
        RootRecordDirURL.appendingPathComponent(DevicesManager.OwnedBeaconsDir)
    }()
    static private let BeaconProductInfoRecordDirURL : URL = {
        RootRecordDirURL.appendingPathComponent(DevicesManager.BeaconProductInfoRecordDir)
    }()
    static private let BeaconEstimatedLocationDirURL : URL = {
        RootRecordDirURL.appendingPathComponent(DevicesManager.BeaconEstimatedLocationDir)
    }()
    static private let BeaconNamingRecordDirURL : URL = {
        RootRecordDirURL.appendingPathComponent(DevicesManager.BeaconNamingRecordDir)
    }()

    private var key : SymmetricKey? = nil

    private var devicesDict : [String : Device] = [:]

    @Published
    var devices = [Device]()

    var dirMonitor : DirectoryMonitor? = nil

    init() {
        self.loadDevices()
        disableNotification = false

        for device in devices {
            print("\(device.id) : \(device.label) - \(device.timestamp?.formatted() ?? "")")
        }

        Task {
            for device in devices {
                await notifyChange(device: device)
            }
        }
    }

    deinit {
        dirMonitor?.stop()
    }

    private func device(id: String) ->  Device?
    {
        return devicesDict[id]
    }

    private func loadKey() -> Bool {
        if key == nil {
            // -> Hex format key from `security find-generic-password -l 'BeaconStore' -w`
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                        kSecAttrLabel as String: "BeaconStore",
                                        kSecMatchLimit as String: kSecMatchLimitOne,
                                        kSecReturnAttributes as String: true,
                                        kSecReturnData as String: true]

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess {
                if let existingItem = item {
                    if let keyData = existingItem[kSecValueData as String] as? Data {
                        key = SymmetricKey(data: keyData)
                    }
                }
            }
        }
        return key != nil
    }

    func processOwnedBeacon(_ record: [String: Any]) {
        guard let identifier = record["identifier"] as? String else { return }

        let model = record["model"] as? String
        let pairingDate = record["pairingDate"] as? Date

        if let device = self.device(id: identifier) {
            device.model = model
            device.pairingDate = pairingDate

            if !disableNotification {
                print("Own beacon changed : \(device)")
            }
        } else {
            self.objectWillChange.send()

            let device = Device(identifier: identifier, model: model, pairingDate: pairingDate)
            self.devicesDict[identifier] = device
            self.devices.append(device)
        }
    }

    func processOwnedBeacon(url: URL? = nil) {
        let url = url ??  DevicesManager.OwnedBeaconsDirURL

        processRecord(url: url) {
            self.processOwnedBeacon($0)
        }
    }

    func processBeaconProductInfoRecord(_ record: [String: Any]) {
        guard let identifier = record["identifier"] as? String else { return }
        guard let device = self.device(id: identifier) else { return }

        let manufacturerName = record["manufacturerName"] as? String
        let modelName = record["modelName"] as? String

        device.manufacturerName = manufacturerName
        device.modelName = modelName

        if !disableNotification {
            print("Product info changed : \(device)")
        }

    }

    func processBeaconProductInfoRecord(url: URL? = nil) {
        let url = url ??  DevicesManager.BeaconProductInfoRecordDirURL

        processRecord(url: url) {
            self.processBeaconProductInfoRecord($0)
        }
    }

    func processBeaconNamingRecord(_ record: [String: Any]) {
        guard let identifier = record["associatedBeacon"] as? String else { return }
        guard let device = self.device(id: identifier) else { return }

        let name = record["name"] as? String
        let emoji = record["emoji"] as? String

        device.name = name
        device.emoji = emoji

        if !disableNotification {
            print("Naming changed : \(device)")
        }

    }

    func processBeaconNamingRecord(url: URL? = nil) {
        let url = url ??  DevicesManager.BeaconNamingRecordDirURL

        processRecord(url: url) {
            self.processBeaconNamingRecord($0)
        }
    }

    func processBeaconEstimatedLocation(_ record: [String: Any]) {
        guard let identifier = record["associatedBeacon"] as? String else { return }
        guard let device = self.device(id: identifier) else { return }

        guard let timestamp = record["timestamp"] as? Date else { return }

        if let currentDeviceTimestamp = device.timestamp {
            if timestamp <= currentDeviceTimestamp {
                return
            }
        }

        let latitude = record["latitude"] as? Double
        let longitude = record["longitude"] as? Double
        let horizontalAccuracy = record["horizontalAccuracy"] as? Double
        let scanDate = record["scanDate"] as? Date

        device.latitude = latitude
        device.longitude = longitude
        device.horizontalAccuracy = horizontalAccuracy
        device.scanDate = scanDate
        device.timestamp = timestamp

        self.locationChangedFor(device: device)
    }

    func locationChangedFor(device: Device) {
        if disableNotification {
            return
        }

        let id = device.identifier.uppercased()
        print("Location changed : \(id) : \(device.label) - \(device.timestamp?.formatted() ?? "")")

        Task {
            await notifyChange(device: device)
        }
    }

    func updateMQTT(device: Device) async {
        if mqttSettings.enabled == false || mqttSettings.server.count == 0 {
            return
        }

        let id = device.identifier.uppercased()

        if mqttSettings.server != mqttClient?.host ||
            mqttSettings.port != mqttClient?.port ||
            mqttSettings.user != mqttClient?.configuration.userName ||
            mqttSettings.password != mqttClient?.configuration.password  {

            try? mqttClient?.syncShutdownGracefully()
            mqttClient = nil
        }

        if mqttClient == nil {
            mqttClient = MQTTClient(
                host: mqttSettings.server,
                port: mqttSettings.port,
                identifier: "FindMyDevices",
                eventLoopGroupProvider: .createNew,
                configuration: MQTTClient.Configuration(userName: mqttSettings.user, password: mqttSettings.password)
            )
            if let client = mqttClient {
                do {
                    try await client.connect()
                    print("Connected")
                }
                catch let error as MQTTError  {
                    print("Error : \(error)")
                    try? mqttClient?.syncShutdownGracefully()
                    mqttClient = nil
                    return
                }
                catch {
                    print("Unknown error")
                    try? mqttClient?.syncShutdownGracefully()
                    mqttClient = nil
                    return
                }
            } else {
                print("Invalid client")
            }

        }

        let deviceId = "FMD_" + id
        let deviceTopic = "homeassistant/device_tracker/" + deviceId + "/"

        let topic = deviceTopic + "config"

        // Create the device (could be done only once - and should be only done if autodiscovery is enabled)
        var deviceInfo : [String : Any] = [
            "identifiers": [deviceId],
            "name": device.label,
        ]

        if let manufacturerName = device.manufacturerName {
            deviceInfo["manufacturer"] = manufacturerName
        }
        if let version = device.version {
            deviceInfo["sw_version"] = version
        }
        if let model = device.model {
            deviceInfo["model"] = model
        } else if let model = device.modelName {
            deviceInfo["model"] = model
        }

        let deviceConfig : [String: Any] = [
            "state_topic": deviceTopic + "state",
            "json_attributes_topic": deviceTopic + "attributes",
            "device": deviceInfo,
            "payload_reset" : "reset",
            "unique_id": deviceId
        ]
        if let deviceConfigData = try? JSONSerialization.data(withJSONObject: deviceConfig, options: .withoutEscapingSlashes) {
            do {
                try await mqttClient?.publish(to: topic, payload: ByteBuffer(data: deviceConfigData), qos: .atLeastOnce, retain: true)
            }
            catch let error as MQTTError  {
                print("Error : \(error)")
                try? mqttClient?.syncShutdownGracefully()
                mqttClient = nil
            }
            catch {
                print("Unknown error")
                try? mqttClient?.syncShutdownGracefully()
                self.mqttClient = nil
            }
        } else {
            print("Can't encode message : \(deviceConfig)")
        }

        var location : [String: Any] = [
            "provider-url": "https://github.com/airy10/FindMyDevices",
            "provider": "FindMyDevices",
            "via_device": "FindMyDevices",
        ]
        if let latitude = device.latitude, let longitude = device.longitude {
            location["latitude"] = latitude
            location["longitude"] = longitude
        }

        if let accuracy = device.horizontalAccuracy {
            location["gps_accuracy"] = accuracy
        }
        if let timestamp = device.timestamp {
            location["last_update"] = timestamp.ISO8601Format()
            location["last_update_timestamp"] = timestamp.timeIntervalSince1970
        }
        if let battery = device.battery {
            location["battery"] = battery
        }

        if let locationData = try? JSONSerialization.data(withJSONObject: location, options: .withoutEscapingSlashes) {
            do {
                try await mqttClient?.publish(to: deviceTopic + "attributes", payload: ByteBuffer(data: locationData), qos: .atLeastOnce, retain: true)

            }
            catch let error as MQTTError  {
                print("Error : \(error)")
                try? mqttClient?.syncShutdownGracefully()
                mqttClient = nil
            }
            catch {
                print("Unknown error")
                try? mqttClient?.syncShutdownGracefully()
                mqttClient = nil
            }
        }

       // _ = mqttClient?.publish(to: deviceTopic + "state", payload: ByteBuffer(string: "reset"), qos: .atLeastOnce, retain: true)
    }

    func updateHomeAssistant(device: Device) async {
        if homeassistantSettings.enabled == false || homeassistantSettings.endpoint.count == 0 || homeassistantSettings.token.count == 0 {
            return
        }

        let id = device.identifier.uppercased()

        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(
            configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        guard let URL = URL(string: homeassistantSettings.endpoint + "/api/services/device_tracker/see") else { return }
        var request = URLRequest(url: URL)
        request.httpMethod = "POST"

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer " + homeassistantSettings.token, forHTTPHeaderField: "Authorization")

        let dev_id = "findmy_" + id.replacingOccurrences(of: "-", with: "")
        var attributes: [String: Any] = [
            "dev_id": dev_id,
            "mac": "FINDMY_" + id.uppercased(),
            "host_name": "FindMyDevices",
        ]
        if let latitude = device.latitude, let longitude = device.longitude {
            attributes["gps"] = [
                latitude,
                longitude,
            ]
        }
        if let accuracy = device.horizontalAccuracy {
            attributes["gps_accuracy"] = accuracy
        }

        if let battery = device.battery {
            attributes["battery"] = battery
        }

        let jsonData = try! JSONSerialization.data(
            withJSONObject: attributes, options: [])

        request.httpBody = jsonData
        do {
            let (_, response) = try await session.data(
                for: request
            )

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200  {
                    print("[" + id + "] Data sent: HTTP \(httpResponse.statusCode)")
                }
            }
        }
        catch {
            print("[" + id + "] Data send error")
        }
    }

    func notifyChange(device: Device) async {

        await updateHomeAssistant(device: device)
        await updateMQTT(device: device)

    }

    func processBeaconEstimatedLocation(url: URL? = nil) {
        let url = url ??  DevicesManager.BeaconEstimatedLocationDirURL

        processRecord(url: url) {
            self.processBeaconEstimatedLocation($0)
        }
    }

    func processRecord(url: URL, code: @escaping ([String: Any]) -> Void) {
        guard let decryptKey = self.key else { return }

        if url.isDirectory {
            if let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                urls.forEach {
                    processRecord(url: $0, code: code)
                }
            }
        } else {
            guard let record = try? decryptRecordFile(fileURL: url, key: decryptKey) else { return }

            // Ensure the change is done in the main thread as this is observed by the UI
            if Thread.isMainThread {
                code(record)
            } else {
                DispatchQueue.main.async {
                    code(record)
                }
            }
        }
    }

    func mqttSettingsDidChange() {
        print("mqttSettingsDidChange")
        try? mqttClient?.syncShutdownGracefully()
        self.mqttClient = nil
    }

    func loadDevices() {
        if key == nil {
            _ = loadKey()
        }
        guard self.key != nil else { return }

        dirMonitor = DirectoryMonitor(dir: DevicesManager.RootRecordDirURL, queue: DispatchQueue.global(qos: .default)) {
            self.processFileChange(url: $0, flags: $1)
        }

        _ = dirMonitor?.start()

        processOwnedBeacon()
        processBeaconNamingRecord()
        processBeaconProductInfoRecord()
        processBeaconEstimatedLocation()
    }

    func processFileChange(url: URL, flags: FSEventStreamEventFlags) {
        switch url {
        case _ where url.path().hasPrefix(DevicesManager.BeaconNamingRecordDirURL.path()):
            processBeaconNamingRecord(url: url)
        case _ where url.path().hasPrefix(DevicesManager.BeaconEstimatedLocationDirURL.path()):
            processBeaconEstimatedLocation(url: url)
        case _ where url.path().hasPrefix(DevicesManager.OwnedBeaconsDirURL.path()):
            processOwnedBeacon(url: url)
        case _ where url.path().hasPrefix(DevicesManager.BeaconProductInfoRecordDirURL.path()):
            processBeaconProductInfoRecord(url: url)
        default:
            break
        }
    }

    // Function to decrypt using AES-GCM
    func decryptRecordFile(fileURL: URL, key: SymmetricKey) throws -> [String: Any] {
        // Read data from the file
        let data = try Data(contentsOf: fileURL)

        // Convert data to a property list (plist)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [Any] else {
            throw Error.invalidFileFormat
        }

        // Extract nonce, tag, and ciphertext
        guard plist.count >= 3,
              let nonceData = plist[0] as? Data,
              let tagData = plist[1] as? Data,
              let ciphertextData = plist[2] as? Data else {
            throw Error.invalidPlistFormat
        }

        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonceData), ciphertext: ciphertextData, tag: tagData)

        // Decrypt using AES-GCM
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        // Convert decrypted data to a property list
        guard let decryptedPlist = try PropertyListSerialization.propertyList(from: decryptedData, options: [], format: nil) as? [String: Any] else {
            throw Error.invalidDecryptedData
        }

        return decryptedPlist
    }
}
