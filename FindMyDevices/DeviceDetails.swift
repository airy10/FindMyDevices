//
//  DeviceDetails.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 09/02/2024.
//

import SwiftUI

struct DeviceDetails: View {
    @ObservedObject
    var device: Device

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                if let emoji = device.emoji {
                    Text(emoji).font(.system(.title))
                }
                if let name = device.name {
                    Text(name).font(.system(.title))
                }
            }
            VStack(alignment: .leading) {
                if let manufacturerName = device.manufacturerName {
                    HStack {
                        Text("Manufacturer:").frame(width: 150, alignment: .trailing)
                        Text("\(manufacturerName)")
                    }
                }
                if let modelName = device.modelName {
                    HStack {
                        Text("Model Name:").frame(width: 150, alignment: .trailing)
                        Text("\(modelName)")
                    }
                } else if let model = device.model {
                    HStack {
                        Text("Model:").frame(width: 150, alignment: .trailing)
                        Text("\(model)")
                    }
                }
                if let time = device.timestamp?.formatted(), let lat = device.latitude, let long = device.longitude {
                    HStack {
                        Text("Time:").frame(width: 150, alignment: .trailing)
                        Text("\(lat)")
                    }
                    HStack {
                        Text("Latitude:").frame(width: 150, alignment: .trailing)
                        Text("\(lat)")
                    }
                    HStack {
                        Text("Longitude:").frame(width: 150, alignment: .trailing)
                        Text("\(long)")
                    }
                    HStack {
                        Text("Date:").frame(width: 150, alignment: .trailing)
                        Text("\(time)")
                    }
                }
            }.scaledToFill()
            Text(device.identifier)
                .font(.system(size: 9))

        }
    }
}

#Preview {
    //    DeviceDetails(device: $nil)
    Button("") {}
}

