//
//  PathTests.swift
//  
//
//  Created by Lukáš Valenta on 05.01.2024.
//

import XCTest
import RouterBytes

final class PathTests: XCTestCase {
    func testEmptyStringInit() {
        let sut = Path(rawValue: "")

        XCTAssertEqual(sut.components, [])
    }

    func testOneComponentInit() {
        let component = "test"

        let sut = Path(components: [component])

        XCTAssertEqual(sut.components, [Path.Component(rawValue: "test")])
    }

    func testOneComponentRawValueInit() {
        let component = "test"

        let sut = Path(rawValue: component)

        XCTAssertEqual(sut.components, [Path.Component(rawValue: "test")])
    }

    func testMultipleComponentsInit() {
        let components = ["test", "test2"]

        let sut = Path(components: components)

        XCTAssertEqual(sut.components, [
            Path.Component(rawValue: "test"),
            Path.Component(rawValue: "test2"),
        ])
    }

    func testMultipleComponentsRawValueInit() {
        let component = "test/test2"

        let sut = Path(rawValue: component)

        XCTAssertEqual(sut.components, [
            Path.Component(rawValue: "test"),
            Path.Component(rawValue: "test2"),
        ])
    }

    func testSingleComponentRawValue() {
        let component = "test"

        let sut = Path(rawValue: component)

        XCTAssertEqual(sut.rawValue, component)
    }

    func testMultipleComponentsRawValue() {
        let component = "test/test2"

        let sut = Path(rawValue: component)

        XCTAssertEqual(sut.rawValue, "test/test2")
    }

    func testStringLiteralInit() {
        let sut: Path = "test/test2"

        XCTAssertEqual(sut.rawValue, "test/test2")
    }

    func testStringInterpolationInit() {
        let value = "test/test2"
        let sut: Path = "\(value)"

        XCTAssertEqual(sut.rawValue, value)
    }

    func testStartsWithSlash() {
        let value = "test/test2"
        let sut: Path = "/\(value)"

        XCTAssertEqual(sut.rawValue, value)
    }

    func testAddition() {
        let sut: Path = "test" + "test2"

        XCTAssertEqual(sut.rawValue, "test/test2")
    }

    func testStringAddition() {
        let sut: Path = "test" + String("test2")

        XCTAssertEqual(sut.rawValue, "test/test2")
    }

    func testAdditionInPlace() {
        var sut: Path = "test"

        sut += "test2"

        XCTAssertEqual(sut.rawValue, "test/test2")
    }

    func testStringInterpolation() {
        let testString = "test/test2"
        let sut: Path = "\(testString)"

        XCTAssertEqual("\(sut)", testString)
    }
}
