import Foundation
import CryptoKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let key = Curve25519.Signing.PrivateKey()
let archive = Data("Synthetic update archive for release-gate tests".utf8)
try archive.write(to: directory.appendingPathComponent("Hairpin.dmg"))
try Data("Interrupted archive".utf8).write(to: directory.appendingPathComponent("broken.dmg"))
try key.publicKey.rawRepresentation.base64EncodedString().write(to: directory.appendingPathComponent("public-key"), atomically: true, encoding: .utf8)
let url = "https://github.com/HiAriesZhou/Hairpin/releases/download/v0.3.0/Hairpin.dmg"
let archiveSignature = try key.signature(for: archive).base64EncodedString()
func feed(_ build: Int, _ name: String, downloadURL: String = url, signature: String = archiveSignature) throws {
    let content = Data("""
    <?xml version="1.0" encoding="utf-8"?>
    <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0"><channel><title>Test</title><item>
    <sparkle:version>\(build)</sparkle:version><sparkle:shortVersionString>0.3.0</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <enclosure url="\(downloadURL)" length="\(archive.count)" type="application/octet-stream" sparkle:edSignature="\(signature)"/>
    </item></channel></rss>

    """.utf8)
    let signature = try key.signature(for: content).base64EncodedString()
    var signed = content
    signed.append(Data("<!-- sparkle-signatures:\nedSignature: \(signature)\nlength: \(content.count)\n-->\n".utf8))
    try signed.write(to: directory.appendingPathComponent(name))
}
try feed(100, "valid.xml")
try feed(99, "previous.xml")
try feed(100, "same-build.xml")
try feed(101, "future.xml")
try feed(100, "unpinned.xml", downloadURL: "https://github.com/HiAriesZhou/Hairpin/releases/latest/download/Hairpin.dmg")
try feed(100, "bad-archive-signature.xml", signature: Data(repeating: 0, count: 64).base64EncodedString())
let valid = try Data(contentsOf: directory.appendingPathComponent("valid.xml"))
var tampered = valid
tampered[10] ^= 1
try tampered.write(to: directory.appendingPathComponent("tampered.xml"))
try Data(valid.prefix(100)).write(to: directory.appendingPathComponent("truncated.xml"))
