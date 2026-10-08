import Foundation
import SpriteContentGate

let report = try SpriteContentGate.run(arguments: Array(CommandLine.arguments.dropFirst()))
FileHandle.standardOutput.write(Data(report.output.utf8))
exit(report.exitCode)
