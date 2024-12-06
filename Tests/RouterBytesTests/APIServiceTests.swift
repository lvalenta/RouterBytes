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
    var apiService: APIRouterService<AuthorizationType, NetworkingServiceMock, MockURLRequestProvider<AuthorizationType>>!
    var delegate: MockAPIServiceEventDelegate!
    var mockURLRequestProvider: MockURLRequestProvider<AuthorizationType>!
    
    override func setUp() {
        super.setUp()
        
        networkingService = NetworkingServiceMock()
        delegate = MockAPIServiceEventDelegate()
        mockURLRequestProvider = MockURLRequestProvider(hostname: URL(string: "https://cleevio.com")!)
        apiService = APIRouterService(networkingService: networkingService, urlRequestProvider: mockURLRequestProvider, eventDelegate: delegate)
    }
    
    override func tearDown() {
        networkingService = nil
        apiService = nil
        delegate = nil
        super.tearDown()
    }
    
    func testGetData() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let request = try router.asURLRequest()
        let expectedResponse = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedResponse)
        let receivedResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        networkingService.onDataCall = { request, _ in
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
        let expectedRequest = try router.asURLRequest()
        let receivedResponse = HTTPURLResponse(url: expectedRequest.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")
        
        networkingService.onDataCall = { request, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _ in
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
            XCTAssertTrue(mockURLRequestProvider.getURLRequestCalled)
            XCTAssertFalse(mockURLRequestProvider.getURLRequestOnUnAuthorizedErrorCalled)

            // Wait for expectations to be fulfilled
            wait(for: [firstRequest, secondRequest], timeout: 1)
        }
    }

    func testRetryOnInternalErrorSuccess() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asURLRequest()
        let receivedResponse = HTTPURLResponse(url: expectedRequest.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        let receivedSuccessResponse = HTTPURLResponse(url: expectedRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        let expectedData = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedData)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")

        
        networkingService.onDataCall = { request, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _ in
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
        XCTAssertTrue(mockURLRequestProvider.getURLRequestCalled)
        XCTAssertFalse(mockURLRequestProvider.getURLRequestOnUnAuthorizedErrorCalled)

        // Wait for expectations to be fulfilled
        wait(for: [firstRequest, secondRequest], timeout: 1)
    }

    func testRetryOnTimeout() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asURLRequest()
        let receivedSuccessResponse = HTTPURLResponse(url: expectedRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        let expectedData = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedData)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")

        
        networkingService.onDataCall = { request, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _ in
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
        XCTAssertTrue(mockURLRequestProvider.getURLRequestCalled)
        XCTAssertFalse(mockURLRequestProvider.getURLRequestOnUnAuthorizedErrorCalled)

        // Wait for expectations to be fulfilled
        wait(for: [firstRequest, secondRequest], timeout: 1)
    }

    func testRetryOnAuthorizedError() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asURLRequest()
        let receivedSuccessResponse = HTTPURLResponse(url: expectedRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        let expectedData = "Hello, World!"
        let responseData = try JSONEncoder().encode(expectedData)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")
        
        networkingService.onDataCall = { request, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _ in
                XCTAssertEqual(expectedRequest, request)
                secondRequest.fulfill()
                return (responseData, receivedSuccessResponse)
            }
            
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: "", headerFields: [:])! as URLResponse)
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
        XCTAssertTrue(mockURLRequestProvider.getURLRequestCalled)
        XCTAssertTrue(mockURLRequestProvider.getURLRequestOnUnAuthorizedErrorCalled)

        // Wait for expectations to be fulfilled
        wait(for: [firstRequest, secondRequest], timeout: 1)
    }

    func testRetryAndFailureOnAuthorizedError() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        let expectedRequest = try router.asURLRequest()
        let receivedResponse = HTTPURLResponse(url: expectedRequest.url!, statusCode: 401, httpVersion: "", headerFields: [:])! as URLResponse
        
        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")

        networkingService.onDataCall = { request, _ in
            XCTAssertEqual(expectedRequest, request)
            firstRequest.fulfill()

            self.networkingService.onDataCall = { request, _ in
                XCTAssertEqual(expectedRequest, request)
                secondRequest.fulfill()
                return (Data(), receivedResponse)
            }
            
            return (Data(), receivedResponse)
        }
    
        do {
            _ = try await apiService.getResponse(from: router)
            XCTFail("Expected failure")
        } catch ResponseValidationError.unauthorized {
            // Ensure that the request was retried and succeeded
            XCTAssertEqual(delegate.receivedResponse, receivedResponse)
            XCTAssertEqual(delegate.firedRequest, expectedRequest)
            XCTAssertEqual(delegate.firedRequestFromResponseReceived, expectedRequest)
            XCTAssertTrue(mockURLRequestProvider.getURLRequestCalled)
            XCTAssertTrue(mockURLRequestProvider.getURLRequestOnUnAuthorizedErrorCalled)
        } catch {
            XCTFail("Received different error than expected: \(error)")
        }
        // Perform the data request, which should trigger token refreshing and retry the request
        // Wait for expectations to be fulfilled
        wait(for: [firstRequest, secondRequest], timeout: 1)
    }

    func testCancellationErrorMapping() async throws {
        let router: BaseAPIRouter<String, String> = Self.mockRouter()
        _ = try router.asURLRequest()

        networkingService.onDataCall = { _, _ in
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
        _ = try router.asURLRequest()

        networkingService.onDataCall = { _, _ in
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
    var firedRequest: URLRequest?
    var receivedData: Data?
    var receivedResponse: URLResponse?
    var firedRequestFromResponseReceived: URLRequest?
    var decodedValue: Any?
    
    func requestFired(request: URLRequest) {
        firedRequest = request
    }
    
    func responseReceived(from request: URLRequest, data: Data, response: URLResponse) {
        firedRequestFromResponseReceived = request
        receivedData = data
        receivedResponse = response
    }
    
    func responseDecoded<T>(_ value: T) {
        decodedValue = value
    }
}
