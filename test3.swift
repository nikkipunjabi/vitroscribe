import Foundation

let scriptSource = """
tell application "Google Chrome"
    return {}
end tell
"""

let script = NSAppleScript(source: scriptSource)
var error: NSDictionary?
if let output = script?.executeAndReturnError(&error) {
    let count = output.numberOfItems
    print("numberOfItems: \(count)")
    if count > 0 {
        print("Iterating...")
        for i in 1...count {
            print(i)
        }
    }
}
