import Carbon.HIToolbox

/// A global hot key. Carbon hot keys need no Accessibility permission.
final class HotKey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var handler: EventHandlerRef?
    private var reference: EventHotKeyRef?

    init?(keyCode: Int, modifiers: Int, id: UInt32, action: @escaping () -> Void) {
        if HotKey.handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hotKey = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
                HotKey.actions[hotKey.id]?()
                return noErr
            }, 1, &spec, nil, &HotKey.handler)
        }
        HotKey.actions[id] = action
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers),
            EventHotKeyID(signature: OSType(0x464C_5348), id: id), // "FLSH"
            GetEventDispatcherTarget(), 0, &reference
        )
        guard status == noErr else { return nil }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
    }
}
