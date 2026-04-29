//
//  APIService.swift
//  
//
//  Created by Lukáš Valenta on 30.04.2023.
//

import Foundation
import HTTPTypes

/**
 `APIRouterService` is a class responsible for making network requests and decoding responses. It uses an implementation of the `NetworkingServiceType` protocol to perform the network requests and an implementation of the `HTTPRequestProvider` protocol to create HTTP requests for the network requests.
 
 To use `APIRouterService`, subclass it and override its methods as needed. The most commonly used method is `getResponse`, which fetches data from the network. You pass an implementation of the `APIRouter` to `getResponse`, and it returns the decoded fetched data.
 
 `APIRouterService` supports retry functionality in the `getData` method. If the network request fails due to an invalid response code, an internal/server error, or a timeout error, it will retry the request once. This behavior helps improve the reliability of data retrieval.
 
 The class also provides an optional `APIServiceEventDelegate` that can be used to receive events from the `APIRouterService` object, such as progress updates and response decoding notifications. If the network request fails with an unauthorized error, it will attempt to fetch the data again using the `getSignedHTTPRequestOnUnAuthorizedError(from:)` method, and notify the event delegate if the second attempt also fails.
 
 The generic `AuthorizationType` represents the type of authorization used by the network requests. It is specified when creating an instance of `APIService`.
 
 By default, `APIRouterService` uses `URLSession.shared` as the networking service.
 
 - Example usage:
 ```
 let networkingService = YourNetworkingService()
 let apiService = APIRouterService<YourAuthorizationType>(networkingService: networkingService)
 
 let router = YourAPIRouter()
 do {
    let responseData: YourResponseDataType = try await apiService.getResponse(from: router)
    // Handle the decoded response data
 } catch {
    // Handle the error
 }
 ```
 */
@available(macOS 12.0, *)
open class APIRouterService<AuthorizationType, NetworkingService: NetworkingServiceType, HTTPRequestProvider>: APIService<NetworkingService>, APIRouterServiceType, @unchecked Sendable where HTTPRequestProvider: RouterBytes.HTTPRequestProvider<AuthorizationType> {
    
    public final let httpRequestProvider: HTTPRequestProvider
    
    /**
     Initializes an `APIService` object with specified networking service, HTTP request provider, and an optional event delegate.
     
     - Parameter networkingService: The networking service to use for network requests. Defaults to `URLSession.shared`.
     - Parameter httpRequestProvider: The HTTP request provider to create HTTP requests for the network requests.
     - Parameter eventDelegate: An optional event delegate to handle events related to the network requests. Defaults to `nil`.
     */
    @inlinable
    public init(networkingService: NetworkingService = URLSession.shared,
                httpRequestProvider: HTTPRequestProvider,
                eventDelegate: APIServiceEventDelegate? = nil) {
        self.httpRequestProvider = httpRequestProvider
        super.init(
            networkingService: networkingService,
            eventDelegate: eventDelegate
        )
    }

    /**
     Fetches and decodes data from the network using a given `HTTPRequest`.
     
     This method fetches the data from the network using the given `HTTPRequest`. It also decodes the data using the given `JSONDecoder` and reports the progress of the request to the `eventDelegate` if it is set.
     
     - Parameters:
     - request: The `HTTPRequest` to use for fetching the data.
     - decoder: The `JSONDecoder` to use for decoding the data.
     - Returns: A decoded response object of type `T`.
     - Throws: An error if the network request or decoding fails.
     */
    @inlinable
    final public func getResponse<RouterType: APIRouter>(from router: RouterType) async throws -> RouterType.Response where RouterType.AuthorizationType == AuthorizationType, RouterType.Response: Decodable, RouterType.HeaderResponse == Void {
        let data = try await getData(for: router).0
        return try getDecoded(from: data, decode: router.decode)
    }

    /**
     Fetches and decodes data from the network using a given `HTTPRequest`.
     
     This method fetches the data from the network using the given `HTTPRequest`. It also decodes the data using the given `JSONDecoder` and reports the progress of the request to the `eventDelegate` if it is set.
     
     - Parameters:
     - request: The `HTTPRequest` to use for fetching the data.
     - decoder: The `JSONDecoder` to use for decoding the data.
     - Returns: A touple containing decoded response object of decoded APIRouter's Response and APIRouter's HeaderResponse.
     - Throws: An error if the network request or decoding fails.
     */
    @inlinable
    final public func getResponse<RouterType: APIRouter>(from router: RouterType) async throws -> (RouterType.Response, RouterType.HeaderResponse) where RouterType.AuthorizationType == AuthorizationType, RouterType.Response: Decodable, RouterType.HeaderResponse: Decodable {
        let (data, response) = try await getData(for: router)

        return (try getDecoded(from: data, decode: router.decode), try getDecodedHeaderResponse(from: response, decode: router.decode))
    }
    
