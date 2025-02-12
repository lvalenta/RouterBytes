//
//  APIServiceDelegate.swift
//  
//
//  Created by Lukáš Valenta on 30.04.2023.
//

import Foundation

/// A protocol for handling events in an API service.
/// An object implementing this protocol can receive callbacks from an `APIService` instance when certain events occur during a network request.
///
/// Example usage:
/// ```
/// struct MyAPIServiceDelegate: APIServiceEventDelegate {
///     var logoutAction: (() async -> Void)?
///
///     func requestFired(request: URLRequest) {
///         log.info(request.cURL(pretty: true))
///     }
///
///     func responseReceived(from request: URLRequest, data: Data, response: URLResponse) {
///         log.debug("Request: \(request)\nResponse: \(data.asString(pretty: true) ?? "could not parse")")
///     }
///
///     func responseDecoded<T>(_ value: T) {
///         log.debug(value)
///     }
///
///     func requestFailedWithUnAuthorizedError(request: URLRequest) async {
///         log.error("Request failed with unAuthorizedError: \(request)")
///         await logoutAction?()
///     }
/// }
/// ```
public protocol APIServiceEventDelegate: Sendable {
    /// Notifies the delegate that a network request has been fired.
    ///
    /// - Parameter request: The URLRequest instance that was fired.
    func requestFired(request: URLRequest)

    /// Notifies the delegate that a network response has been received.
    ///
    /// - Parameters:
    ///   - data: The data returned in the response.
    ///   - response: The URLResponse object for the response.
    func responseReceived(from request: URLRequest, data: Data, response: URLResponse)

    /// Notifies the delegate that a response has been decoded.
    ///
    /// - Parameter value: The decoded value of type `T`.
    func responseDecoded<T: Sendable>(_ value: T)

    /// Notifies the delegate that a request failed with an unauthorized error.
    ///
    /// - Parameter router: The APIRouter instance that failed with an unauthorized error.
    func requestFailedWithUnAuthorizedError(router: some APIRouter) async
}

public extension APIServiceEventDelegate {
    /// Default implementation of `requestFired(request:)`.
    @inlinable
    func requestFired(request: URLRequest) { }

    /// Default implementation of `responseReceived(data:response:)`.
    @inlinable
    func responseReceived(from request: URLRequest, data: Data, response: URLResponse) { }

    /// Default implementation of `responseDecoded(_:)`.
    @inlinable
    func responseDecoded<T: Sendable>(_ value: T) { }

    /// Default implementation of `requestFailedWithUnAuthorizedError(router:)`.
    @inlinable
    func requestFailedWithUnAuthorizedError(router: some APIRouter) async { }
}
