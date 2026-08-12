// Reads CodexBar's WidgetKit snapshot without asking CodexBar or its providers
// to refresh, renders CodexBar's plain merged-style quota meters, and updates
// two ordinary SketchyBar items. Geometry follows CodexBar v0.41.0's MIT-
// licensed IconRenderer; both providers intentionally use its undecorated
// `.combined` style.

import AppKit
import Darwin
import Foundation

private let canvasPixels = 36
private let outputScale: CGFloat = 2

private struct Configuration {
    var snapshotURL: URL
    var outputDirectory: URL
    var runOnce = false
    var updateSketchyBar = true
}

private enum ProviderStyle: String, CaseIterable {
    case codex
    case claude

    var itemName: String { "\(self.rawValue)_usage" }
}

private struct ProviderState: Equatable {
    let visible: Bool
    let topPercent: Double?
    let bottomPercent: Double?
    let creditsPercent: Double?
}

private struct SnapshotState: Equatable {
    let providers: [ProviderStyle: ProviderState]
}

private struct SourceWindow {
    let id: String
    let usedPercent: Double
    let remainingPercent: Double
    let windowMinutes: Int?
    let resetsAt: Date?

    var isSession: Bool {
        self.id == "session" || self.windowMinutes == 300
    }

    var isWeekly: Bool {
        self.id == "weekly" || self.windowMinutes == 10_080
    }
}

private struct PixelRect {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    var midX: Int { self.x + self.width / 2 }

    func points() -> CGRect {
        CGRect(
            x: CGFloat(self.x) / outputScale,
            y: CGFloat(self.y) / outputScale,
            width: CGFloat(self.width) / outputScale,
            height: CGFloat(self.height) / outputScale)
    }
}

private func parseConfiguration() -> Configuration {
    let home = FileManager.default.homeDirectoryForCurrentUser
    var configuration = Configuration(
        snapshotURL: home
            .appendingPathComponent("Library/Group Containers", isDirectory: true)
            .appendingPathComponent("Y5PE65HELJ.com.steipete.codexbar", isDirectory: true)
            .appendingPathComponent("widget-snapshot.json"),
        outputDirectory: home
            .appendingPathComponent(".cache/sketchybar/codexbar", isDirectory: true))

    var index = 1
    let arguments = CommandLine.arguments
    while index < arguments.count {
        switch arguments[index] {
        case "--once":
            configuration.runOnce = true
        case "--no-sketchybar":
            configuration.updateSketchyBar = false
        case "--snapshot" where index + 1 < arguments.count:
            index += 1
            configuration.snapshotURL = URL(fileURLWithPath: arguments[index])
        case "--output-dir" where index + 1 < arguments.count:
            index += 1
            configuration.outputDirectory = URL(fileURLWithPath: arguments[index], isDirectory: true)
        default:
            fputs("codexbar_usage_watcher: ignoring unknown argument \(arguments[index])\n", stderr)
        }
        index += 1
    }
    return configuration
}

private func number(_ value: Any?) -> Double? {
    (value as? NSNumber)?.doubleValue
}

private func dictionary(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
}

private func parseDate(_ value: Any?) -> Date? {
    guard let string = value as? String else { return nil }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: string) { return date }

    let ordinary = ISO8601DateFormatter()
    ordinary.formatOptions = [.withInternetDateTime]
    return ordinary.date(from: string)
}

private func sourceWindow(
    id: String,
    row: [String: Any]?,
    window: [String: Any]?) -> SourceWindow?
{
    let remaining = number(row?["percentLeft"])
        ?? number(window?["usedPercent"]).map { 100 - $0 }
    let used = number(window?["usedPercent"])
        ?? remaining.map { 100 - $0 }
    guard let remaining, let used else { return nil }

    return SourceWindow(
        id: id,
        usedPercent: max(0, min(used, 100)),
        remainingPercent: max(0, min(remaining, 100)),
        windowMinutes: number(window?["windowMinutes"]).map(Int.init),
        resetsAt: parseDate(window?["resetsAt"]))
}

private func displayedPercent(_ window: SourceWindow, showUsed: Bool) -> Double {
    showUsed ? window.usedPercent : window.remainingPercent
}

