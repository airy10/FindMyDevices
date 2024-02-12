//
//  ContentView.swift
//  FindMyDevices
//
//  Created by Airy ANDRE on 07/02/2024.
//

import SwiftUI
import MapKit

struct DeviceMarker:  MapContent {
    @ObservedObject
    var device : Device

    @Binding
    var selection : Device?

    var body: some  MapContent {
        if let latitude = device.latitude, let longitude = device.longitude {
            let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            Marker("\(device.label)", coordinate: location)
                .tint(device == selection ? .red : .blue)
        }
    }
}
struct ContentView: View {
    @ObservedObject
    var devicesManager : DevicesManager

    @State
    private var selection : Device? = nil

    init(devicesManager: DevicesManager = DevicesManager()) {
        self.devicesManager = devicesManager
    }

    var body: some View {
            HSplitView {
                VSplitView {
                    GeometryReader { geometry in

                        List(devicesManager.devices, selection: $selection) { device in
                           // DeviceLabel(device: device, selection: $selection)
                            Text("\(device.label)")
                                .frame(width: geometry.size.width, alignment: Alignment.leading)
                                .contentShape(Rectangle())
                                .foregroundStyle(device == selection  ? AnyShapeStyle(.selection): AnyShapeStyle(.foreground))
                                .listRowBackground(device == selection  ? Color.accentColor : nil)
                                .onTapGesture {
                                    selection = device
                                }
                        }
                        .listStyle(PlainListStyle())
                        .listItemTint(Color.accentColor)
                    }
                    DeviceDetails(device: $selection)
                        .padding()
                }
                Map(interactionModes: .all) {
                    ForEach(devicesManager.devices) { device in
                        if let _ = device.latitude, let _ = device.longitude {
                            DeviceMarker(device: device, selection: $selection)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapPitchSlider()
                    MapPitchToggle()
                }

            }
            .padding()
    }
}

#Preview {
    ContentView()
}
