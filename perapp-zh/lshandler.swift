import Foundation
import CoreServices
// lshandler get <scheme> | set <scheme> <bundle-id> —— 查看 / 设置 URL scheme 的默认处理 App
let a = CommandLine.arguments
func cur(_ s: String) -> String {
    let cfs: CFString = s as CFString
    guard let h = LSCopyDefaultHandlerForURLScheme(cfs) else { return "(none)" }
    let v: CFString = h.takeRetainedValue()
    return String(describing: v)
}
if a.count >= 3 && a[1] == "get" { print(cur(a[2])) }
else if a.count >= 4 && a[1] == "set" {
    let st = LSSetDefaultHandlerForURLScheme(a[2] as CFString, a[3] as CFString)
    let now = cur(a[2]); print("status \(st) → now: \(now)"); exit(now.lowercased() == a[3].lowercased() ? 0 : 1)
} else { FileHandle.standardError.write("usage: lshandler get <scheme> | set <scheme> <bundle-id>\n".data(using: .utf8)!); exit(2) }