private func codexState(
    entry: [String: Any]?,
    visible: Bool,
    showUsed: Bool,
    now: Date) -> ProviderState
{
    guard visible else {
        return ProviderState(visible: false, topPercent: nil, bottomPercent: nil, creditsPercent: nil)
    }
    guard let entry else {
        return ProviderState(visible: true, topPercent: nil, bottomPercent: nil, creditsPercent: nil)
    }

    var windows: [SourceWindow] = []
    if let rows = entry["usageRows"] as? [[String: Any]] {
        windows = rows.compactMap { row in
            let id = row["id"] as? String ?? ""
            return sourceWindow(id: id, row: row, window: dictionary(row["window"]))
        }
    }

    // Older snapshots may omit usageRows. Preserve source slot order, then use
    // the same 300-minute/10080-minute classification as CodexBar.
    if windows.isEmpty {
        var fallbackOrder: [String] = []
        var fallbackWindows: [String: SourceWindow] = [:]
        for (fallbackID, key) in [("session", "primary"), ("weekly", "secondary")] {
            guard let window = dictionary(entry[key]) else { continue }
            let minutes = number(window["windowMinutes"]).map(Int.init)
            let id = switch minutes {
            case 300: "session"
            case 10_080: "weekly"
            default: fallbackID
            }
            if let parsed = sourceWindow(id: id, row: nil, window: window) {
                if fallbackWindows[id] == nil { fallbackOrder.append(id) }
                fallbackWindows[id] = parsed
            }
        }
        windows = fallbackOrder.compactMap { fallbackWindows[$0] }
    }

    let weekly = windows.first(where: \.isWeekly)
    let weeklyCapsSession = weekly.map { weekly in
        guard weekly.remainingPercent <= 0 else { return false }
        return weekly.resetsAt.map { $0 > now } ?? true
    } ?? false

    let selectable = windows.compactMap { source -> SourceWindow? in
        var window = source
        if source.isSession, weeklyCapsSession {
            let sessionIsExhausted = source.remainingPercent <= 0
                && (source.resetsAt.map { $0 > now } ?? true)
            let bindingReset: Date? = if sessionIsExhausted {
                if let sessionReset = source.resetsAt, let weeklyReset = weekly?.resetsAt {
                    max(sessionReset, weeklyReset)
                } else {
                    nil
                }
            } else {
                weekly?.resetsAt
            }
            window = SourceWindow(
                id: source.id,
                usedPercent: 100,
                remainingPercent: 0,
                windowMinutes: source.windowMinutes,
                resetsAt: bindingReset)
        }

        // CodexBar drops exhausted lanes only after their known reset has
        // passed, then compacts the surviving lanes into the two icon slots.
        if window.remainingPercent <= 0,
           let reset = window.resetsAt,
           reset <= now
        {
            return nil
        }
        return window
    }

    let creditsBalance = number(entry["creditsRemaining"])
    let hasExhaustedLane = windows.contains { window in
        window.remainingPercent <= 0 && (window.resetsAt.map { $0 > now } ?? true)
    }
    let creditsPercent: Double? = if let creditsBalance,
                                     creditsBalance > 0,
                                     windows.isEmpty || hasExhaustedLane
    {
        min(creditsBalance / 1_000 * 100, 100)
    } else {
        nil
    }

    return ProviderState(
        visible: true,
        topPercent: selectable.first.map { displayedPercent($0, showUsed: showUsed) },
        bottomPercent: selectable.dropFirst().first.map { displayedPercent($0, showUsed: showUsed) },
        creditsPercent: creditsPercent)
}

private func claudeState(
    entry: [String: Any]?,
    visible: Bool,
    showUsed: Bool) -> ProviderState
{
    guard visible else {
        return ProviderState(visible: false, topPercent: nil, bottomPercent: nil, creditsPercent: nil)
    }
    guard let entry else {
        return ProviderState(visible: true, topPercent: nil, bottomPercent: nil, creditsPercent: nil)
    }

    // Unlike Codex, Claude keeps its source slots fixed: primary/session is
    // always the top lane and secondary/weekly is always the bottom lane.
    let primary = dictionary(entry["primary"]).flatMap {
        sourceWindow(id: "primary", row: nil, window: $0)
    }
    let secondary = dictionary(entry["secondary"]).flatMap {
        sourceWindow(id: "secondary", row: nil, window: $0)
    }

    return ProviderState(
        visible: true,
        topPercent: primary.map { displayedPercent($0, showUsed: showUsed) },
        bottomPercent: secondary.map { displayedPercent($0, showUsed: showUsed) },
        creditsPercent: nil)
}