    /**
     Fetches data from the network using a given `APIRouter`.
     
     This method fetches the data from the network using the given `APIRouter` and reports the progress of the request to the `eventDelegate` if it is set.
     
     - Parameter router: The `APIRouter` object representing the network request.
     - Throws: An error if the network request fails.
     - Note: `RouterType.AuthorizationType` must match the `AuthorizationType` of the `APIService` instance.
     */
    @inlinable
    final public func getResponse<RouterType: APIRouter>(from router: RouterType) async throws -> Void where RouterType.AuthorizationType == AuthorizationType, RouterType.Response == Void, RouterType.HeaderResponse == Void {
        try await getData(for: router)
    }

    /**
     Fetches data from the network using a given `APIRouter`.
     
     This method fetches the data from the network using the given `APIRouter` and reports the progress of the request to the `eventDelegate` if it is set.
     
     - Parameter router: The `APIRouter` object representing the network request.
     - Returns: Decoded APIRouter's HeaderResponse.
     - Throws: An error if the network request fails.
     - Note: `RouterType.AuthorizationType` must match the `AuthorizationType` of the `APIService` instance.
     */
    @inlinable
    final public func getResponse<RouterType: APIRouter>(from router: RouterType) async throws -> RouterType.HeaderResponse where RouterType.AuthorizationType == AuthorizationType, RouterType.Response == Void, RouterType.HeaderResponse: Decodable {
        let (_, response) = try await getData(for: router)
        return try getDecodedHeaderResponse(from: response, decode: router.decode)
    }

    /**
     Fetches data from the network for the specified `APIRouter`.
     
     This method fetches the data from the network using the `HTTPRequest` created by the `getSignedHTTPRequest(from:)` method of the given `APIRouter`. The method also supports retry functionality, improving the reliability of data retrieval by retrying the request once if it fails due to an invalid response code, an internal/server error, or a timeout error. If the request fails with an unauthorized error, it will attempt to fetch the data again using the `getSignedHTTPRequestOnUnAuthorizedError(from:)` method, and notify the event delegate if the second attempt also fails.
     
     - Parameter router: The `APIRouter` object representing the network request.
     - Returns: The data fetched from the network.
     - Throws: An error if the network request fails.
     - Note: `RouterType.AuthorizationType` must match the `AuthorizationType` of the `APIService` instance.
     */
    @discardableResult
    @inlinable
    open func getData<RouterType: APIRouter>(for router: RouterType) async throws -> (Data, HTTPResponse) where RouterType.AuthorizationType == AuthorizationType {
        let body = try router.encodedBody()

        do {
            return try await getDataFromNetwork(for: try await getHTTPRequest(from: router), body: body)
        } catch let error as ResponseValidationError where error.status.kind == .serverError && router.retryOptions.contains(.retryOnInternalError) {
            return try await getDataFromNetwork(for: try await getHTTPRequest(from: router), body: body)
        } catch let error as ResponseValidationError where (error.status.kind == .informational || error.status.kind == .invalid) && router.retryOptions.contains(.retryOnInvalidResponseCode) {
            return try await getDataFromNetwork(for: try await getHTTPRequest(from: router), body: body)
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut && router.retryOptions.contains(.retryOnTimeOut) {
            return try await getDataFromNetwork(for: try await getHTTPRequest(from: router), body: body)
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            throw CancellationError()
        } catch let error as NSError where error.code == -1009 {
            throw URLError(.notConnectedToInternet)
        } catch let error as ResponseValidationError where error.status == .unauthorized {
            do {
                let request = try await getHTTPRequestOnUnAuthorizedError(from: router)
                return try await getDataFromNetwork(for: request, body: body)
            } catch let error as FailedWithUnAuthorizedError {
                await eventDelegate?.requestFailedWithUnAuthorizedError(router: router, error: error)
                throw error
            }
        } catch let error as FailedWithUnAuthorizedError {
            await eventDelegate?.requestFailedWithUnAuthorizedError(router: router, error: error.reason)
            throw error
       }
    }
    
    /**
     Returns an HTTP request created by a given `APIRouter`.
     
     This method creates a `HTTPRequest` using the `getHTTPRequest(from:)` method of the `HTTPRequestProvider`.
     
     - Parameter router: The `APIRouter` object representing the network request.
     - Returns: A `HTTPRequest` object.
     - Throws: An error if the `HTTPRequest` could not be created from the `APIRouter`.
     - Note: `RouterType.AuthorizationType` must match the `AuthorizationType` of the `APIService` instance.
     */
    @inlinable
    final public func getHTTPRequest<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType {
        try await httpRequestProvider.getHTTPRequest(from: router)
    }
    
    /**
     Returns an HTTP request created by a given `APIRouter` when an unauthorized error occurs.
     
     This method creates a `HTTPRequest` using the `getHTTPRequestOnUnAuthorizedError(from:)` method of the `HTTPRequestProvider`.
     
     - Parameter router: The `APIRouter` object representing the network request.
     - Returns: A `HTTPRequest` object.
     - Throws: An error if the `HTTPRequest` could not be created from the `APIRouter`.
     - Note: `RouterType.AuthorizationType` must match the `AuthorizationType` of the `APIService` instance.
     */
    @inlinable
    final public func getHTTPRequestOnUnAuthorizedError<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType {
        try await httpRequestProvider.getHTTPRequestOnUnAuthorizedError(from: router)
    }
}

public protocol APIServiceType: Sendable {
    /**
     Decodes the data using the specified `JSONDecoder`.
     
     This method decodes the given data using the specified `JSONDecoder`. It also reports the progress of the decoding to the `eventDelegate` if it is set.
     
     - Parameters:
     - data: The data to be decoded.
     - decoder: The `JSONDecoder` to use for decoding the data.
     - Returns: A decoded object of the specified type.
     - Throws: An error if the decoding fails.
     */
    func getDecoded<T: Decodable>(from data: Data, decode: (T.Type, Data) throws -> T) throws -> T

