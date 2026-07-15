//
//  DownloadTests.swift
//
//
//  Created by Lukáš Valenta on 15.07.2026.
//

import XCTest
import RouterBytes

@available(iOS 15.0, *)
final class DownloadTests: XCTestCase {
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
        mockHTTPRequestProvider = nil
        super.tearDown()
    }

    func testDownloadReturnsFileURLAndAppliesAuth() async throws {
        let router = Self.mockRouter()
        let expectedRequest = try router.asHTTPRequest()
        let downloadedURL = Self.temporaryFileURL()
        let receivedResponse = HTTPResponse(status: 200)

        networkingService.onDownloadCall = { request, _ in
            XCTAssertEqual(request, expectedRequest)
            return (downloadedURL, receivedResponse)
        }

        let fileURL: URL = try await apiService.getDownloadResponse(from: router)

        XCTAssertEqual(fileURL, downloadedURL)
        XCTAssertEqual(delegate.firedRequest, expectedRequest)
        XCTAssertEqual(delegate.firedRequestFromDownloadResponseReceived, expectedRequest)
        XCTAssertEqual(delegate.downloadFileURL, downloadedURL)
        XCTAssertEqual(delegate.downloadReceivedResponse, receivedResponse)
        XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestCalled)
        XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)
    }

    func testDownloadReturnsFileURLAndDecodedHeaderResponse() async throws {
        let router: BaseDownloadRouter<EmptyCodable, [String: String]> = BaseDownloadRouter(
            hostname: URL(string: "https://cleevio.com")!,
            path: "/file",
            authType: .none
        )
        let downloadedURL = Self.temporaryFileURL()
        let traceId = HTTPField.Name("X-Trace-Id")!
        let receivedResponse = HTTPResponse(status: 200, headerFields: [traceId: "trace-id-123"])

        networkingService.onDownloadCall = { _, _ in
            (downloadedURL, receivedResponse)
        }

        let (fileURL, headers): (URL, [String: String]) = try await apiService.getDownloadResponse(from: router)

        XCTAssertEqual(fileURL, downloadedURL)
        XCTAssertEqual(headers["X-Trace-Id"], "trace-id-123")
    }

    func testDownloadValidatesStatusOnlyWithEmptyData() async throws {
        let router = Self.mockRouter()
        let receivedResponse = HTTPResponse(status: 404)

        networkingService.onDownloadCall = { _, _ in
            (Self.temporaryFileURL(), receivedResponse)
        }

        do {
            _ = try await apiService.getDownloadResponse(from: router) as URL
            XCTFail("Expected ResponseValidationError")
        } catch let error as ResponseValidationError {
            XCTAssertEqual(error.status, .notFound)
            XCTAssertEqual(error.data, Data())
            XCTAssertFalse(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)
        } catch {
            XCTFail("Expected ResponseValidationError, got \(error)")
        }
    }

    func testDownloadRetriesOnUnauthorizedError() async throws {
        let router = Self.mockRouter()
        let expectedRequest = try router.asHTTPRequest()
        let downloadedURL = Self.temporaryFileURL()
        let successResponse = HTTPResponse(status: 200)

        let firstRequest = XCTestExpectation(description: "First request should fire")
        let secondRequest = XCTestExpectation(description: "Second request should fire")

        networkingService.onDownloadCall = { request, _ in
            XCTAssertEqual(request, expectedRequest)
            firstRequest.fulfill()

            self.networkingService.onDownloadCall = { request, _ in
                XCTAssertEqual(request, expectedRequest)
                secondRequest.fulfill()
                return (downloadedURL, successResponse)
            }

            return (Self.temporaryFileURL(), HTTPResponse(status: 401))
        }

        let fileURL: URL = try await apiService.getDownloadResponse(from: router)

        XCTAssertEqual(fileURL, downloadedURL)
        XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestCalled)
        XCTAssertTrue(mockHTTPRequestProvider.getHTTPRequestOnUnAuthorizedErrorCalled)

        await fulfillment(of: [firstRequest, secondRequest])
    }

    func testDownloadRetriesOnInternalError() async throws {
        let router = Self.mockRouter()
        let downloadedURL = Self.temporaryFileURL()
        var requestCount = 0

        networkingService.onDownloadCall = { _, _ in
            requestCount += 1
            if requestCount == 1 {
                return (Self.temporaryFileURL(), HTTPResponse(status: 500))
            }
            return (downloadedURL, HTTPResponse(status: 200))
        }

        let fileURL: URL = try await apiService.getDownloadResponse(from: router)

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(fileURL, downloadedURL)
    }

    static private func mockRouter() -> BaseDownloadRouter<EmptyCodable, Void> {
        BaseDownloadRouter(hostname: URL(string: "https://cleevio.com")!, path: "/file", authType: .none)
    }

    static private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
    }
}