private func decodeSnapshot(_ data: Data, now: Date = Date()) throws -> SnapshotState {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw NSError(domain: "CodexBarUsage", code: 1, userInfo: [NSLocalizedDescriptionKey: "root is not an object"])
    }

    let entries = (root["entries"] as? [[String: Any]]) ?? []
    var byProvider: [String: [String: Any]] = [:]
    for entry in entries {
        guard let provider = entry["provider"] as? String else { continue }
        byProvider[provider] = entry
    }
    let enabledList = root["enabledProviders"] as? [String]
    let enabled = Set(enabledList ?? byProvider.keys.map { $0 })
    let showUsed = (root["usageBarsShowUsed"] as? Bool) ?? false

    let codexVisible = enabled.contains(ProviderStyle.codex.rawValue)
    let claudeVisible = enabled.contains(ProviderStyle.claude.rawValue)
    return SnapshotState(providers: [
        .codex: codexState(
            entry: byProvider[ProviderStyle.codex.rawValue],
            visible: codexVisible,
            showUsed: showUsed,
            now: now),
        .claude: claudeState(
            entry: byProvider[ProviderStyle.claude.rawValue],
            visible: claudeVisible,
            showUsed: showUsed),
    ])
}

private func colorFromEnvironment() -> NSColor {
    let raw = ProcessInfo.processInfo.environment["CODEXBAR_USAGE_COLOR"] ?? "0xffc0caf5"
    let cleaned = raw.lowercased().hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
    guard let value = UInt64(cleaned, radix: 16) else {
        return NSColor(srgbRed: 0xc0 / 255, green: 0xca / 255, blue: 0xf5 / 255, alpha: 1)
    }
    let alpha: CGFloat
    let rgb: UInt64
    if cleaned.count > 6 {
        alpha = CGFloat((value >> 24) & 0xff) / 255
        rgb = value & 0x00ff_ffff
    } else {
        alpha = 1
        rgb = value
    }
    return NSColor(
        srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
        green: CGFloat((rgb >> 8) & 0xff) / 255,
        blue: CGFloat(rgb & 0xff) / 255,
        alpha: alpha)
}

