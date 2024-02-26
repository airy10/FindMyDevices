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

    let isSelected : Bool

    var body: some  MapContent {

        if let latitude = device.latitude, let longitude = device.longitude {
            let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            if let accuracy = device.horizontalAccuracy {
                MapCircle(center: location, radius: accuracy)
                    .mapOverlayLevel(level: isSelected ? .aboveLabels : .aboveRoads)
                    .foregroundStyle(.teal.opacity(isSelected ? 0.3 : 0.05))
                    .stroke(.white, lineWidth: isSelected ? 2.0 : 0.5)
            }

            Marker(device.label, coordinate: location)
                .tint(isSelected ? .red : .blue)
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

    private var selectionIndex: Int? {
        return $selection.wrappedValue == nil ? nil : devicesManager.devices.firstIndex(of: $selection.wrappedValue!)
    }

    private func device(atIndex index: Int?) -> Device? {
        guard let idx = index, (0...devicesManager.devices.count-1) ~= idx else { return nil}

        return devicesManager.devices[idx]

    }

    private func selectPrev()
    {
        if let selIndex = selectionIndex {
            selection = device(atIndex:  selIndex - 1)
        } else {
            selection = devicesManager.devices.last
        }
    }

    private func selectNext()
    {
        if let selIndex = selectionIndex {
            selection = device(atIndex:  selIndex + 1)
        } else {
            selection = devicesManager.devices.first
        }
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading) {

                GeometryReader { geometry in

                    VStack(alignment: .leading) {
                        List(devicesManager.devices, selection: $selection) { device in
                            Text(device.label)
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

                        .onKeyPress(keys: [ .upArrow, .downArrow]) {
                            key in

                            switch key.key {
                            case .upArrow:
                                selectPrev()
                            case .downArrow:
                                selectNext()
                            default:
                                break
                            }

                            return .handled
                        }

                        // Hack because "onKeyPress" doesn't get down and up arrow keys on macOS
                        VStack {
                            Button("") {
                                selectNext()
                            }
                            .keyboardShortcut(KeyboardShortcut(.downArrow, modifiers: []))

                            Button("") {
                                selectPrev()
                            }
                            .keyboardShortcut(KeyboardShortcut(.upArrow, modifiers: []))
                        }.hidden()

                        if let sel = $selection.wrappedValue  {
                            DeviceDetails(device: sel)
                                .frame(width: geometry.size.width)
                        }
                    }

                }
            }
            .frame(minWidth: 200)
            Map(interactionModes: .all, selection: $selection) {
                ForEach(devicesManager.devices, id: \.self) { device in
                    if let _ = device.latitude, let _ = device.longitude {

                        let isSelected = (device == selection)
                        DeviceMarker(device: device, isSelected: isSelected)
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
            .frame(minWidth: 400)

        }
        .padding()
    }
}

#Preview {
    ContentView()
}

