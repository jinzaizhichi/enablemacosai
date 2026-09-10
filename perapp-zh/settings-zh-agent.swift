import AppKit
// settings-zh-agent —— 让「系统设置」每次都以中文界面启动,Dock 只钉真正的系统设置(单图标)。
// 1) 系统设置 willLaunch 时若命令行没带 -AppleLanguages:在窗口出现前结束并带参数重开;带参数的实例放行。
// 2) 自身注册为 x-apple.systempreferences: 深链接处理器,收到 URL 后 open -a "System Settings" <url> --args -AppleLanguages …,
//    权限弹窗 / Spotlight / 控制中心的「打开系统设置」既是中文又能落到目标面板。
// 安全阀:60 秒内重开 4 次即暂停拦截 5 分钟(防止未来系统不认参数时无限杀 / 重开)。
let target = "com.apple.systempreferences"
let langArg = ProcessInfo.processInfo.environment["SETTINGS_ZH_LANGS"] ?? "(zh-Hans,en)"
let logPath = NSString(string: "~/Library/Logs/settings-zh-agent.log").expandingTildeInPath
var handled = Set<pid_t>(); var lastRelaunch = Date.distantPast; var kills: [Date] = []; var pausedUntil = Date.distantPast
let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
func log(_ s: String) {
    let line = "[\(df.string(from: Date()))] \(s)\n"
    if let sz = (try? FileManager.default.attributesOfItem(atPath: logPath))?[.size] as? Int, sz > 512 * 1024 { try? FileManager.default.removeItem(atPath: logPath) }
    if let h = FileHandle(forWritingAtPath: logPath) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
    else { FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8)) }
}
func run(_ exe: String, _ args: [String]) -> (Int32, String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = out
    do { try p.run() } catch { return (-1, "\(error)") }; p.waitUntilExit()
    return (p.terminationStatus, String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
}
func argsOf(_ pid: pid_t) -> String { run("/bin/ps", ["-o", "args=", "-p", "\(pid)"]).1 }
func openSettings(url: String?) {
    var a = ["-a", "System Settings"]; if let u = url { a.append(u) }; a += ["--args", "-AppleLanguages", langArg]
    for _ in 0..<25 { let (st, _) = run("/usr/bin/open", a); if st == 0 { return }; Thread.sleep(forTimeInterval: 0.2) }
    log("open failed after retries (url=\(url ?? "-"))")
}
func check(_ app: NSRunningApplication, _ src: String) {
    guard app.bundleIdentifier == target, app.processIdentifier > 0, !handled.contains(app.processIdentifier) else { return }
    handled.insert(app.processIdentifier)
    let tNotify = Date(), pid = app.processIdentifier
    if argsOf(pid).contains("-AppleLanguages") { log("pid \(pid) via \(src): has -AppleLanguages, pass"); return }
    if Date() < pausedUntil { log("pid \(pid): interception paused (circuit breaker)"); return }
    if Date().timeIntervalSince(lastRelaunch) < 2 { log("pid \(pid): throttled"); return }
    kills = kills.filter { Date().timeIntervalSince($0) < 60 }
    if kills.count >= 4 { pausedUntil = Date().addingTimeInterval(300); log("circuit breaker: 4 relaunches within 60 s → pause 5 min"); return }
    kills.append(Date()); lastRelaunch = Date()
    let shown = ((CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? [])
        .filter { ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid) && ($0[kCGWindowLayer as String] as? Int ?? 1) == 0 }.count
    kill(pid, SIGKILL)
    var n = 0; while kill(pid, 0) == 0 && n < 100 { Thread.sleep(forTimeInterval: 0.02); n += 1 }
    log("pid \(pid) via \(src): no -AppleLanguages → killed in \(Int(Date().timeIntervalSince(tNotify)*1000)) ms (on-screen windows at kill: \(shown)), relaunching")
    openSettings(url: nil)
}
class URLHandler: NSObject {
    @objc func handle(_ event: NSAppleEventDescriptor, with reply: NSAppleEventDescriptor) {
        guard let u = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else { return }
        log("deep link: \(u) → forwarding with -AppleLanguages"); openSettings(url: u)
    }
}
let urlHandler = URLHandler()
NSAppleEventManager.shared().setEventHandler(urlHandler, andSelector: #selector(URLHandler.handle(_:with:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
let nc = NSWorkspace.shared.notificationCenter
nc.addObserver(forName: NSWorkspace.willLaunchApplicationNotification, object: nil, queue: .main) { n in
    if let a = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { check(a, "willLaunch") } }
nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { n in
    if let a = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { check(a, "didLaunch") } }
nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { n in
    if let a = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, a.bundleIdentifier == target { handled.remove(a.processIdentifier) } }
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    for a in NSWorkspace.shared.runningApplications where a.bundleIdentifier == target { check(a, "poll") } }
log("settings-zh-agent started (pid \(getpid())), langs=\(langArg)")
let app = NSApplication.shared; app.setActivationPolicy(.prohibited); app.run()
