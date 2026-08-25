import Foundation
import XCTest
@testable import KittenTag

final class FileRenameTransactionTests: XCTestCase {
    func testRenamesMultipleFiles() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("one.flac")
        let second = directory.appendingPathComponent("two.flac")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)

        try FileRenameTransaction.execute([
            FileRenamePlan(source: first, destination: directory.appendingPathComponent("01.flac")),
            FileRenamePlan(source: second, destination: directory.appendingPathComponent("02.flac"))
        ])

        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("01.flac"), encoding: .utf8), "one")
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("02.flac"), encoding: .utf8), "two")
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
    }

    func testSupportsNameSwapWithoutOverwriting() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("one.flac")
        let second = directory.appendingPathComponent("two.flac")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)

        try FileRenameTransaction.execute([
            FileRenamePlan(source: first, destination: second),
            FileRenamePlan(source: second, destination: first)
        ])

        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "two")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "one")
    }

    func testRollsEveryFileBackWhenSecondPhaseFails() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("one.flac")
        let second = directory.appendingPathComponent("two.flac")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)
        var moveCount = 0
        var didInjectFailure = false
        let operations = FileRenameOperations(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            move: { source, destination in
                moveCount += 1
                if moveCount == 4 && !didInjectFailure {
                    didInjectFailure = true
                    throw CocoaError(.fileWriteUnknown)
                }
                try FileManager.default.moveItem(at: source, to: destination)
            }
        )

        XCTAssertThrowsError(try FileRenameTransaction.execute([
            FileRenamePlan(source: first, destination: directory.appendingPathComponent("01.flac")),
            FileRenamePlan(source: second, destination: directory.appendingPathComponent("02.flac"))
        ], operations: operations))

        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "one")
        XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "two")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("01.flac").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("02.flac").path))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix(".kittentag-rename-") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testRejectsExistingDestinationBeforeMovingAnything() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("one.flac")
        let destination = directory.appendingPathComponent("existing.flac")
        try Data("source".utf8).write(to: source)
        try Data("existing".utf8).write(to: destination)

        XCTAssertThrowsError(try FileRenameTransaction.execute([
            FileRenamePlan(source: source, destination: destination)
        ]))
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "source")
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "existing")
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kittentag-rename-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
