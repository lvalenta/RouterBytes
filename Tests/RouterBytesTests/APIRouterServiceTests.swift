//
//  APIRouterServiceTests.swift
//  
//
//  Created by Lukáš Valenta on 30.04.2023.
//

import XCTest
import RouterBytes

@available(iOS 15.0, *)
final class APIRouterServiceTests: XCTestCase {
    var networkingService: NetworkingServiceMock!
    var apiService: APIRouterService<BearerAuthorizationType, NetworkingServiceMock, MockHTTPRequestProvider<BearerAuthorizationType>>!
    var delegate: MockAPIServiceEventDelegate!
    var mockHTTPRequestProvider: MockHTTPRequestProvider<BearerAuthorizationType>!

    override func setUp() {
        super.setUp()
        
        networkingService = NetworkingServiceMock()
        delegate = MockAPIServiceEventDelegate()
        mockHTTPRequestProvider = MockHTTPRequestProvider(hostname: URL(string: "https://cleevio.com")!)
        apiService = APIRouterService(networkingService: networkingService, httpRequestProvider: mockHTTPRequestProvider, eventDelegate: delegate)
    }
    
    override func tearDown() {
        networkingService = nil
        apiService = nil
        delegate = nil
        super.tearDown()
    }
    
    func testGetData() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let request = try router.asHTTPRequest()
        let expectedResponse = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedResponse)
        let receivedResponse = HTTPResponse(status: 200)
        networkingService.onDataCall = { request, _, _ in
            (responseData, receivedResponse)
        }
        
        let response = try await apiService.getResponse(from: router)
        
        XCTAssertEqual(response, expectedResponse)
        XCTAssertEqual(delegate.receivedData, responseData)
        XCTAssertEqual(delegate.receivedResponse, receivedResponse)
        XCTAssertEqual(delegate.firedRequest, request)
        XCTAssertEqual(delegate.firedRequestFromResponseReceived, request)
        XCTAssertNotNil(delegate.decodedValue as? String)
    }

    func testRetryOnInternalErrorFailure() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asHTTPRequest()
        let receivedResponse = HTTPResponse(status: 500)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")
        
        networkingService.onDataCall = { request, _, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _, _ in
                XCTAssertEqual(expectedRequest, request)
                secondRequest.fulfill()
                return (Data(), receivedResponse)
            }
            
            return (Data(), receivedResponse)
        }
    
        do {
            // Perform the data request, which should trigger token refreshing and retry the request
            _ = try await apiService.getResponse(from: router)
            XCTFail()
        } catch {
            // Ensure that the request was retried and succeeded
            XCTAssertEqual(delegate.receivedResponse, receivedResponse)
            XCTAssertEqual(delegate.firedRequest, expectedRequest)
            XCTAssertEqual(delegate.firedRequestFromResponseReceived, expectedRequest)
            XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestCalled)
            XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)

            // Wait for expectations to be fulfilled
            await fulfillment(of:[firstRequest, secondRequest])
        }
    }

    func testRetryOnInternalErrorSuccess() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asHTTPRequest()
        let receivedResponse = HTTPResponse(status: 500)
        let receivedSuccessResponse = HTTPResponse(status: 200)
        
        let expectedData = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedData)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")

        
        networkingService.onDataCall = { request, _, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _, _ in
                XCTAssertEqual(expectedRequest, request)
                secondRequest.fulfill()
                return (responseData, receivedSuccessResponse)
            }
            
            return (Data(), receivedResponse)
        }
    
        // Perform the data request, which should trigger token refreshing and retry the request
        let response = try await apiService.getResponse(from: router)

        // Ensure that the request was retried and succeeded
        XCTAssertEqual(delegate.receivedResponse, receivedSuccessResponse)
        XCTAssertEqual(response, expectedData)
        XCTAssertEqual(delegate.decodedValue as? String, expectedData)
        XCTAssertEqual(delegate.firedRequest, expectedRequest)
        XCTAssertEqual(delegate.firedRequestFromResponseReceived, expectedRequest)
        XCTAssertNotNil(delegate.decodedValue as? String)
        XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestCalled)
        XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)

        // Wait for expectations to be fulfilled
        await fulfillment(of: [firstRequest, secondRequest])
    }

    func testRetryOnTimeout() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asHTTPRequest()
        let receivedSuccessResponse = HTTPResponse(status: 200)
        
        let expectedData = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedData)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")

        
        networkingService.onDataCall = { request, _, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _, _ in
                XCTAssertEqual(expectedRequest, request)
                secondRequest.fulfill()
                return (responseData, receivedSuccessResponse)
            }
            
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        }
    
        // Perform the data request, which should trigger token refreshing and retry the request
        let response = try await apiService.getResponse(from: router)

        // Ensure that the request was retried and succeeded
        XCTAssertEqual(delegate.receivedResponse, receivedSuccessResponse)
        XCTAssertEqual(response, expectedData)
        XCTAssertEqual(delegate.decodedValue as? String, expectedData)
        XCTAssertEqual(delegate.firedRequest, expectedRequest)
        XCTAssertEqual(delegate.firedRequestFromResponseReceived, expectedRequest)
        XCTAssertNotNil(delegate.decodedValue as? String)
        XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestCalled)
        XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)

        // Wait for expectations to be fulfilled
        await fulfillment(of: [firstRequest, secondRequest])
    }

    func testNoRetryOnInvalidResponseCodeWhenDisabled() async throws {
        let router = BaseAPIRouter<String, String>(
            hostname: URL(string: "https://cleevio.com")!,
            path: "/blog",
            authType: .none,
            body: "",
            retryOptions: [.retryOnTimeOut]
        )
        let expectedRequest = try router.asHTTPRequest()
        let invalidResponse = HTTPResponse(status: 100)
        var requestCount = 0

        networkingService.onDataCall = { request, _, _ in
            requestCount += 1
            XCTAssertEqual(request, expectedRequest)
            return (Data(), invalidResponse)
        }

        do {
            _ = try await apiService.getResponse(from: router)
            XCTFail("Expected invalidResponseCode")
        } catch let error as ResponseValidationError where error.status.kind == .informational || error.status.kind == .invalid {
            XCTAssertEqual(requestCount, 1)
            XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)
        } catch {
            XCTFail("Expected invalidResponseCode, got \(error)")
        }
    }

    func testRetryOnInvalidResponseCodeWhenEnabled() async throws {
        let router = BaseAPIRouter<String, String>(
            hostname: URL(string: "https://cleevio.com")!,
            path: "/blog",
            authType: .none,
            body: "",
            retryOptions: [.retryOnInvalidResponseCode]
        )
        let expectedRequest = try router.asHTTPRequest()
        let receivedSuccessResponse = HTTPResponse(status: 200)
        let expectedData = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedData)

        var requestCount = 0
        networkingService.onDataCall = { request, _, _ in
            requestCount += 1
            XCTAssertEqual(request, expectedRequest)

            if requestCount == 1 {
                return (Data(), HTTPResponse(status: 100))
            }

            return (responseData, receivedSuccessResponse)
        }

        let response = try await apiService.getResponse(from: router)

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(response, expectedData)
        XCTAssertEqual(delegate.receivedResponse, receivedSuccessResponse)
        XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)
    }

    func testNoRetryOnInternalErrorWhenRetryOnInternalErrorDisabled() async throws {
        let router = BaseAPIRouter<String, String>(
            hostname: URL(string: "https://cleevio.com")!,
            path: "/blog",
            authType: .none,
            body: "",
            retryOptions: [.retryOnInvalidResponseCode]
        )
        let expectedRequest = try router.asHTTPRequest()
        var requestCount = 0

        networkingService.onDataCall = { request, _, _ in
            requestCount += 1
            XCTAssertEqual(request, expectedRequest)
            return (Data(), HTTPResponse(status: 500))
        }

        do {
            _ = try await apiService.getResponse(from: router)
            XCTFail("Expected internal error")
        } catch let error as ResponseValidationError where error.status.kind == .serverError {
            XCTAssertEqual(requestCount, 1)
            XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)
        } catch {
            XCTFail("Expected internal error, got \(error)")
        }
    }

    func testNoRetryOnTimeoutWhenDisabled() async throws {
        let router = BaseAPIRouter<String, String>(
            hostname: URL(string: "https://cleevio.com")!,
            path: "/blog",
            authType: .none,
            body: "",
            retryOptions: [.retryOnInvalidResponseCode]
        )
        let expectedRequest = try router.asHTTPRequest()
        var requestCount = 0

        networkingService.onDataCall = { request, _, _ in
            requestCount += 1
            XCTAssertEqual(request, expectedRequest)
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        }

        do {
            _ = try await apiService.getResponse(from: router)
            XCTFail("Expected timeout error")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, NSURLErrorDomain)
            XCTAssertEqual(error.code, NSURLErrorTimedOut)
            XCTAssertEqual(requestCount, 1)
            XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)
        } catch {
            XCTFail("Expected NSError timeout, got \(error)")
        }
    }

    func testRetryOnAuthorizedError() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asHTTPRequest()
        let receivedSuccessResponse = HTTPResponse(status: 200)
        
        let expectedData = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedData)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")
        
        networkingService.onDataCall = { request, _, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _, _ in
                XCTAssertEqual(expectedRequest, request)
                secondRequest.fulfill()
                return (responseData, receivedSuccessResponse)
            }
            
            return (Data(), HTTPResponse(status: 401))
        }
    
        // Perform the data request, which should trigger token refreshing and retry the request
        let response = try await apiService.getResponse(from: router)

        // Ensure that the request was retried and succeeded
        XCTAssertEqual(delegate.receivedResponse, receivedSuccessResponse)
        XCTAssertEqual(response, expectedData)
        XCTAssertEqual(delegate.decodedValue as? String, expectedData)
        XCTAssertEqual(delegate.firedRequest, expectedRequest)
        XCTAssertEqual(delegate.firedRequestFromResponseReceived, expectedRequest)
        XCTAssertNotNil(delegate.decodedValue as? String)
        XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestCalled)
        XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)

        // Wait for expectations to be fulfilled
        await fulfillment(of: [firstRequest, secondRequest])
    }

    func testRetryAndFailureOnAuthorizedError() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asHTTPRequest()
        let receivedResponse = HTTPResponse(status: 401)
        
        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")

        networkingService.onDataCall = { request, _, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _, _ in
                XCTAssertEqual(expectedRequest, request)
                secondRequest.fulfill()
                return (Data(), receivedResponse)
            }
            
            return (Data(), receivedResponse)
        }
    
        do {
            _ = try await apiService.getResponse(from: router)
            XCTFail("Expected failure")
        } catch let error as ResponseValidationError where error.status == .unauthorized {
            // Ensure that the request was retried and succeeded
            XCTAssertEqual(delegate.receivedResponse, receivedResponse)
            XCTAssertEqual(delegate.firedRequest, expectedRequest)
            XCTAssertEqual(delegate.firedRequestFromResponseReceived, expectedRequest)
            XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestCalled)
            XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)
        } catch {
            XCTFail("Received different error than expected: \(error)")
        }
        // Perform the data request, which should trigger token refreshing and retry the request
        // Wait for expectations to be fulfilled
        await fulfillment(of: [firstRequest, secondRequest])
    }

    func testCancellationErrorMapping() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        _ = try router.asHTTPRequest()

        networkingService.onDataCall = { _, _, _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
        }

        do {
            _ = try await apiService.getResponse(from: router)
            XCTFail("Expected CancellationError, but no error was thrown.")
        } catch is CancellationError {
            XCTAssertTrue(true, "CancellationError was correctly thrown.")
        } catch {
            XCTFail("Expected CancellationError, but received \(error).")
        }
    }

    func testURLErrorNotConnectedToInternet() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        _ = try router.asHTTPRequest()

        networkingService.onDataCall = { _, _, _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        }

        do {
            _ = try await apiService.getResponse(from: router)
            XCTFail("Expected URLError(.notConnectedToInternet) to be thrown")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet, "URLError(.notConnectedToInternet) was correctly thrown")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    static private func mockRouter<Response: Decodable>() -> BaseAPIRouter<String, Response> {
        BaseAPIRouter(hostname: URL(string: "https://cleevio.com")!, path: "/blog", authType: .none, body: "")
    }
}


final class MockAPIServiceEventDelegate: @unchecked Sendable, APIServiceEventDelegate {
    var firedRequest: HTTPRequest?
    var receivedData: Data?
    var receivedResponse: HTTPResponse?
    var firedRequestFromResponseReceived: HTTPRequest?
    var decodedValue: Any?
    
    func requestFired(request: HTTPRequest, body: Data?) {
        firedRequest = request
    }
    
    func responseReceived(from request: HTTPRequest, body: Data?, data: Data, response: HTTPResponse) {
        firedRequestFromResponseReceived = request
        receivedData = data
        receivedResponse = response
    }
    
    func responseDecoded<T>(_ value: T) {
        decodedValue = value
    }
}
