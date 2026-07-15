//
//  DownloadRouter.swift
//
//
//  Created by Lukáš Valenta on 15.07.2026.
//

import Foundation
import OrderedCollections
import HTTPTypes

/**
 A router describing a request whose response should be streamed straight to a
 file on disk rather than loaded into memory as `Data`.

 A `DownloadRouter` is fetched through `APIRouterService.getResponse(from:)` /
 `getFile(for:)`, which use `URLSession.download(for:)` under the hood and return
 the `URL` of the downloaded (temporary) file. Everything else — authorization,
 retry behavior, and token refresh — works exactly like a regular `APIRouter`.

 `Response` is fixed to `Never`: `Never` is `Sendable` but is neither `Decodable`
 nor `Void`, which lets the download `getResponse` overloads coexist with the
 decoding overloads without ambiguity. `HeaderResponse` is left free, so a
 download can still decode a header response just like the data path.

 Downloads are `GET`-style: `URLSession.download(for:)` does not send a request
 body, so `RequestBody` should be `Void` — any body is ignored.

 - Note: The returned file URL points at a temporary location that is **not**
   removed automatically. The caller is responsible for moving it somewhere
   persistent.
 */
public protocol DownloadRouter: APIRouter where Response == Never {}

/**
 A concrete `DownloadRouter` mirroring `BaseAPIRouter`, so a download can be
 described without hand-rolling a protocol conformance.

 `Response` is fixed to `Never`; `HeaderResponse` is parameterized (defaults to
 `Void`) and decoded from the response headers when requested.
 */
public struct BaseDownloadRouter<RequestBody: Sendable & Encodable, HeaderResponse: Sendable>: DownloadRouter, HasHostname {
    public typealias Response = Never

    public let defaultHeaderFields: HTTPFields
    public let hostname: URL
    public let jsonDecoder: JSONDecoder
    public let jsonEncoder: JSONEncoder
    public let path: Path
    public let authType: AuthorizationType
    public let additionalHeaderFields: HTTPFields
    public let queryItems: QueryItems
    public let method: HTTPMethod
    public let body: RequestBody
    public let retryOptions: RetryOptions

    public init(defaultHeaderFields: HTTPFields = [:],
                hostname: URL,
                jsonDecoder: JSONDecoder = JSONDecoder(),
                jsonEncoder: JSONEncoder = JSONEncoder(),
                path: Path,
                authType: AuthorizationType,
                additionalHeaderFields: HTTPFields = [:],
                queryItems: QueryItems = [:],
                method: HTTPMethod = .get,
                body: RequestBody,
                retryOptions: RetryOptions = .default,
                requestType: RequestBody.Type = RequestBody.self,
                headerResponseType: HeaderResponse.Type = HeaderResponse.self) {
        self.defaultHeaderFields = defaultHeaderFields
        self.hostname = hostname
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.path = path
        self.authType = authType
        self.additionalHeaderFields = additionalHeaderFields
        self.queryItems = queryItems
        self.method = method
        self.body = body
        self.retryOptions = retryOptions
    }

    public func encode(_ value: RequestBody) throws -> Data? {
        try jsonEncoder.encode(value)
    }

    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        try jsonDecoder.decode(type, from: data)
    }
}

public extension BaseDownloadRouter where RequestBody == EmptyCodable {
    /// Convenience initializer for a body-less download (the common `GET` case).
    init(defaultHeaderFields: HTTPFields = [:],
         hostname: URL,
         jsonDecoder: JSONDecoder = JSONDecoder(),
         jsonEncoder: JSONEncoder = JSONEncoder(),
         path: Path,
         authType: AuthorizationType,
         additionalHeaderFields: HTTPFields = [:],
         queryItems: QueryItems = [:],
         method: HTTPMethod = .get,
         retryOptions: RetryOptions = .default,
         headerResponseType: HeaderResponse.Type = HeaderResponse.self) {
        self.init(defaultHeaderFields: defaultHeaderFields,
                  hostname: hostname,
                  jsonDecoder: jsonDecoder,
                  jsonEncoder: jsonEncoder,
                  path: path,
                  authType: authType,
                  additionalHeaderFields: additionalHeaderFields,
                  queryItems: queryItems,
                  method: method,
                  body: EmptyCodable(),
                  retryOptions: retryOptions)
    }
}
