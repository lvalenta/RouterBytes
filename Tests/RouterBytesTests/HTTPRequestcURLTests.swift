//
//  HTTPRequestcURLTests.swift
//  
//
//  Created by Lukáš Valenta on 30.04.2023.
//

import Foundation
import XCTest
import RouterBytes

class HTTPRequestcURLTests: XCTestCase {
    let url = URL(string: "https://www.example.com")!
    var request: HTTPRequest!
    var body: Data?
    
    override func setUp() {
        super.setUp()

        let headerFields: HTTPFields = [.contentType: "application/json"]
        body = "{\"name\":\"John Doe\", \"age\":30}".data(using: .utf8)
        request = HTTPRequest(method: .post, url: url, headerFields: headerFields)
    }
    
    func testCurlCommand() {
        let expectedCurlCommand = "curl --request POST\\\n--url 'https://www.example.com/'\\\n--header 'Content-Type: application/json'\\\n--data '{\n  \"name\" : \"John Doe\",\n  \"age\" : 30\n}'"
        
        let curlCommand = request.cURL(body: body, pretty: true)
        XCTAssertEqual(curlCommand, expectedCurlCommand)
    }
    
    func testCurlCommandWithNoBody() {
        body = nil
        let expectedCurlCommand = "curl --request POST\\\n--url 'https://www.example.com/'\\\n--header 'Content-Type: application/json'"
        
        let curlCommand = request.cURL(body: body, pretty: true)
        XCTAssertEqual(curlCommand, expectedCurlCommand)
    }

    func testCurlCommandWithNoBodyNotPretty() {
        body = nil
        let expectedCurlCommand = "curl -X POST 'https://www.example.com/' -H 'Content-Type: application/json'"
        
        let curlCommand = request.cURL(body: body, pretty: false)
        XCTAssertEqual(curlCommand, expectedCurlCommand)
    }

    func testCurlCommandWithDefaultOptions() {
        let expectedCurlCommand = "curl -X POST 'https://www.example.com/' -H 'Content-Type: application/json' --data '{\"name\":\"John Doe\", \"age\":30}'"
        
        let curlCommand = request.cURL(body: body)
        XCTAssertEqual(curlCommand, expectedCurlCommand)
    }
}
