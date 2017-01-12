//
//  RedundantVoidReturnRule.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 12/26/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct RedundantVoidReturnRule: ASTRule, ConfigurationProviderRule, CorrectableRule {

    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "redundant_void_return",
        name: "Redundant Void Return",
        description: "Returning Void in a function declaration is redundant.",
        nonTriggeringExamples: [
            "func foo() {}\n",
            "func foo() -> Int {}\n",
            "func foo() -> Int -> Void {}\n",
            "let foo: Int -> Void\n",
            "func foo() -> Int -> () {}\n",
            "let foo: Int -> ()\n"
        ],
        triggeringExamples: [
            "func foo()↓ -> Void {}\n",
            "protocol Foo {\n func foo()↓ -> Void\n}\n",
            "func foo()↓ -> () {}\n",
            "protocol Foo {\n func foo()↓ -> ()\n}\n"
        ],
        corrections: [
            "func foo()↓ -> Void {}\n": "func foo() {}\n",
            "protocol Foo {\n func foo()↓ -> Void\n}\n": "protocol Foo {\n func foo()\n}\n",
            "func foo()↓ -> () {}\n": "func foo() {}\n",
            "protocol Foo {\n func foo()↓ -> ()\n}\n": "protocol Foo {\n func foo()\n}\n"
        ]
    )

    private let pattern = "\\s*->\\s*(?:Void|\\(\\s*\\))"

    public func validate(file: File, kind: SwiftDeclarationKind,
                         dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        return violationRanges(in: file, kind: kind, dictionary: dictionary).map {
            StyleViolation(ruleDescription: type(of: self).description,
                           severity: configuration.severity,
                           location: Location(file: file, characterOffset: $0.location))
        }
    }

    private func violationRanges(in file: File, kind: SwiftDeclarationKind,
                                 dictionary: [String: SourceKitRepresentable]) -> [NSRange] {
        guard SwiftDeclarationKind.functionKinds().contains(kind),
            let nameOffset = (dictionary["key.nameoffset"] as? Int64).flatMap({ Int($0) }),
            let nameLength = (dictionary["key.namelength"] as? Int64).flatMap({ Int($0) }),
            let length = (dictionary["key.length"] as? Int64).flatMap({ Int($0) }),
            let offset = (dictionary["key.offset"] as? Int64).flatMap({ Int($0) }),
            case let start = nameOffset + nameLength,
            case let end = (dictionary["key.bodyoffset"] as? Int64).flatMap({ Int($0) }) ?? offset + length,
            case let contents = file.contents.bridge(),
            let range = contents.byteRangeToNSRange(start: start, length: end - start),
            case let kinds = excludingKinds(),
            file.match(pattern: "->", excludingSyntaxKinds: kinds, range: range).count == 1,
            let match = file.match(pattern: pattern, excludingSyntaxKinds: kinds, range: range).first else {
                return []
        }

        return [match]
    }

    private func excludingKinds() -> [SyntaxKind] {
        return SyntaxKind.allKinds().filter { $0 != .typeidentifier }
    }

    private func violationRanges(in file: File, dictionary: [String: SourceKitRepresentable]) -> [NSRange] {
        return dictionary.substructure.flatMap { subDict -> [NSRange] in
            guard let kindString = subDict["key.kind"] as? String,
                let kind = SwiftDeclarationKind(rawValue: kindString) else {
                    return []
            }
            return violationRanges(in: file, dictionary: subDict) +
                violationRanges(in: file, kind: kind, dictionary: subDict)
        }
    }

    private func violationRanges(in file: File) -> [NSRange] {
        return violationRanges(in: file, dictionary: file.structure.dictionary).sorted { lh, rh in
            lh.location < rh.location
        }
    }

    public func correct(file: File) -> [Correction] {
        let violatingRanges = file.ruleEnabled(violatingRanges: violationRanges(in: file), for: self)
        var correctedContents = file.contents
        var adjustedLocations = [Int]()

        for violatingRange in violatingRanges.reversed() {
            if let indexRange = correctedContents.nsrangeToIndexRange(violatingRange) {
                correctedContents = correctedContents.replacingCharacters(in: indexRange, with: "")
                adjustedLocations.insert(violatingRange.location, at: 0)
            }
        }

        file.write(correctedContents)

        return adjustedLocations.map {
            Correction(ruleDescription: type(of: self).description,
                       location: Location(file: file, characterOffset: $0))
        }
    }

}
