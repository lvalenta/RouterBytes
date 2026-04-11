//
//  BaseAPIRouter.swift
//  
//
//  Created by Lukáš Valenta on 28.04.2023.
//

import Foundation
import OrderedCollections
import HTTPTypes

public struct BaseAPIRouter<RequestBody: Sendable & Encodable, Response: Decodable & Sendable>: APIRouter, HasHostname {    
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
                requestType: RequestBody.Type = RequestBody.self) {
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

public extension BaseAPIRouter where RequestBody == EmptyCodable {
    init(defaultHeaderFields: HTTPFields = [:],
                hostname: URL,
                jsonDecoder: JSONDecoder = JSONDecoder(),
                jsonEncoder: JSONEncoder = JSONEncoder(),
                path: Path,
                authType: AuthorizationType,
                additionalHeaderFields: HTTPFields = [:],
                queryItems: QueryItems = [:],
                method: HTTPMethod = .get,
                body: RequestBody,
                retryOptions: RetryOptions = .default) {
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

}
