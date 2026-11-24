import Foundation

enum FixtureError: Error {
    case missing(String)
}

/// Loads one of the saved rivnerun.club pages under `Fixtures/` (the same HTML snapshots
/// the Android project's parser tests use, copied verbatim — see the sibling
/// `rivnerun.club_android/app/src/test/resources/site/` directory).
func fixturePage(_ name: String) throws -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures") else {
        throw FixtureError.missing("Fixtures/\(name).html")
    }
    return try String(contentsOf: url, encoding: .utf8)
}
