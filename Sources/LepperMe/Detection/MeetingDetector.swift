import AppKit
import Combine
import CoreAudio
import CoreMediaIO

/// Detects meetings locally, without calendar access:
/// microphone or camera in use by any app = meeting. A running meeting app is only an extra hint.
/// The meeting only counts as ended once mic and camera have been idle for the buffer time.
@MainActor
final class MeetingDetector: ObservableObject {
    @Published private(set) var isInMeeting = false
    @Published private(set) var microphoneActive = false
    @Published private(set) var cameraActive = false
    @Published private(set) var runningMeetingApps: [String] = []

    private let settings: SettingsStore
    private var lastActiveAt: Date?
    private var timer: AnyCancellable?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        poll()
        // Polling keeps this simple and robust across device changes (plug/unplug, AirPods etc.).
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
    }

    func stop() {
        timer = nil
    }

    private func poll() {
        let s = settings.settings
        microphoneActive = s.detectMicrophone && AudioDevices.isAnyInputRunning()
        cameraActive = s.detectCamera && VideoDevices.isAnyCameraRunning()
        runningMeetingApps = Self.runningApps(matching: s.meetingApps)

        let now = Date()
        if microphoneActive || cameraActive {
            lastActiveAt = now
            if !isInMeeting { isInMeeting = true }
        } else if isInMeeting, let last = lastActiveAt,
                  now.timeIntervalSince(last) >= TimeInterval(s.meetingBufferSeconds) {
            isInMeeting = false
        }
    }

    private static func runningApps(matching bundleIDs: [String]) -> [String] {
        let wanted = Set(bundleIDs)
        return NSWorkspace.shared.runningApplications
            .filter { app in app.bundleIdentifier.map(wanted.contains) ?? false }
            .compactMap { $0.localizedName ?? $0.bundleIdentifier }
    }
}

// MARK: - CoreAudio

/// Asks CoreAudio whether any input device is currently used by *some* process.
/// We never open the device ourselves, so no microphone permission is needed.
enum AudioDevices {
    static func isAnyInputRunning() -> Bool {
        allDeviceIDs().contains { hasInputStreams($0) && isRunningSomewhere($0) }
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func hasInputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func isRunningSomewhere(_ id: AudioDeviceID) -> Bool {
        // TODO: Devices that are both input and output (e.g. AirPods) may report "running"
        // while only playing audio. Verify on real hardware and refine if needed.
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(id, &address) {
            address.mScope = kAudioObjectPropertyScopeGlobal
        }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }
}

// MARK: - CoreMediaIO

/// Asks CoreMediaIO whether any camera is currently used by *some* process.
/// We never open the camera ourselves, so no camera permission is needed.
enum VideoDevices {
    static func isAnyCameraRunning() -> Bool {
        allDeviceIDs().contains(where: isRunningSomewhere)
    }

    private static func allDeviceIDs() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &ids) == noErr else { return [] }
        return ids
    }

    private static func isRunningSomewhere(_ id: CMIOObjectID) -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
        var running: UInt32 = 0
        var used: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        guard CMIOObjectGetPropertyData(id, &address, 0, nil, size, &used, &running) == noErr else { return false }
        return running != 0
    }
}
