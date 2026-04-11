//
//  APIRouterTests.swift
//  
//
//  Created by Lukáš Valenta on 28.04.2023.
//

import XCTest
import RouterBytes

final class APIRouterTests: XCTestCase {

    func testDefaultAPIRouter() throws {
           let router = BaseAPIRouter<EmptyCodable, Data>(
               hostname: URL(string: "https://example.com")!,
               path: "/test",
               authType: .none,
               body: EmptyCodable()
           )

        let expectedURL = URL(string: "https://example.com/test")!

        XCTAssertEqual(try router.asURL(), expectedURL)
        let request = try router.asHTTPRequest()
        XCTAssertEqual(request.url, expectedURL)
        XCTAssertEqual(request.method.rawValue, HTTPMethod.get.rawValue)
        XCTAssertEqual(try router.encodedBody(), try JSONEncoder().encode(.empty))
        XCTAssertEqual(headersDictionary(from: request), ["Content-Type": "application/json"])
    }
    
    func testAsURL() throws {
        let router = BaseAPIRouter<String, Data>(
            hostname: URL(string: "https://example.com")!,
            path: "/api/test",
            authType: .none,
            queryItems: ["param1": "value1", "param2": "value2"],
            body: ""
        )
        
        let url = try router.asURL()
        XCTAssertTrue(url.absoluteString.contains("https://example.com/api/test"))
        XCTAssertTrue(url.absoluteString.contains("?param1=value1&param2=value2") || url.absoluteString.contains("?param2=value2&param1=value1"))
    }

    func testAsURLHostnameWithPath() throws {
        let router = BaseAPIRouter<String, Data>(
            hostname: URL(string: "https://example.com/path")!,
            path: "/api/test",
            authType: .none,
            queryItems: ["param1": "value1", "param2": "value2"],
            body: ""
        )
        
        let url = try router.asURL()
        XCTAssertTrue(url.absoluteString.contains("https://example.com/path/api/test"))
        XCTAssertTrue(url.absoluteString.contains("?param1=value1&param2=value2") || url.absoluteString.contains("?param2=value2&param1=value1"))
    }
    
    func testAsURLRequest() throws {
        let router = BaseAPIRouter<String, Data>(
            hostname: URL(string: "https://example.com")!,
            path: "/api/test",
            authType: .none,
            queryItems: ["param1": "value1", "param2": "value2"],
            method: .post,
            body: "Test Body"
        )
        
        let request = try router.asHTTPRequest()
        
        XCTAssertEqual(request.method.rawValue, "POST")
        XCTAssertEqual(headersDictionary(from: request), ["Content-Type": "application/json"])
        
        let url = try XCTUnwrap(request.url)
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/api/test"))
        XCTAssertTrue(url.absoluteString.contains("?param1=value1&param2=value2") || url.absoluteString.contains("?param2=value2&param1=value1"))

        XCTAssertEqual(try router.encodedBody(), "\"Test Body\"".data(using: .utf8))
    }
    
    func testAsURLWithAdditionalHeadersAndQueryItems() throws {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaderFields: [.init("header1")!: "value1", .init("header2")!: "value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaderFields: [.init("header3")!: "header3"],
            queryItems: ["page": "1", "perPage": "20"],
            body: EmptyCodable()
        )

        let url = try router.asURL()
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/users"))
        XCTAssertTrue(url.absoluteString.contains("?page=1&perPage=20") || url.absoluteString.contains("?perPage=20&page=1"))
    }

    func testAsURLRequstWithAdditionalHeadersAndQueryItems() throws {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaderFields: [.init("header1")!: "value1", .init("header2")!: "value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaderFields: [.init("header3")!: "value3"],
            queryItems: ["page": "1", "perPage": "20"],
            body: EmptyCodable()
        )

        let request = try router.asHTTPRequest()

        let url = try XCTUnwrap(request.url)
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/users"))
        XCTAssertTrue(url.absoluteString.contains("?page=1&perPage=20") || url.absoluteString.contains("?perPage=20&page=1"))
        XCTAssertEqual(headersDictionary(from: request), ["Content-Type": "application/json", "header1":"value1", "header2":"value2", "header3": "value3"])
        XCTAssertEqual(try router.encodedBody(), try JSONEncoder().encode(EmptyCodable()))
    }

