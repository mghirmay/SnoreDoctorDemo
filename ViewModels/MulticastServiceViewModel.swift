//
//  MulticastServiceViewModel.swift
//  SnoreDoctorDemo
//
//  Created by musie Ghirmay on 13.05.25.
//

import Foundation
import MessagePack // Make sure you have this library integrated

// Define the MessagePack type for MIDI messages, matching the Java constant
let MsgPACK_TYPE_MIDI_MESSAGE: UInt8 = 0x45
// Define the MessagePack type for Device Info, matching your constant
let MsgPACK_TYPE_DEVICE_INFO: UInt8 = 0x12

// This struct mirrors your C++ DeviceInfoStruct
struct DeviceInfo {
    var id: Int
    var index: Int
    var fType: Int // Device Type: 0 for ws2812, 1 for ws2801, 2 for PWM fixture
    var pixels: Int // Number of NeoPixels attached to the device
    var segments: Int // not used yet
    var width: Int // Width of the device or display
    var height: Int // Height of the device or display
    var layOutX: Int // Layout position on the X-axis
    var layOutY: Int // Layout position on the Y-axis
    var layOutZ: Int // Layout position on the Z-axis
    var title: String // Title or name of the device
    var group: String // Group name to which the device belongs
    var espChipId: String // Hardware device name (ESP chip identifier)
    var fwVersion: String // Firmware version running on the device
}

class MulticastServiceViewModel: ObservableObject {
    private let client = MulticastServiceClient()

    // The DeviceInfo instance you want to send
    let myDevice = DeviceInfo(
        id: 1,
        index: 0,
        fType: 3, // midi messanger
        pixels: 150,
        segments: 0,
        width: 150,
        height: 1,
        layOutX: 0,
        layOutY: 0,
        layOutZ: 0,
        title: "IPhone",
        group: "Midi messanger",
        espChipId: "ABCD",
        fwVersion: "1.0.1"
    )

    init() {
           // Set up all your callbacks here
           client.onConnectionReady = { [weak self] in
               guard let self = self else { return }
               print("[ViewModel] Sending connection became ready! Sending Device Info.")
               self.sendDeviceInfoMessage(deviceInfo: self.myDevice)
           }

           client.onConnectionFailed = { error in
               print("[ViewModel] Sending connection failed with error: \(error.localizedDescription)")
               // Potentially show an alert to the user or log to analytics
           }

           client.onSendError = { error in
               print("[ViewModel] Data send failed with error: \(error.localizedDescription)")
               // Inform the user, retry sending, or update UI state
           }

           client.onServiceFound = { service in
               print("[ViewModel] Discovered service: \(service.name) of type \(service.type)")
           }

           client.onServiceRemoved = { service in
               print("[ViewModel] Service removed: \(service.name)")
           }

           client.onServiceResolved = { service in
               print("[ViewModel] Target service resolved: \(service.name) on port \(service.port)")
           }

           // NEW: Callback for listener restarts
           client.onListenerRestarted = {
               print("[ViewModel] Listener restarted!  Ready to receive data again.")
               // Perform any actions needed when the listener restarts,
               // such as re-enabling UI elements or logging.
           }

           // NEW: Callback for incoming data
        client.onDataReceived = { [weak self] data, senderEndpoint in
            guard self != nil else { return }
                   print("[ViewModel] Received data from \(senderEndpoint.debugDescription): \(data.count) bytes.")
                   
                   do {
                       // FIX: Convert Data to [UInt8] before unpacking
                       let (unpackedValue, _) = try MessagePack.unpack(data)
                       print("[ViewModel] Unpacked received data: \(unpackedValue)")

                       // Now, you'd inspect unpackedValue to determine its type and content
                       // For example, if it's structured like your outbound messages:
                       if case let .array(outerArray) = unpackedValue, outerArray.count >= 2 {
                           if case let .uint(packageIdx) = outerArray[0],
                              case let .uint(packageID) = outerArray[1] {
                               print("  Received packageIdx: \(packageIdx), packageID: \(String(format: "0x%02X", packageID))")

                               if packageID == MsgPACK_TYPE_MIDI_MESSAGE {
                                   print("  It's a MIDI message!")
                                   // Further parse the MIDI message array if it's at outerArray[2]
                               } else if packageID == MsgPACK_TYPE_DEVICE_INFO {
                                   print("  It's Device Info!")
                                   // Further parse the Device Info array if it's at outerArray[2]
                               } else {
                                   print("  Unknown package ID.")
                               }
                           }
                       }

                   } catch {
                       print("[ViewModel] Error unpacking received data: \(error.localizedDescription)")
                   }
               }

           start()
       }

