// Event provider for the bluetooth_boucles item (spawned by sketchybarrc).
// Watches IOBluetooth connection/disconnection notifications for the configured
// device and triggers sketchybar only when that device changes state.
import Foundation
import IOBluetooth

let sketchybar = "/opt/homebrew/bin/sketchybar"
let deviceName = ProcessInfo.processInfo.environment["BOUCLES_DEVICE_NAME"] ?? "Boucles soniques"

func trigger(_ state: String) {
    let t = Process()
    t.executableURL = URL(fileURLWithPath: sketchybar)
    t.arguments = ["--trigger", "bluetooth_boucles_change", "BOUCLES_STATE=\(state)"]
    try? t.run()
}

final class Watcher: NSObject {
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [IOBluetoothUserNotification] = []

    func start() {
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    private func matches(_ device: IOBluetoothDevice) -> Bool {
        return device.name == deviceName
    }

    private func registerDisconnect(_ device: IOBluetoothDevice) {
        if let notification = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:))) {
            disconnectNotifications.append(notification)
        }
    }

    @objc func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard matches(device) else { return }
        registerDisconnect(device)
        trigger("connected")
    }

    @objc func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard matches(device) else { return }
        trigger("disconnected")
    }
}

let watcher = Watcher()
watcher.start()

// Exit when sketchybar is gone so reload-spawned copies don't accumulate
// (sketchybarrc also killalls before spawning).
Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
    let t = Process()
    t.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    t.arguments = ["-x", "sketchybar"]
    t.standardOutput = Pipe()
    try? t.run()
    t.waitUntilExit()
    if t.terminationStatus != 0 { exit(0) }
}

RunLoop.main.run()
