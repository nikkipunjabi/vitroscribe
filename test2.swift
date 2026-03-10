import Foundation
import ScriptingBridge

let scriptSource = """
tell application "Google Chrome"
    set urlList to {}
    repeat with w in windows
        repeat with t in tabs of w
            set end of urlList to URL of t
        end repeat
    end repeat
    return urlList
end tell
"""

let script = NSAppleScript(source: scriptSource)
var error: NSDictionary?
if let output = script?.executeAndReturnError(&error) {
    print("Success")
} else {
    print("Error: \(String(describing: error))")
}
