//
//  MockAPIService.swift
//
//
//  Created by Lukáš Valenta on 12.02.2024.
//

import Foundation
import RouterBytes
import HTTPTypes

public final class MockAPIService: RouterBytes.APIRouterServiceType, @unchecked Sendable {
    public typealias AuthorizationType = RouterBytes.BearerAuthorizationType
    
    private var responsesOnRouter: [ObjectIdentifier: (any APIRouter) async throws -> (Any)] = [:]
    private var httpRequestsOnUnAuthorizedRouter: [ObjectIdentifier: (any APIRouter) async throws -> HTTPRequest] = [:]
    private var httpRequestProviders: [ObjectIdentifier: (Any) async throws -> HTTPRequest] = [:]
    private var decodedProviders: [ObjectIdentifier: (Any) async throws -> Any] = [:]
    private var dataFromNetworkProviders: [RequestBodyKey: (HTTPRequest, Data?) async throws -> (Data, HTTPResponse)] = [:]
    private var dataProviders: [ObjectIdentifier: (Any) async throws -> (Data, HTTPResponse)] = [:]

    private struct RequestBodyKey: Hashable {
        let request: HTTPRequest
        let body: Data?
    }

    public init() { }

    public func registerHTTPRequestResponseOnUnAuthorizedRouter<Router: RouterBytes.APIRouter>(router: Router, response: @escaping (Router) -> HTTPRequest) {
        httpRequestsOnUnAuthorizedRouter[ObjectIdentifier(Router.self)] = { router in
            response(router as! Router)
        }
    }

    public func registerDataProvider<Router: RouterBytes.APIRouter>(
        for routerType: Router.Type,
        dataProvider: @escaping (Router) throws -> (Data, HTTPResponse)
    ) {
        dataProviders[ObjectIdentifier(routerType)] = { router in
            guard let router = router as? Router else {
                fatalError("HTTP request provider not registered")
            }
            return try dataProvider(router)
        }
    }
    
    public func registerHTTPRequestProvider<Router: RouterBytes.APIRouter>(
        for routerType: Router.Type,
        httpRequestProvider: @escaping (Router) throws -> HTTPRequest
    ) {
        httpRequestProviders[ObjectIdentifier(routerType)] = { router in
            guard let router = router as? Router else {
                fatalError("HTTP request provider not registered")
            }
            return try httpRequestProvider(router)
        }
    }
    
    public func registerDecodedProvider<Router: RouterBytes.APIRouter, DecodedType>(
        for routerType: Router.Type,
        decodedProvider: @escaping (Router) throws -> DecodedType
    ) {
        decodedProviders[ObjectIdentifier(routerType)] = { router in
            guard let router = router as? Router else {
                fatalError("HTTP request provider not registered")
            }
            return try decodedProvider(router)
        }
    }
    
    public func registerDataFromNetworkProvider(
        for request: HTTPRequest,
        body: Data? = nil,
        dataProvider: @escaping (HTTPRequest, Data?) throws -> (Data, HTTPResponse)
    ) {
        dataFromNetworkProviders[RequestBodyKey(request: request, body: body)] = dataProvider
    }


    private func getResponseOnRouter<APIRouter: RouterBytes.APIRouter>(router: APIRouter) async throws -> APIRouter.Response {
        guard let response = responsesOnRouter[ObjectIdentifier(APIRouter.self)] else {
            fatalError("Response not registered")
        }

        return try await response(router) as! APIRouter.Response
    }
    
    public func getResponse<RouterType>(from router: RouterType) async throws -> RouterType.Response where RouterType : RouterBytes.APIRouter, AuthorizationType == RouterType.AuthorizationType, RouterType.Response : Decodable, RouterType.HeaderResponse == Void {
        try await getResponseOnRouter(router: router.self)
    }

    public func getResponse<RouterType>(from router: RouterType) async throws -> (RouterType.Response, RouterType.HeaderResponse) where RouterType : RouterBytes.APIRouter, AuthorizationType == RouterType.AuthorizationType, RouterType.Response : Decodable, RouterType.HeaderResponse: Decodable {
        fatalError("Needs to be implemented") // TODO:
    }
    
    public func getResponse<RouterType>(from router: RouterType) async throws where RouterType : RouterBytes.APIRouter, AuthorizationType == RouterType.AuthorizationType, RouterType.Response == Void, RouterType.HeaderResponse == Void {
        try await getResponseOnRouter(router: router)
    }

    public func getResponse<RouterType>(from router: RouterType) async throws -> RouterType.HeaderResponse where RouterType : RouterBytes.APIRouter, AuthorizationType == RouterType.AuthorizationType, RouterType.Response == Void, RouterType.HeaderResponse: Decodable {
        fatalError("Needs to be implemented") // TODO:
    }
    
    public func getHTTPRequest<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : RouterBytes.APIRouter, AuthorizationType == RouterType.AuthorizationType {
        guard let httpRequestProvider = httpRequestProviders[ObjectIdentifier(RouterType.self)] else {
            fatalError("DataProvider not registered")
        }
        return try await httpRequestProvider(router)
    }
    
    public func getHTTPRequestOnUnAuthorizedError<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : RouterBytes.APIRouter, AuthorizationType == RouterType.AuthorizationType {
        guard let response = httpRequestsOnUnAuthorizedRouter[ObjectIdentifier(RouterType.self)] else {
            fatalError("Response not registered")
        }

        return try await response(router)
    }
    
    public func getData<RouterType>(for router: RouterType) async throws -> (Data, HTTPResponse) where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        guard let dataProvider = dataProviders[ObjectIdentifier(RouterType.self)] else {
            fatalError("DataFromNetwork provider not registered")
        }

        return try await dataProvider(router)
    }
    
    public func getDataFromNetwork(for request: HTTPRequest, body: Data?) async throws -> (Data, HTTPResponse) {
        let key = RequestBodyKey(request: request, body: body)

        guard let dataFromNetworkProvider = dataFromNetworkProviders[key] else {
            fatalError("DataFromNetwork provider not registered")
        }
        return try await dataFromNetworkProvider(request, body)
    }

    public func getDecoded<T>(from data: Data, decode: (T.Type, Data) throws -> T) throws -> T where T : Decodable {
        try decode(T.self, data)
    }

    public func getDecodedHeaderResponse<T>(from response: HTTPResponse, decode: (T.Type, Data) throws -> T) throws -> T where T: Decodable, T: Sendable {
        let headers: [String: String] = response.headerFields.reduce(into: [:]) { partialResult, field in
            partialResult[field.name.rawName] = field.value
        }
        let serialization = try JSONSerialization.data(withJSONObject: headers, options: [])
        return try getDecoded(from: serialization, decode: decode)
    }
}
