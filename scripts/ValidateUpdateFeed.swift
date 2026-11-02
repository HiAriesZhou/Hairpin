import Foundation
import CryptoKit

// Release gate: validate with the bundled public key, without accessing a
// private key. Run after notarization and feed generation, before publication.
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw NSError(domain: "UpdateFeed", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

func verifiedFeed(_ path: String, key: Curve25519.Signing.PublicKey) throws -> XMLDocument {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let marker = Data("<!-- sparkle-signatures:\n".utf8)
    guard let range = data.range(of: marker, options: .backwards),
          let trailer = String(data: data[range.lowerBound...], encoding: .utf8) else {
        throw NSError(domain: "UpdateFeed", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing signed feed trailer"])
    }
    let lines = trailer.components(separatedBy: "\n")
    try require(lines.count == 5 && lines[3] == "-->" && lines[4].isEmpty, "Unexpected feed signature trailer")
    try require(lines[1].hasPrefix("edSignature: ") && lines[2].hasPrefix("length: "), "Invalid signature metadata")
    let signature = Data(base64Encoded: String(lines[1].dropFirst(13))) ?? Data()
    let length = Int(lines[2].dropFirst(8))
    try require(length == range.lowerBound, "Feed signed length mismatch")
    try require(key.isValidSignature(signature, for: data.prefix(range.lowerBound)), "Invalid feed signature")
    return try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
}

func items(_ document: XMLDocument) throws -> [XMLElement] {
    try document.nodes(forXPath: "/rss/channel/item").compactMap { $0 as? XMLElement }
}

func text(_ item: XMLElement, _ name: String) -> String {
    item.elements(forName: name).first?.stringValue ?? ""
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    try require(args.count >= 3, "Usage: ValidateUpdateFeed.swift verify FEED KEY | validate FEED DMG BUILD VERSION URL KEY [PREVIOUS_FEED]")
    let verifyingOnly = args[0] == "verify"
    try require(verifyingOnly ? args.count == 3 : (args[0] == "validate" && (args.count == 7 || args.count == 8)), "Invalid arguments")
    let keyPath = args[verifyingOnly ? 2 : 6]
    let keyText = try String(contentsOfFile: keyPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: keyText) ?? Data())
    let feed = try verifiedFeed(args[1], key: key)
    if !verifyingOnly {
        let entries = try items(feed)
        try require(!entries.isEmpty, "Empty update feed")
        let build = args[3]
        let matches = entries.filter { text($0, "sparkle:version") == build }
        try require(matches.count == 1 && entries.first === matches.first, "Current build must be the first, unique item")
        let item = matches[0]
        try require(text(item, "sparkle:shortVersionString") == args[4], "Display version mismatch")
        try require(text(item, "sparkle:minimumSystemVersion") == "13.0", "Unexpected minimum macOS")
        try require(item.elements(forName: "sparkle:deltas").isEmpty, "Delta updates are not supported by this release pipeline")
        let enclosures = item.elements(forName: "enclosure")
        try require(enclosures.count == 1, "Expected one full update enclosure")
        let enclosure = enclosures[0]
        try require(enclosure.attribute(forName: "url")?.stringValue == args[5], "Unpinned or incorrect download URL")
        let archive = try Data(contentsOf: URL(fileURLWithPath: args[2]), options: .mappedIfSafe)
        try require(enclosure.attribute(forName: "length")?.stringValue == String(archive.count), "Archive length mismatch")
        let signature = Data(base64Encoded: enclosure.attribute(forName: "sparkle:edSignature")?.stringValue ?? "") ?? Data()
        try require(key.isValidSignature(signature, for: archive), "Invalid archive signature")
        if args.count == 8 {
            let previous = try items(verifiedFeed(args[7], key: key))
            let oldBuilds = previous.compactMap { UInt64(text($0, "sparkle:version")) }
            try require(oldBuilds.count == previous.count && UInt64(build) != nil, "Builds must be integers")
            try require(UInt64(build)! > (oldBuilds.max() ?? 0), "Build number must increase beyond the published feed")
        }
    }
    print("Update feed verified")
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
