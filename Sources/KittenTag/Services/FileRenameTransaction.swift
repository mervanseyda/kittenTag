import Foundation

struct FileRenamePlan: Equatable {
    let source: URL
    let destination: URL
}

struct FileRenameOperations: @unchecked Sendable {
    var fileExists: (URL) -> Bool
    var move: (URL, URL) throws -> Void

    static let live = FileRenameOperations(
        fileExists: { FileManager.default.fileExists(atPath: $0.path) },
        move: { try FileManager.default.moveItem(at: $0, to: $1) }
    )
}

enum FileRenameTransactionError: LocalizedError {
    case duplicateDestination(String)
    case destinationExists(String)
    case moveFailed(String, Error)
    case rollbackFailed(originalError: Error, failures: [String])

    var errorDescription: String? {
        switch self {
        case .duplicateDestination(let name):
            return L10n.format("Şablon birden fazla dosya için “%@” adını üretiyor.", name)
        case .destinationExists(let name):
            return L10n.format("“%@” zaten var. Hiçbir dosya yeniden adlandırılmadı.", name)
        case .moveFailed(let name, let error):
            return L10n.format("“%@” yeniden adlandırılamadı: %@", name, error.localizedDescription)
        case .rollbackFailed(let originalError, let failures):
            return L10n.format("Yeniden adlandırma tamamlanamadı ve bazı dosyalar eski adına döndürülemedi: %@\n%@", originalError.localizedDescription, failures.joined(separator: "\n"))
        }
    }
}

enum FileRenameTransaction {
    private struct StagedFile {
        let source: URL
        let destination: URL
        let temporary: URL
    }

    static func execute(
        _ plans: [FileRenamePlan],
        operations: FileRenameOperations = .live
    ) throws {
        let plans = plans.filter { exactKey($0.source) != exactKey($0.destination) }
        guard !plans.isEmpty else { return }

        var destinationKeys = Set<String>()
        for plan in plans where !destinationKeys.insert(standardizedKey(plan.destination)).inserted {
            throw FileRenameTransactionError.duplicateDestination(plan.destination.lastPathComponent)
        }

        let sourceKeys = Set(plans.map { standardizedKey($0.source) })
        for plan in plans where operations.fileExists(plan.destination) && !sourceKeys.contains(standardizedKey(plan.destination)) {
            throw FileRenameTransactionError.destinationExists(plan.destination.lastPathComponent)
        }

        let staged = plans.map { plan in
            StagedFile(
                source: plan.source,
                destination: plan.destination,
                temporary: unusedTemporaryURL(beside: plan.source, operations: operations)
            )
        }

        var movedToTemporary: [StagedFile] = []
        do {
            for file in staged {
                try operations.move(file.source, file.temporary)
                movedToTemporary.append(file)
            }
        } catch {
            let failures = rollbackTemporaryFiles(movedToTemporary.reversed(), operations: operations)
            if failures.isEmpty {
                throw FileRenameTransactionError.moveFailed(movedToTemporary.last?.source.lastPathComponent ?? L10n.string("Dosya"), error)
            }
            throw FileRenameTransactionError.rollbackFailed(originalError: error, failures: failures)
        }

        var movedToDestination: [StagedFile] = []
        do {
            for file in staged {
                try operations.move(file.temporary, file.destination)
                movedToDestination.append(file)
            }
        } catch {
            var failures: [String] = []
            for file in movedToDestination.reversed() {
                do { try operations.move(file.destination, file.temporary) }
                catch { failures.append("\(file.destination.lastPathComponent): \(error.localizedDescription)") }
            }
            failures += rollbackTemporaryFiles(staged.reversed(), operations: operations)
            if failures.isEmpty {
                let current = staged.dropFirst(movedToDestination.count).first
                throw FileRenameTransactionError.moveFailed(current?.source.lastPathComponent ?? L10n.string("Dosya"), error)
            }
            throw FileRenameTransactionError.rollbackFailed(originalError: error, failures: failures)
        }
    }

    private static func rollbackTemporaryFiles<S: Sequence>(
        _ files: S,
        operations: FileRenameOperations
    ) -> [String] where S.Element == StagedFile {
        var failures: [String] = []
        for file in files where operations.fileExists(file.temporary) {
            do { try operations.move(file.temporary, file.source) }
            catch { failures.append("\(file.source.lastPathComponent): \(error.localizedDescription)") }
        }
        return failures
    }

    private static func unusedTemporaryURL(beside source: URL, operations: FileRenameOperations) -> URL {
        let directory = source.deletingLastPathComponent()
        while true {
            let candidate = directory.appendingPathComponent(".kittentag-rename-\(UUID().uuidString).tmp")
            if !operations.fileExists(candidate) { return candidate }
        }
    }

    private static func standardizedKey(_ url: URL) -> String {
        url.standardizedFileURL.path.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func exactKey(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}
