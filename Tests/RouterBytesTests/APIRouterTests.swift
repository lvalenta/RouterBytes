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
        
        let headers: [String: String] = [:]
        
        let expectedURL = URL(string: "https://example.com/test")!
        
        XCTAssertEqual(router.headers, headers)
        XCTAssertEqual(try router.asURL(), expectedURL)
        let urlRequest = try router.asURLRequest()
        XCTAssertEqual(urlRequest.url, expectedURL)
        XCTAssertEqual(urlRequest.httpMethod, HTTPMethod.get.rawValue)
        XCTAssertEqual(urlRequest.httpBody, try JSONEncoder().encode(.empty))
        XCTAssertEqual(urlRequest.allHTTPHeaderFields, ["Content-Type": "application/json"])
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
        
        let urlRequest = try router.asURLRequest()
        
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.allHTTPHeaderFields, ["Content-Type": "application/json"])
        
        let url = try XCTUnwrap(urlRequest.url)
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/api/test"))
        XCTAssertTrue(url.absoluteString.contains("?param1=value1&param2=value2") || url.absoluteString.contains("?param2=value2&param1=value1"))

        XCTAssertEqual(urlRequest.httpBody, "\"Test Body\"".data(using: .utf8))
    }
    
    func testAsURLWithAdditionalHeadersAndQueryItems() throws {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaders: ["header1":"value1", "header2":"value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaders: ["header3": "header3"],
            queryItems: ["page": "1", "perPage": "20"],
            body: EmptyCodable()
        )

        let url = try router.asURL()
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/users"))
        XCTAssertTrue(url.absoluteString.contains("?page=1&perPage=20") || url.absoluteString.contains("?perPage=20&page=1"))
    }

    func testAsURLRequstWithAdditionalHeadersAndQueryItems() throws {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaders: ["header1":"value1", "header2":"value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaders: ["header3": "value3"],
            queryItems: ["page": "1", "perPage": "20"],
            body: EmptyCodable()
        )

        let urlRequest = try router.asURLRequest()

        let url = try XCTUnwrap(urlRequest.url)
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/users"))
        XCTAssertTrue(url.absoluteString.contains("?page=1&perPage=20") || url.absoluteString.contains("?perPage=20&page=1"))
        XCTAssertEqual(urlRequest.allHTTPHeaderFields, ["Content-Type": "application/json", "header1":"value1", "header2":"value2", "header3": "value3"])
        XCTAssertEqual(urlRequest.httpBody, try JSONEncoder().encode(EmptyCodable()))
    }

    func testAsURLRequstWithOverridingDefaultHeaderWithAdditionalHeaders() throws {
        let router = BaseAPIRouter<EmptyCodable, Data>(
            defaultHeaders: ["Content-Type": "test", "header1":"value1", "header2":"value2"],
            hostname: URL(string: "https://example.com")!,
            path: "/users",
            authType: .none,
            additionalHeaders: ["header1": "value3"],
            queryItems: ["page": "1", "perPage": "20"],
            body: EmptyCodable()
        )

        let urlRequest = try router.asURLRequest()

        let url = try XCTUnwrap(urlRequest.url)
        
        XCTAssertTrue(url.absoluteString.contains("https://example.com/users"))
        XCTAssertTrue(url.absoluteString.contains("?page=1&perPage=20") || url.absoluteString.contains("?perPage=20&page=1"))
        XCTAssertEqual(urlRequest.allHTTPHeaderFields, ["Content-Type": "test", "header1":"value3", "header2":"value2"])
        XCTAssertEqual(urlRequest.httpBody, try JSONEncoder().encode(.empty))
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
        let urlRequest = try router.asURLRequest()

        let url = try XCTUnwrap(urlRequest.url)
        
        XCTAssertEqual(url, expectedURL)
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.httpBody, try JSONEncoder().encode(createUserRequest))
    }

    func testAsURLRequestWithPUTMethodAndCachePolicy() throws {
        struct UpdateUserRequest: Encodable {
            let id: Int
            let name: String
            let email: String
            let password: String
        }

        let updateUserRequest = UpdateUserRequest(id: 1, name: "John Doe", email: "johndoe@example.com", password: "password")
        let router = BaseAPIRouter<UpdateUserRequest, Data>(hostname: URL(string: "https://example.com")!, path: "/users/1", authType: .none, method: .put, body: updateUserRequest, cachePolicy: .useProtocolCachePolicy)

        let urlRequest = try router.asURLRequest()

        XCTAssertEqual(urlRequest.httpMethod, "PUT")
        XCTAssertEqual(urlRequest.httpBody, try JSONEncoder().encode(updateUserRequest))
        XCTAssertEqual(urlRequest.cachePolicy, .useProtocolCachePolicy)
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
    }
}
