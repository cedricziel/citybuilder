import Foundation
import GameDataModel

let outcome = GameDataCommand.run(
    Array(CommandLine.arguments.dropFirst()),
    standardInput: { FileHandle.standardInput.readDataToEndOfFile() },
    currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
)
FileHandle.standardOutput.write(Data(outcome.output.utf8))
FileHandle.standardError.write(Data(outcome.error.utf8))
exit(outcome.status)
