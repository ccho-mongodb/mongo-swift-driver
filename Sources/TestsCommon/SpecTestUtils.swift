import Foundation
import MongoSwift
import XCTest

extension MongoSwiftTestCase {
    /// Gets the path of the directory containing spec files, depending on whether
    /// we're running from XCode or the command line
    static var specsPath: String {
        // if we can access the "/Tests" directory, assume we're running from command line
        if FileManager.default.fileExists(atPath: "./Tests") {
            return "./Tests/Specs"
        }
        // otherwise we're in Xcode, get the bundle's resource path
        guard let path = Bundle(for: self).resourcePath else {
            XCTFail("Missing resource path")
            return ""
        }
        return path
    }
}

extension Document {
    public init(fromJSONFile file: URL) throws {
        let jsonString = try String(contentsOf: file, encoding: .utf8)
        try self.init(fromJSON: jsonString)
    }
}

/// Given a spec folder name (e.g. "crud") and optionally a subdirectory name for a folder (e.g. "read") retrieves an
/// array of [(filename, file decoded to type T)].
public func retrieveSpecTestFiles<T: Decodable>(
    specName: String,
    subdirectory: String? = nil,
    asType _: T.Type
) throws -> [(String, T)] {
    var path = "\(MongoSwiftTestCase.specsPath)/\(specName)/tests"
    if let sd = subdirectory {
        path += "/\(sd)"
    }
    return try FileManager.default
        .contentsOfDirectory(atPath: path)
        .filter { $0.hasSuffix(".json") }
        .map { filename in
            let url = URL(fileURLWithPath: "\(path)/\(filename)")
            var doc = try Document(fromJSONFile: url)
            doc["name"] = .string(filename)
            return try (filename, BSONDecoder().decode(T.self, from: doc))
        }
}

/// Given two documents, returns a copy of the input document with all keys that *don't*
/// exist in `standard` removed, and with all matching keys put in the same order they
/// appear in `standard`.
public func rearrangeDoc(_ input: Document, toLookLike standard: Document) -> Document {
    var output = Document()
    for (k, v) in standard {
        switch (v, input[k]) {
        case let (.document(sDoc), .document(iDoc)?):
            output[k] = .document(rearrangeDoc(iDoc, toLookLike: sDoc))
        case let (.array(sArr), .array(iArr)?):
            var newArr: [BSON] = []
            for (i, el) in iArr.enumerated() {
                if let docEl = el.documentValue, let sDoc = sArr[i].documentValue {
                    newArr.append(.document(rearrangeDoc(docEl, toLookLike: sDoc)))
                } else {
                    newArr.append(el)
                }
            }
            output[k] = .array(newArr)
        default:
            output[k] = input[k]
        }
    }
    return output
}

public func fileLevelLog(_ message: String) {
    print("\n------------\n\(message)\n")
}
