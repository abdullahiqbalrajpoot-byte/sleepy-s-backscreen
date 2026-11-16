import Foundation
import CoreBluetooth
import UIKit

class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()

    // Matching firmware & Android config
    static let deviceName = "SMART_BACKPACK_DISPLAY"
    static let serviceUUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
    static let metadataCharUUID = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
    static let artworkCharUUID = CBUUID(string: "19B10002-E8F2-537E-4F6C-D104768A1214")
    static let playbackCharUUID = CBUUID(string: "19B10003-E8F2-537E-4F6C-D104768A1214")

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?

    private var metadataChar: CBCharacteristic?
    private var artworkChar: CBCharacteristic?
    private var playbackChar: CBCharacteristic?

    @Published var isConnected = false
    @Published var isScanning = false
    @Published var statusMessage = "Disconnected"

    var onStateChanged: ((Bool, String?) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            statusMessage = "Bluetooth is not powered on"
            return
        }

        if isConnected {
            statusMessage = "Already connected"
            return
        }

        isScanning = true
        statusMessage = "Scanning for \(BLEManager.deviceName)..."
        centralManager.scanForPeripherals(
            withServices: [BLEManager.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
            statusMessage = "Scan stopped"
        }
    }

    func disconnect() {
        stopScan()
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        self.peripheral = nil
        self.metadataChar = nil
        self.artworkChar = nil
        self.playbackChar = nil
        self.isConnected = false
        self.statusMessage = "Disconnected"
        self.onStateChanged?(false, nil)
    }

    // ── Sending Data ─────────────────────────────────────────────────────────

    func sendMetadata(title: String, artist: String, album: String = "", duration: Int64 = 0, artwork: UIImage? = nil) {
        guard isConnected, let p = peripheral, let char = metadataChar else { return }

        let payload: [String: Any] = [
            "title": title,
            "artist": artist,
            "album": album,
            "duration": duration,
            "position": 0,
            "playing": true
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            p.writeValue(jsonData, for: char, type: writeType)
            print("[BLE] Sent metadata: \(title) - \(artist)")
        }

        if let artwork = artwork {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                self.sendArtwork(image: artwork)
            }
        }
    }

    func sendCustomText(text: String) {
        guard !text.isEmpty else { return }
        let bannerArt = ImageProcessing.createBannerArtwork(text: text)
        sendMetadata(
            title: text,
            artist: "BACKPACK MARQUEE",
            album: "Custom Message",
            duration: 0,
            artwork: bannerArt
        )
    }

    func sendPlaybackState(position: Int64, isPlaying: Bool) {
        guard isConnected, let p = peripheral, let char = playbackChar else { return }

        let payload: [String: Any] = [
            "position": position,
            "playing": isPlaying
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            p.writeValue(jsonData, for: char, type: writeType)
        }
    }

    private func sendArtwork(image: UIImage) {
        guard let p = peripheral, let char = artworkChar else { return }

        let rawBytes = ImageProcessing.convertToRgb565(image: image, targetSize: 80)
        let chunks = ImageProcessing.createChunks(rawData: rawBytes, chunkSize: 480)

        print("[BLE] Sending artwork: \(chunks.count) chunks (\(rawBytes.count) bytes)...")

        let writeType: CBCharacteristicWriteType = char.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

        for (index, chunk) in chunks.enumerated() {
            p.writeValue(chunk, for: char, type: writeType)
            // Pace packets by 25ms to prevent BLE buffer overflow
            Thread.sleep(forTimeInterval: 0.025)
        }

        print("[BLE] Artwork transfer complete!")
    }
}

// ── CBCentralManagerDelegate ──────────────────────────────────────────────────

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
        case .poweredOff:
            statusMessage = "Bluetooth turned off"
            disconnect()
        case .unauthorized:
            statusMessage = "Bluetooth permission not granted"
        case .unsupported:
            statusMessage = "Bluetooth LE not supported"
        default:
            statusMessage = "Bluetooth state: \(central.state.rawValue)"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown"
        print("[BLE] Discovered: \(name)")

        // Match device name or service UUID
        if name.contains("BACKPACK") || name.contains("Sleepy") || name == BLEManager.deviceName {
            stopScan()
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            statusMessage = "Connecting to \(name)..."
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusMessage = "Connected! Discovering services..."
        peripheral.discoverServices([BLEManager.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown")"
        disconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Disconnected from device"
        disconnect()
    }
}

// ── CBPeripheralDelegate ──────────────────────────────────────────────────────

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            statusMessage = "Error discovering services: \(error.localizedDescription)"
            return
        }

        guard let services = peripheral.services else { return }
        for service in services where service.uuid == BLEManager.serviceUUID {
            peripheral.discoverCharacteristics([
                BLEManager.metadataCharUUID,
                BLEManager.artworkCharUUID,
                BLEManager.playbackCharUUID
            ], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            statusMessage = "Error discovering chars: \(error.localizedDescription)"
            return
        }

        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            switch char.uuid {
            case BLEManager.metadataCharUUID:
                self.metadataChar = char
            case BLEManager.artworkCharUUID:
                self.artworkChar = char
            case BLEManager.playbackCharUUID:
                self.playbackChar = char
            default:
                break
            }
        }

        if metadataChar != nil {
            self.isConnected = true
            self.statusMessage = "Connected to Backpack Display"
            self.onStateChanged?(true, peripheral.name ?? BLEManager.deviceName)
            print("[BLE] All services and characteristics ready!")
        }
    }
}
