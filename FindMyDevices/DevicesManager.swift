//
//  DevicesManager.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 07/02/2024.
//

import Foundation
import CryptoKit
import SwiftUI


class DevicesManager : ObservableObject {

    @AppStorage("homeassistant_enabled") var ha_enabled: Bool = false
    @AppStorage("homeassistant_endpoint") var ha_endpoint: String = "http://homeassistant.local:8123"
    @AppStorage("homeassistant_token") var ha_token: String = ""

    var disableNotification = true

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
            print(device)
            if device.timestamp != nil {
                notifyChange(device: device)
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
            processOwnedBeacon($0)
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
            processBeaconProductInfoRecord($0)
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
            processBeaconNamingRecord($0)
        }
    }

    func processBeaconEstimatedLocation(_ record: [String: Any]) {
        guard let identifier = record["associatedBeacon"] as? String else { return }
        guard let device = self.device(id: identifier) else { return }

        guard let timestamp = record["timestamp"] as? Date else { return }

        if let currentTimestamp = device.timestamp {
            if timestamp.compare(currentTimestamp) == .orderedAscending {
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

        locationChangedFor(device: device)

    }

    func locationChangedFor(device: Device) {
        if disableNotification {
            return
        }

        guard let _ = device.latitude, let _ = device.longitude else { return }
        let id = device.identifier.uppercased()
        print("Location changed : \(id) : \(device.label) - \(device.timestamp?.formatted() ?? "")")

        notifyChange(device: device)
    }

    func notifyChange(device: Device) {

        guard let latitude = device.latitude, let longitude = device.longitude else { return }
        let id = device.identifier.uppercased()

        if ha_enabled == false || ha_endpoint.count == 0 || ha_token.count == 0 {
            return
        }
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(
            configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        guard let URL = URL(string: ha_endpoint + "/api/services/device_tracker/see") else { return }
        var request = URLRequest(url: URL)
        request.httpMethod = "POST"

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer " + ha_token, forHTTPHeaderField: "Authorization")

        let dev_id = "findmy_" + id.replacingOccurrences(of: "-", with: "")
        var bodyObject: [String: Any] = [
            "dev_id": dev_id,
            "gps": [
                latitude,
                longitude,
            ],
            "mac": "FINDMY_" + id.uppercased(),
            "host_name": "FindMyDevices",
        ]

        if let accuracy = device.horizontalAccuracy {
            bodyObject["gps_accuracy"] = accuracy
        }

        #if false
        if let battery = device.battery {
            bodyObject["battery"] = battery
        }
        #endif
        request.httpBody = try! JSONSerialization.data(
            withJSONObject: bodyObject, options: [])

        let task = session.dataTask(
            with: request,
            completionHandler: {
                (data, response, error) in
                if error == nil {
                    let statusCode = (response as! HTTPURLResponse).statusCode
                    if statusCode != 200 {
                        print("[" + id + "] Data sent: HTTP \(statusCode)")
                        //                debugPrint(String(data: data!, encoding: .utf8))
                    }
                } else {
                    print(
                        "[" + id
                        + "] Data error: \(error!.localizedDescription)"
                    )
                }
            })
        task.resume()
        session.finishTasksAndInvalidate()

    }

    func processBeaconEstimatedLocation(url: URL? = nil) {
        let url = url ??  DevicesManager.BeaconEstimatedLocationDirURL

        processRecord(url: url) {
            processBeaconEstimatedLocation($0)
        }
    }

    func processRecord(url: URL, code: ([String: Any]) -> Void) {
        guard let decryptKey = self.key else { return }

        if url.isDirectory {
            if let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                urls.forEach {
                    processRecord(url: $0, code: code)
                }
            }
        } else {
            guard let record = try? decryptRecordFile(fileURL: url, key: decryptKey) else { return }

            code(record)
        }
    }

    func loadDevices() {
        if key == nil {
            _ = loadKey()
        }
        guard self.key != nil else { return }

        dirMonitor = DirectoryMonitor(dir: DevicesManager.RootRecordDirURL, queue: DispatchQueue.main) {
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