private func drawMeter(
    state: ProviderState,
    color: NSColor) -> Data?
{
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasPixels,
        pixelsHigh: canvasPixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0)
    else { return nil }
    bitmap.size = NSSize(width: 18, height: 18)
    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.clear(CGRect(x: 0, y: 0, width: 18, height: 18))

    let topRect = PixelRect(x: 3, y: 19, width: 30, height: 12)
    let bottomRect = PixelRect(x: 3, y: 5, width: 30, height: 8)
    let creditsRect = PixelRect(x: 3, y: 14, width: 30, height: 16)
    let exhaustedBottomRect = PixelRect(x: 3, y: 4, width: 30, height: 6)

    func drawBar(
        rect: PixelRect,
        percent: Double?,
        alpha: CGFloat = 1,
        decoration: ProviderStyle? = nil)
    {
        let radiusPixels = rect.height / 2
        let path = NSBezierPath(
            roundedRect: rect.points(),
            xRadius: CGFloat(radiusPixels) / outputScale,
            yRadius: CGFloat(radiusPixels) / outputScale)

        color.withAlphaComponent(0.28 * alpha).setFill()
        path.fill()

        let inset = 1
        let strokeRect = PixelRect(
            x: rect.x + inset,
            y: rect.y + inset,
            width: max(0, rect.width - inset * 2),
            height: max(0, rect.height - inset * 2))
        let strokePath = NSBezierPath(
            roundedRect: strokeRect.points(),
            xRadius: CGFloat(max(0, radiusPixels - inset)) / outputScale,
            yRadius: CGFloat(max(0, radiusPixels - inset)) / outputScale)
        strokePath.lineWidth = 1
        color.withAlphaComponent(0.44 * alpha).setStroke()
        strokePath.stroke()

        if let percent {
            let clamped = max(0, min(percent, 100))
            let fillWidth = max(0, min(rect.width, Int((Double(rect.width) * clamped / 100).rounded())))
            if fillWidth > 0 {
                context.saveGState()
                path.addClip()
                color.withAlphaComponent(alpha).setFill()
                NSBezierPath(rect: PixelRect(
                    x: rect.x,
                    y: rect.y,
                    width: fillWidth,
                    height: rect.height).points()).fill()
                context.restoreGState()
            }
        }

    }

    if state.bottomPercent == nil {
        if state.topPercent == nil, let creditsPercent = state.creditsPercent {
            drawBar(rect: creditsRect, percent: creditsPercent)
            drawBar(rect: exhaustedBottomRect, percent: nil, alpha: 0.45)
        } else {
            drawBar(rect: topRect, percent: state.topPercent)
            drawBar(rect: bottomRect, percent: nil, alpha: 0.45)
        }
    } else if state.bottomPercent! <= 0 {
        // CodexBar uses a thinner secondary track for a literal zero value.
        if let creditsPercent = state.creditsPercent {
            drawBar(rect: creditsRect, percent: creditsPercent)
        } else {
            drawBar(rect: topRect, percent: state.topPercent)
        }
        drawBar(rect: exhaustedBottomRect, percent: state.bottomPercent)
    } else {
        drawBar(rect: topRect, percent: state.topPercent)
        drawBar(rect: bottomRect, percent: state.bottomPercent)
    }

    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

private func writeIfChanged(_ data: Data, to url: URL) throws {
    if let existing = try? Data(contentsOf: url), existing == data { return }
    try data.write(to: url, options: .atomic)
}

