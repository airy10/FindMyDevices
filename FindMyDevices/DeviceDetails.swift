//
//  DeviceDetails.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 09/02/2024.
//

import SwiftUI

struct DeviceDetails: View {
    @Binding
    var device: Device?

    var body: some View {
        if let d = device {
            @ObservedObject
            var dev = d

            VStack {
                HStack {
                    if let emoji = dev.emoji {
                        Text(dev.emoji ?? "").font(.system(.title))
                    }
                    if let name = dev.name {
                        Text(name).font(.system(.title))
                    }
                }
                if let manufacturerName = dev.manufacturerName {
                    HStack {
                        Text("Manufacturer:").frame(minWidth: 200, alignment: .trailing)
                        Text("\(manufacturerName)").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .leading)
                    }
                }
                if let modelName = dev.modelName {
                    HStack {
                        Text("Model Name:").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .trailing)
                        Text("\(modelName)").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .leading)
                    }
                } else if let model = dev.model {
                    HStack {
                        Text("Model:").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .trailing)
                        Text("\(model)").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .leading)
                    }
                }
                if let time = dev.timestamp?.formatted(), let lat = dev.latitude, let long = dev.longitude {
                    HStack {
                        Text("Time:").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .trailing)
                        Text("\(lat)").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .leading)
                    }
                    HStack {
                        Text("Longitude:").frame(minWidth: 200, alignment: .trailing)
                        Text("\(long)").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .leading)
                    }
                    HStack {
                        Text("Date:").frame(minWidth: /*@START_MENU_TOKEN@*/200/*@END_MENU_TOKEN@*/, alignment: .trailing)
                        Text("\(time)").frame(minWidth: 200, alignment: .leading)
                    }
                }

                Text(dev.identifier)
                    .font(.system(size: 9))

            }.padding()
        }
    }
}

#Preview {
//    DeviceDetails(device: $nil)
    Button("") {}
}
