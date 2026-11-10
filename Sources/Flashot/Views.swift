import AppKit
import ServiceManagement
import SwiftUI

struct MainView: View {
    @Bindable var navigation: Navigation

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.tab) {
                Label("Trang chủ", systemImage: "house").tag(Tab.home)
                Label("Lịch sử", systemImage: "photo.on.rectangle.angled").tag(Tab.history)
                Label("Cài đặt", systemImage: "gearshape").tag(Tab.settings)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            switch navigation.tab ?? .home {
            case .home: HomeView(navigation: navigation)
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .onAppear { History.shared.reload() }
    }
}

// MARK: Home

struct HomeView: View {
    var navigation: Navigation
    private let settings = Settings.shared
    private let history = History.shared
    @State private var permitted = CGPreflightScreenCaptureAccess()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Flashot").font(.largeTitle.bold())
                        Text("Chụp màn hình, đánh dấu và chia sẻ trong vài giây.").foregroundStyle(.secondary)
                    }
                }

                if !permitted { PermissionBanner(permitted: $permitted) }

                HStack(spacing: 16) {
                    CaptureCard(symbol: "rectangle.dashed", title: "Chụp vùng", detail: "Kéo chọn vùng hoặc bấm vào một cửa sổ",
                                shortcut: settings.regionShortcut.label, tint: .blue) {
                        MainWindow.shared.capture(fullScreen: false)
                    }
                    CaptureCard(symbol: "macwindow.on.rectangle", title: "Toàn màn hình", detail: "Lấy cả màn hình, vẫn vẽ được trước khi chép",
                                shortcut: settings.fullScreenShortcut.label, tint: .purple) {
                        MainWindow.shared.capture(fullScreen: true)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Ảnh gần đây").font(.title3.bold())
                        Spacer()
                        if !history.items.isEmpty {
                            Button("Xem tất cả") { navigation.tab = .history }.buttonStyle(.link)
                        }
                    }
                    if history.items.isEmpty {
                        Text("Ảnh bạn lưu (⌘S trong lúc chụp) sẽ hiện ở đây.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 90)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(history.items.prefix(8)) { ShotCell(item: $0, compact: true) }
                        }
                    }
                }

                ShortcutHelp()
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permitted = CGPreflightScreenCaptureAccess()
        }
    }
}