private func sketchyBarExecutable() -> String? {
    let environment = ProcessInfo.processInfo.environment
    let candidates = [
        environment["SKETCHYBAR_BIN"],
        "/opt/homebrew/bin/sketchybar",
        "/usr/local/bin/sketchybar",
    ].compactMap { $0 }
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

private func updateSketchyBar(
    states: [ProviderStyle: ProviderState],
    imageURLs: [ProviderStyle: URL]) -> Bool
{
    guard let executable = sketchyBarExecutable() else { return false }
    var arguments: [String] = []
    for style in ProviderStyle.allCases {
        guard let state = states[style] else { continue }
        arguments += ["--set", style.itemName, "drawing=\(state.visible ? "on" : "off")"]
        if state.visible, let imageURL = imageURLs[style] {
            arguments.append("icon.background.image=\(imageURL.path)")
            arguments.append("icon.background.image.drawing=on")
        }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

private final class SnapshotController {
    private let configuration: Configuration
    private let color = colorFromEnvironment()
    private var lastGoodData: Data?
    private var lastState: SnapshotState?
    private var consecutiveReadFailures = 0

    private var hiddenState: SnapshotState {
        SnapshotState(providers: Dictionary(uniqueKeysWithValues: ProviderStyle.allCases.map {
            ($0, ProviderState(
                visible: false,
                topPercent: nil,
                bottomPercent: nil,
                creditsPercent: nil))
        }))
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    @discardableResult
    func refresh(forceSketchyBarUpdate: Bool = false, reevaluateTime: Bool = false) -> Bool {
        guard let data = try? Data(contentsOf: self.configuration.snapshotURL) else {
            return self.handleReadFailure()
        }
        if !forceSketchyBarUpdate, !reevaluateTime, data == self.lastGoodData {
            self.consecutiveReadFailures = 0
            return true
        }

        let state: SnapshotState
        do {
            state = try decodeSnapshot(data)
        } catch {
            fputs("codexbar_usage_watcher: invalid snapshot: \(error)\n", stderr)
            return self.handleReadFailure()
        }
        self.consecutiveReadFailures = 0

        let visibleImagesExist = ProviderStyle.allCases.allSatisfy { style in
            guard state.providers[style]?.visible == true else { return true }
            return FileManager.default.fileExists(
                atPath: self.configuration.outputDirectory
                    .appendingPathComponent("\(style.rawValue).png").path)
        }
        if !forceSketchyBarUpdate, state == self.lastState, visibleImagesExist {
            self.lastGoodData = data
            return true
        }

        do {
            try FileManager.default.createDirectory(
                at: self.configuration.outputDirectory,
                withIntermediateDirectories: true)
            var imageURLs: [ProviderStyle: URL] = [:]
            for style in ProviderStyle.allCases {
                guard let provider = state.providers[style], provider.visible else { continue }
                guard let png = drawMeter(state: provider, color: self.color) else {
                    throw NSError(
                        domain: "CodexBarUsage",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "could not render \(style.rawValue)"])
                }
                let url = self.configuration.outputDirectory.appendingPathComponent("\(style.rawValue).png")
                try writeIfChanged(png, to: url)
                imageURLs[style] = url
            }
            if self.configuration.updateSketchyBar,
               !updateSketchyBar(states: state.providers, imageURLs: imageURLs)
            {
                self.lastState = nil
                return false
            }
            self.lastGoodData = data
            self.lastState = state

            let summary = ProviderStyle.allCases.map { style -> String in
                let provider = state.providers[style]
                let top = provider?.topPercent.map { String(format: "%.1f", $0) } ?? "nil"
                let bottom = provider?.bottomPercent.map { String(format: "%.1f", $0) } ?? "nil"
                return "\(style.rawValue)=\(provider?.visible == true ? "on" : "off")[\(top),\(bottom)]"
            }.joined(separator: " ")
            print(summary)
            return true
        } catch {
            fputs("codexbar_usage_watcher: render failed: \(error)\n", stderr)
            return false
        }
    }

    private func handleReadFailure() -> Bool {
        self.consecutiveReadFailures += 1
        // Keep a last-good image across a transient atomic-replacement race.
        // At cold start hide immediately; after a valid snapshot, require three
        // consecutive misses before treating the cache as genuinely gone.
        let shouldHide = self.lastGoodData == nil || self.consecutiveReadFailures >= 3
        guard shouldHide else { return false }

        let hidden = self.hiddenState
        if self.lastState != hidden {
            if self.configuration.updateSketchyBar,
               !updateSketchyBar(states: hidden.providers, imageURLs: [:])
            {
                return false
            }
            self.lastState = hidden
        }
        self.lastGoodData = nil
        return false
    }
}

private final class SnapshotDirectoryWatcher {
    private let directoryPath: String
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?

    init(directoryPath: String, onChange: @escaping () -> Void) {
        self.directoryPath = directoryPath
        self.onChange = onChange
    }

    func ensureWatching() {
        guard self.source == nil else { return }
        let descriptor = open(self.directoryPath, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename, .delete],
            queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = self.source?.data ?? []
            self.debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.onChange() }
            self.debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200), execute: work)

            if events.contains(.rename) || events.contains(.delete) {
                self.source?.cancel()
                self.source = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.ensureWatching()
                }
            }
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    deinit {
        self.debounceWorkItem?.cancel()
        self.source?.cancel()
    }
}

private let configuration = parseConfiguration()
private let controller = SnapshotController(configuration: configuration)
let initialSuccess = controller.refresh(forceSketchyBarUpdate: true)
if configuration.runOnce {
    exit(initialSuccess ? 0 : 1)
}

private let directoryPath = configuration.snapshotURL.deletingLastPathComponent().path
private let directoryWatcher = SnapshotDirectoryWatcher(directoryPath: directoryPath) {
    _ = controller.refresh()
}
directoryWatcher.ensureWatching()

// This only rereads a tiny local file when its bytes changed; it never invokes
// CodexBar or a provider. It recovers from missed events across sleep/wake and
// rearms the directory source if the app-group container appears or is replaced.
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    directoryWatcher.ensureWatching()
    _ = controller.refresh(reevaluateTime: true)
}

if let rawPID = ProcessInfo.processInfo.environment["SKETCHYBAR_PID"],
   let sketchyBarPID = pid_t(rawPID)
{
    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
        if kill(sketchyBarPID, 0) != 0 { exit(0) }
    }
}

withExtendedLifetime(directoryWatcher) {
    RunLoop.main.run()
}