    func getDecodedHeaderResponse<T: Decodable & Sendable>(from response: HTTPResponse, decode: (T.Type, Data) throws -> T) throws -> T

    /**
     Fetches data from the network using a given `HTTPRequest`.
     
     This method fetches the data from the network using the given `HTTPRequest`. It also reports the progress of the request to the `eventDelegate` if it is set.
     
     - Parameter request: The `HTTPRequest` to use for fetching the data.
     - Returns: The data and response fetched from the network.
     - Throws: An error if the network request fails.
     */
    func getDataFromNetwork(for request: HTTPRequest, body: Data?) async throws -> (Data, HTTPResponse)
}

extension APIServiceType {
    @_disfavoredOverload
    public func getDataFromNetwork(for request: HTTPRequest, body: Data?) async throws -> (Data) {
        try await getDataFromNetwork(for: request, body: body).0
    }
}

@available(macOS 12.0, *)
public protocol APIRouterServiceType<AuthorizationType>: RouterBytes.APIServiceType {
    associatedtype AuthorizationType

    func getResponse<RouterType: APIRouter>(from router: RouterType) async throws -> (RouterType.Response, RouterType.HeaderResponse) where RouterType.AuthorizationType == AuthorizationType, RouterType.Response: Decodable, RouterType.HeaderResponse: Decodable

    func getResponse<RouterType: APIRouter>(from router: RouterType) async throws -> RouterType.Response where RouterType.AuthorizationType == AuthorizationType, RouterType.Response: Decodable, RouterType.HeaderResponse == Void

    func getResponse<RouterType: APIRouter>(from router: RouterType) async throws where RouterType.AuthorizationType == AuthorizationType, RouterType.Response == Void, RouterType.HeaderResponse == Void

    func getResponse<RouterType: APIRouter>(from router: RouterType) async throws -> RouterType.HeaderResponse where RouterType.AuthorizationType == AuthorizationType, RouterType.Response == Void, RouterType.HeaderResponse: Decodable

    func getData<RouterType: APIRouter>(for router: RouterType) async throws -> (Data, HTTPResponse) where RouterType.AuthorizationType == AuthorizationType

    func getHTTPRequest<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType

    func getHTTPRequestOnUnAuthorizedError<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType
}

@available(macOS 12.0, *)
open class APIService<NetworkingService: NetworkingServiceType>: @unchecked Sendable, APIServiceType {
    /// The networking service used to perform network requests.
    public final let networkingService: NetworkingService

    /// An optional delegate that can be used to receive events from the `APIService` object.
    public let eventDelegate: APIServiceEventDelegate?

    @inlinable
    public init(networkingService: NetworkingService = URLSession.shared,
                eventDelegate: APIServiceEventDelegate? = nil) {
        self.networkingService = networkingService
        self.eventDelegate = eventDelegate
    }

    final public func getDecoded<T: Decodable & Sendable>(from data: Data, decode: (T.Type, Data) throws -> T) throws -> T {
        let decoded: T = try decode(T.self, data)
        
        eventDelegate?.responseDecoded(decoded)
        
        return decoded
    }

    final public func getDataFromNetwork(for request: HTTPRequest, body: Data?) async throws -> (Data, HTTPResponse) {
        eventDelegate?.requestFired(request: request, body: body)
        
        let (data, response) = try await networkingService.data(for: request, body: body)
        eventDelegate?.responseReceived(from: request, body: body, data: data, response: response)

        try checkResponse(from: data, with: response)
        
        return (data, response)
    }

    @inlinable
    final public func getDecodedHeaderResponse<T: Decodable & Sendable>(from response: HTTPResponse, decode: (T.Type, Data) throws -> T) throws -> T {
        let headers: [String: String] = response.headerFields.reduce(into: [:]) { partialResult, field in
            partialResult[field.name.rawName] = field.value
        }
        let serialization = try JSONSerialization.data(withJSONObject: headers, options: [])

        return try getDecoded(from: serialization, decode: decode)
    }

    /**
     Checks the HTTP response for errors, throwing a `ResponseValidationError` if the response is invalid.
     
     - Parameter data: The data returned from the request.
     - Parameter response: The HTTP response received from the server.
     
     - Throws: A `ResponseValidationError` if the response is invalid.
     */
    @inlinable
    open func checkResponse(from data: Data, with response: HTTPResponse) throws {
        if let error = ResponseValidationError(response: response) {
            throw error
        }
    }
}
