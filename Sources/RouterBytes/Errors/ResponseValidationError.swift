//
//  ResponseValidationError.swift
//  
//
//  Created by Lukáš Valenta on 30.04.2023.
//

import Foundation
import HTTPTypes

/// An error that occurs when a response is not valid.
public struct ResponseValidationError: Error, Equatable, Sendable {
    /// HTTP status that caused validation to fail.
    public let status: HTTPResponse.Status

    /// Creates a validation error with explicit status.
    public init(status: HTTPResponse.Status) {
        self.status = status
    }

    /// Initializes a `ResponseValidationError` instance from the provided `HTTPResponse`.
    ///
    /// `2xx` and `3xx` responses are considered valid and return `nil`.
    /// Any other response maps to a validation error containing the response status.
    ///
    /// - Parameter response: The `HTTPResponse` to validate.
    public init?(response: HTTPResponse) {
        let status = response.status

        switch status.kind {
        case .successful, .redirection:
            return nil
        case .clientError, .serverError, .informational, .invalid:
            self = .init(status: status)
        }
    }
}

extension ResponseValidationError: LocalizedError {
    /// A localized description of the error.
    public var errorDescription: String? {
        switch status {
        case .badRequest:
            return NSLocalizedString("Bad request", comment: "")
        case .unauthorized:
            return NSLocalizedString("Unauthorized", comment: "")
        case .forbidden:
            return NSLocalizedString("Access denied", comment: "")
        case .notFound:
            return NSLocalizedString("Not found", comment: "")
        default:
            switch status.kind {
            case .informational, .invalid:
                return NSLocalizedString("Invalid response code", comment: "")
            case .clientError:
                return "Client Error \(status.code)"
            case .serverError:
                return NSLocalizedString("Internal error", comment: "")
            case .successful, .redirection:
                return nil
            }
        }
    }
}
