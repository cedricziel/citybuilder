// Prints the window number of the first on-screen window owned by a process, for
// `screencapture -l<windowid>`. Usage: xcrun swift mac-window-id.swift <pid>
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: mac-window-id.swift <pid>\n".utf8))
    exit(2)
}

let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window[kCGWindowOwnerPID as String] as? Int32) == pid {
    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    let width = (window[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0
    if layer == 0, width >= 100, let number = window[kCGWindowNumber as String] as? Int {
        print(number)
        exit(0)
    }
}

FileHandle.standardError.write(Data("no window for pid \(pid)\n".utf8))
exit(1)