    func testAsURLRequstWithOverridingDefaultHeaderWithAdditionalHeaders() throws {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaderFields: [.init("Content-Type")!: "test", .init("header1")!: "value1", .init("header2")!: "value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaderFields: [.init("header1")!: "value3"],
            queryItems: ["page": "1", "perPage": "20"],
            body: EmptyCodable()
        )

        let request = try router.asHTTPRequest()

        let url = try XCTUnwrap(request.url)
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/users"))
        XCTAssertTrue(url.absoluteString.contains("?page=1&perPage=20") || url.absoluteString.contains("?perPage=20&page=1"))
        XCTAssertEqual(headersDictionary(from: request), ["Content-Type": "test", "header1":"value3", "header2":"value2"])
        XCTAssertEqual(try router.encodedBody(), try JSONEncoder().encode(.empty))
    }

    func testHeaderFields() {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaderFields: [.init("header1")!: "defaultValue", .init("header2")!: "value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaderFields: [.init("header1")!: "overrideValue"],
            body: EmptyCodable()
        )

        XCTAssertEqual(router.headerFields[.init("header1")!], "defaultValue, overrideValue")
        XCTAssertEqual(router.headerFields[.init("header2")!], "value2")
    }

    func testHeaderFieldsWithSameNameUsesAdditionalValueInRequest() throws {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaderFields: [.init("header1")!: "defaultValue", .init("header2")!: "value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaderFields: [.init("header1")!: "overrideValue"],
            body: EmptyCodable()
        )
        let request = try router.asHTTPRequest(hostname: URL(string: "https://lvalenta.cz")!)
        
        XCTAssertEqual(request.headerFields[.init("header1")!], "overrideValue")
        XCTAssertEqual(request.headerFields[.init("header2")!], "value2")
    }

    func testAsURLRequestWithPOSTMethod() throws {
        struct CreateUserRequest: Encodable {
            let name: String
            let email: String
            let password: String
        }

        let createUserRequest = CreateUserRequest(name: "John Doe", email: "johndoe@example.com", password: "password")
        let router = BaseAPIRouter<CreateUserRequest, Data>(hostname: URL(string: "https://example.com")!, path: "/users", authType: .none, method: .post, body: createUserRequest)

        let expectedURL = URL(string: "https://example.com/users")!
        let request = try router.asHTTPRequest()

        let url = try XCTUnwrap(request.url)
        
        XCTAssertEqual(url, expectedURL)
        XCTAssertEqual(request.method.rawValue, "POST")
        XCTAssertEqual(try router.encodedBody(), try JSONEncoder().encode(createUserRequest))
    }

    func testAsURLRequestWithPUTMethod() throws {
        struct UpdateUserRequest: Encodable {
            let id: Int
            let name: String
            let email: String
            let password: String
        }

        let updateUserRequest = UpdateUserRequest(id: 1, name: "John Doe", email: "johndoe@example.com", password: "password")
        let router = BaseAPIRouter<UpdateUserRequest, Data>(hostname: URL(string: "https://example.com")!, path: "/users/1", authType: .none, method: .put, body: updateUserRequest)

        let request = try router.asHTTPRequest()

        XCTAssertEqual(request.method.rawValue, "PUT")
        XCTAssertEqual(try router.encodedBody(), try JSONEncoder().encode(updateUserRequest))
    }

    func testDefaultRetryOptions() {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            hostname: URL(string: "https://example.com")!,
            path: "/test",
            authType: .none,
            body: EmptyCodable()
        )

        XCTAssertEqual(router.retryOptions, RetryOptions.default)
        XCTAssertTrue(router.retryOptions.contains(RetryOptions.retryOnTimeOut))
        XCTAssertTrue(router.retryOptions.contains(RetryOptions.retryOnInvalidResponseCode))
        XCTAssertTrue(router.retryOptions.contains(RetryOptions.retryOnInternalError))
    }
}

private func headersDictionary(from request: HTTPRequest) -> [String: String] {
    request.headerFields.reduce(into: [:]) { partialResult, field in
        partialResult[field.name.rawName] = field.value
    }
}