struct CaptureCard: View {
    let symbol: String, title: String, detail: String, shortcut: String
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12))
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                KeyCap(shortcut)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hovering ? tint.opacity(0.6) : .secondary.opacity(0.15)))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct PermissionBanner: View {
    @Binding var permitted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Chưa có quyền Ghi màn hình").font(.headline)
                Text("Cấp quyền cho Flashot, sau đó thoát và mở lại app.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Mở Cài đặt hệ thống") {
                CGRequestScreenCaptureAccess()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
        }
        .padding(14)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ShortcutHelp: View {
    private let rows: [(String, String)] = [
        ("R  E  A  P", "Chữ nhật, elip, mũi tên, bút"),
        ("T  N", "Chữ, đánh số"),
        ("M  B", "Làm mờ ô vuông, làm nhòe"),
        ("↩  ⌘C", "Chép vào bộ nhớ tạm"),
        ("⌘S", "Lưu ảnh"),
        ("⌘P", "Ghim lên màn hình"),
        ("⌘Z", "Hoàn tác"),
        ("Esc", "Huỷ"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trong lúc chụp").font(.title3.bold())
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                ForEach(rows, id: \.0) { row in
                    GridRow {
                        KeyCap(row.0)
                        Text(row.1).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: History

struct HistoryView: View {
    private let history = History.shared
    private let settings = Settings.shared

    var body: some View {
        Group {
            if history.items.isEmpty {
                ContentUnavailableView("Chưa có ảnh nào", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Ảnh lưu bằng ⌘S nằm trong \(settings.folder.path)."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
                        ForEach(history.items) { ShotCell(item: $0, compact: false) }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Lịch sử")
        .toolbar {
            Button { history.reload() } label: { Label("Làm mới", systemImage: "arrow.clockwise") }
            Button { NSWorkspace.shared.open(settings.folder) } label: { Label("Mở thư mục", systemImage: "folder") }
        }
        .onAppear { history.reload() }
    }
}

struct ShotCell: View {
    let item: History.Item
    let compact: Bool
    @State private var thumbnail: NSImage?
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Rectangle().fill(.quaternary.opacity(0.5))
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFit().padding(6)
                }
            }
            .frame(height: compact ? 100 : 140)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(hovering ? Color.accentColor : .secondary.opacity(0.15), lineWidth: hovering ? 2 : 1))
            if !compact {
                Text(item.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .help(item.url.lastPathComponent)
        .contextMenu {
            Button("Mở") { NSWorkspace.shared.open(item.url) }
            Button("Sao chép") { History.shared.copy(item) }
            Button("Ghim lên màn hình") { History.shared.pin(item) }
            Button("Hiện trong Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button("Chuyển vào Thùng rác", role: .destructive) { History.shared.trash(item) }
        }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .task(id: item.url) { thumbnail = await Self.thumbnail(item.url) }
    }

    private static func thumbnail(_ url: URL) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceThumbnailMaxPixelSize: 480,
                  ] as CFDictionary) else { return nil }
            return NSImage(cgImage: image, size: .zero)
        }.value
    }
}

// MARK: Settings

struct SettingsView: View {
    @Bindable private var settings = Settings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var permitted = CGPreflightScreenCaptureAccess()

    var body: some View {
        Form {
            Section("Phím tắt") {
                LabeledContent("Chụp vùng") {
                    ShortcutRecorder(shortcut: $settings.regionShortcut, other: settings.fullScreenShortcut, defaultValue: .region)
                }
                LabeledContent("Chụp toàn màn hình") {
                    ShortcutRecorder(shortcut: $settings.fullScreenShortcut, other: settings.regionShortcut, defaultValue: .fullScreen)
                }
            }
            Section("Lưu ảnh") {
                LabeledContent("Thư mục") {
                    HStack {
                        Text(settings.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                        Button("Chọn…", action: chooseFolder)
                    }
                }
                Toggle("Khi chép (Enter) thì lưu luôn một bản vào thư mục", isOn: $settings.autoSave)
            }
            Section("Chung") {
                Toggle("Mở cùng máy", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            Toast.show("Không đổi được: \(error.localizedDescription)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Hiện cửa sổ này khi mở app", isOn: $settings.showWindowAtLaunch)
            }
            Section("Quyền") {
                LabeledContent("Ghi màn hình") {
                    if permitted {
                        Label("Đã cấp", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Cấp quyền…") {
                            CGRequestScreenCaptureAccess()
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                    }
                }
            }
            Section {
                LabeledContent("Phiên bản", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Cài đặt")
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permitted = CGPreflightScreenCaptureAccess()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.folder
        panel.prompt = "Chọn"
        if panel.runModal() == .OK, let url = panel.url { settings.folder = url }
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut
    let other: Shortcut
    let defaultValue: Shortcut
    @State private var recording = false
    @State private var monitor: Any?
    private let settings = Settings.shared

    var body: some View {
        HStack(spacing: 8) {
            if settings.takenShortcuts.contains(shortcut), !recording {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    .help("Ứng dụng khác đang dùng tổ hợp này")
            }
            Button { recording ? stop() : start() } label: {
                Text(recording ? "Nhấn tổ hợp phím…" : shortcut.label)
                    .frame(minWidth: 130)
                    .foregroundStyle(recording ? Color.accentColor : .primary)
            }
            if shortcut != defaultValue, !recording {
                Button { shortcut = defaultValue } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(.borderless)
                    .help("Về mặc định (\(defaultValue.label))")
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        settings.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                stop()
            } else if let new = Shortcut(event: event), new != other {
                shortcut = new
                stop()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording {
            recording = false
            settings.isRecording = false
        }
    }
}
