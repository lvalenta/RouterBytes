//
//  HTTPMethodTests.swift
//  
//
//  Created by Lukáš Valenta on 28.04.2023.
//

import XCTest
import RouterBytes

final class HTTPMethodTests: XCTestCase {
    
    func testConnect() {
        let method = HTTPMethod.connect
        XCTAssertEqual(method.rawValue, "CONNECT")
    }
    
    func testDelete() {
        let method = HTTPMethod.delete
        XCTAssertEqual(method.rawValue, "DELETE")
    }
    
    func testGet() {
        let method = HTTPMethod.get
        XCTAssertEqual(method.rawValue, "GET")
    }
    
    func testHead() {
        let method = HTTPMethod.head
        XCTAssertEqual(method.rawValue, "HEAD")
    }
    
    func testOptions() {
        let method = HTTPMethod.options
        XCTAssertEqual(method.rawValue, "OPTIONS")
    }
    
    func testPatch() {
        let method = HTTPMethod.patch
        XCTAssertEqual(method.rawValue, "PATCH")
    }
    
    func testPost() {
        let method = HTTPMethod.post
        XCTAssertEqual(method.rawValue, "POST")
    }
    
    func testPut() {
        let method = HTTPMethod.put
        XCTAssertEqual(method.rawValue, "PUT")
    }
    
    func testTrace() {
        let method = HTTPMethod.trace
        XCTAssertEqual(method.rawValue, "TRACE")
    }
    
    func testEquatable() {
        XCTAssertEqual(HTTPMethod.get, HTTPMethod.get)
        XCTAssertNotEqual(HTTPMethod.get, HTTPMethod.post)
    }
    
    func testHashable() {
        XCTAssertEqual(HTTPMethod.get.hashValue, HTTPMethod.get.hashValue)
        XCTAssertNotEqual(HTTPMethod.get.hashValue, HTTPMethod.post.hashValue)
    }
    
    func testInitFromString() throws {
        let method = try XCTUnwrap(HTTPMethod("TEST"))
        XCTAssertEqual(method.rawValue, "TEST")
    }

    func testInitFromInvalidString() {
        XCTAssertNil(HTTPMethod("in valid"))
    }
}
