//
//  APIServiceTests.swift
//  RouterBytes
//
//  Created by Lukáš Valenta on 11.04.2026.
//


import Foundation
import RouterBytes
import Testing

@Suite
struct APIServiceTests {
    @Test("APIService.getDecoded decodes response data and notifies delegate")
    func getDecodedDecodesResponseData() throws {
        let delegate = APIServiceEventDelegateSpy()
        let apiService = APIService<UnusedNetworkingService>(
            networkingService: UnusedNetworkingService(),
            eventDelegate: delegate
        )

        let expectedResponse = DecodedResponse(message: "Hello, World!")
        let payload = try JSONEncoder().encode(expectedResponse)
        let decoder = JSONDecoder()

        let decoded: DecodedResponse = try apiService.getDecoded(from: payload) { type, data in
            try decoder.decode(type, from: data)
        }

        #expect(decoded == expectedResponse)
        #expect(delegate.decodedResponse as? DecodedResponse == expectedResponse)
    }

    @Test("APIService.getDecoded forwards decode errors")
    func getDecodedForwardsDecodeErrors() {
        let apiService = APIService<UnusedNetworkingService>(networkingService: UnusedNetworkingService())

        do {
            let _: DecodedResponse = try apiService.getDecoded(from: Data("{}".utf8)) { _, _ in
                throw DecodeFailure.failed
            }
            Issue.record("Expected DecodeFailure.failed to be thrown.")
        } catch let error as DecodeFailure {
            #expect(error == .failed)
        } catch {
            Issue.record("Expected DecodeFailure.failed, got \(error).")
        }
    }

    @Test("APIService.getDecodedHeaderResponse decodes header values and notifies delegate")
    func getDecodedHeaderResponseDecodesHeaders() {
        let delegate = APIServiceEventDelegateSpy()
        let apiService = APIService<UnusedNetworkingService>(
            networkingService: UnusedNetworkingService(),
            eventDelegate: delegate
        )
        let traceId = HTTPField.Name("X-Trace-Id")!
        let totalCount = HTTPField.Name("X-Total-Count")!
        let httpResponse = HTTPResponse(
            status: 200,
            headerFields: [
                traceId: "trace-id-123",
                totalCount: "7"
            ]
        )
        let decoder = JSONDecoder()

        do {
            let decoded: [String: String] = try apiService.getDecodedHeaderResponse(from: httpResponse) { type, data in
                try decoder.decode(type, from: data)
            }

            #expect(decoded["X-Trace-Id"] == "trace-id-123")
            #expect(decoded["X-Total-Count"] == "7")
            #expect((delegate.decodedResponse as? [String: String])?["X-Trace-Id"] == "trace-id-123")
        } catch {
            Issue.record("Expected decoded headers, got \(error).")
        }
    }

    @Test("APIService.getDecodedHeaderResponse forwards decode errors")
    func getDecodedHeaderResponseForwardsDecodeErrors() {
        let apiService = APIService<UnusedNetworkingService>(networkingService: UnusedNetworkingService())
        let response = HTTPResponse(status: 200)

        do {
            let _: [String: String] = try apiService.getDecodedHeaderResponse(from: response) { _, _ in
                throw DecodeFailure.failed
            }
            Issue.record("Expected DecodeFailure.failed to be thrown.")
        } catch let error as DecodeFailure {
            #expect(error == .failed)
        } catch {
            Issue.record("Expected DecodeFailure.failed, got \(error).")
        }
    }
}

@available(macOS 12.0, *)
private final class UnusedNetworkingService: NetworkingServiceType {
    func finishTasksAndInvalidate() { }

    func invalidateAndCancel() { }

    func reset() async { }

    func data(for request: HTTPRequest, body: Data?) async throws -> (Data, HTTPResponse) {
        fatalError("This test double is intentionally unused for network calls")
    }

    @available(iOS 15.0, *)
    func data(for request: HTTPRequest, body: Data?, delegate: URLSessionTaskDelegate?) async throws -> (Data, HTTPResponse) {
        fatalError("This test double is intentionally unused for network calls")
    }

    @available(iOS 15.0, *)
    func bytes(for request: HTTPRequest, delegate: URLSessionTaskDelegate?) async throws -> (URLSession.AsyncBytes, HTTPResponse) {
        fatalError("This test double is intentionally unused for network calls")
    }
}

private struct DecodedResponse: Codable, Equatable, Sendable {
    let message: String
}

private enum DecodeFailure: Error, Equatable {
    case failed
}

private final class APIServiceEventDelegateSpy: @unchecked Sendable, APIServiceEventDelegate {
    var decodedResponse: Any?

    func responseDecoded<T: Sendable>(_ value: T) {
        decodedResponse = value
    }
}
