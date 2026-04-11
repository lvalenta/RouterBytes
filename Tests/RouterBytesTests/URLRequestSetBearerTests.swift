//
//  URLRequestSetBearerTests.swift
//  
//
//  Created by Lukáš Valenta on 01.05.2023.
//

import XCTest
import RouterBytes

final class URLRequestSetBearerTests: XCTestCase {
    func testSetBearerToken() throws {
        var request = HTTPRequest(method: .get, url: URL(string: "https://example.com/api")!)
        request.setBearerToken("abc123")
        
        XCTAssertEqual(request.headerFields[.authorization], "Bearer abc123")
    }

    func testWithBearerToken() {
        let originalRequest = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
        let request = originalRequest.withBearerToken("test-token")
        
        XCTAssertEqual(request.headerFields[.authorization], "Bearer test-token")

        var updatedRequestWithSetBearerFunction = originalRequest
        updatedRequestWithSetBearerFunction.setBearerToken("test-token")
        XCTAssertEqual(request, updatedRequestWithSetBearerFunction)
    }
}
