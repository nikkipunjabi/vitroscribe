import Foundation

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
    print("numberOfItems: \(output.numberOfItems)")
    print("stringValue: \(String(describing: output.stringValue))")
    
    var urls: [String] = []
    for i in 1...output.numberOfItems {
        if let itemStr = output.atIndex(i)?.stringValue {
            urls.append(itemStr)
        }
    }
    if urls.isEmpty, let singleStr = output.stringValue {
        urls = singleStr.components(separatedBy: ", ")
    }
    print("Parsed URLs:")
    for url in urls {
        print(" - '\(url)'")
    }
} else {
    print("Error: \(String(describing: error))")
}
