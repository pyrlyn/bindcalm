import AppKit
import BindcalmCore

// Headless modes exist so the scanners can be verified (and scripted) without the GUI.
let arguments = CommandLine.arguments
if arguments.contains("--dump") || arguments.contains("--probe-symbols") || arguments.contains("--help") {
    CLI.run(arguments)
} else {
    BindcalmApp.main()
}