    func start() {
        print("[ViewModel] Starting multicast service client")
        client.startSearching()
    }

    func send(message: String) {
        guard let data = message.data(using: .utf8) else {
            print("[ViewModel] Failed to encode message")
            return
        }
        print("[ViewModel] Sending string message: \(message)")
        client.sendData(data)
    }

    // MARK: - MIDI Message Packing and Sending

    func sendMidiMessage(command: UInt8, channel: UInt8, data1: UInt8, data2: UInt8) {
        do {
            let packedMidiData = try packMidiMessage(command: command, channel: channel, data1: data1, data2: data2)
            print("[ViewModel] Sending packed MIDI message: Command=\(String(format: "0x%02X", command)), Channel=\(channel), Data1=\(data1), Data2=\(data2)")
            client.sendData(packedMidiData)
        } catch {
            print("[ViewModel] Error packing MIDI message: \(error.localizedDescription)")
        }
    }

    private func packMidiMessage(command: UInt8, channel: UInt8, data1: UInt8, data2: UInt8) throws -> Data {
        let packageIdx: UInt8 = 0
        let packageID: UInt8 = MsgPACK_TYPE_MIDI_MESSAGE

        let midiMessageArrayContent: [MessagePackValue] = [
            .uint(UInt64(command)),
            .uint(UInt64(channel)),
            .uint(UInt64(data1)),
            .uint(UInt64(data2))
        ]
        let midiMessagePackValue: MessagePackValue = .array(midiMessageArrayContent)

        let fullMessageArrayContent: [MessagePackValue] = [
            .uint(UInt64(packageIdx)),
            .uint(UInt64(packageID)),
            midiMessagePackValue
        ]

        let fullMessagePackValue: MessagePackValue = .array(fullMessageArrayContent)

        let packedData = MessagePack.pack(fullMessagePackValue)

        return Data(packedData)
    }

    // MARK: - DeviceInfo Packing and Sending

    func sendDeviceInfoMessage(deviceInfo: DeviceInfo) {
        do {
            let packedDeviceInfoData = try packDeviceInfo(deviceInfo: deviceInfo)
            print("[ViewModel] Sending packed DeviceInfo for ID: \(deviceInfo.id)")
            client.sendData(packedDeviceInfoData)
        } catch {
            print("[ViewModel] Error packing DeviceInfo: \(error.localizedDescription)")
        }
    }

    private func packDeviceInfo(deviceInfo: DeviceInfo) throws -> Data {
        let packageIdx: UInt8 = 0
        let packageID: UInt8 = MsgPACK_TYPE_DEVICE_INFO

        let deviceInfoArrayContent: [MessagePackValue] = [
            .int(Int64(deviceInfo.id)),
            .int(Int64(deviceInfo.index)),
            .int(Int64(deviceInfo.fType)),
            .int(Int64(deviceInfo.pixels)),
            .int(Int64(deviceInfo.segments)),
            .int(Int64(deviceInfo.width)),
            .int(Int64(deviceInfo.height)),
            .int(Int64(deviceInfo.layOutX)),
            .int(Int64(deviceInfo.layOutY)),
            .int(Int64(deviceInfo.layOutZ)),
            .string(deviceInfo.title),
            .string(deviceInfo.group),
            .string(deviceInfo.espChipId),
            .string(deviceInfo.fwVersion)
        ]
        let deviceInfoPackValue: MessagePackValue = .array(deviceInfoArrayContent)

        let fullMessageArrayContent: [MessagePackValue] = [
            .uint(UInt64(packageIdx)),
            .uint(UInt64(packageID)),
            deviceInfoPackValue
        ]

        let fullMessagePackValue: MessagePackValue = .array(fullMessageArrayContent)

        let packedData = MessagePack.pack(fullMessagePackValue)

        return Data(packedData)
    }
}
