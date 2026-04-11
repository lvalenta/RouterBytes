//
//  RefreshTokenAPIRouter.swift
//  
//
//  Created by Lukáš Valenta on 02.05.2023.
//

import Foundation
import RouterBytes

/**
A protocol for API routers that handle refreshing authentication tokens.

The `RefreshTokenAPIRouter` protocol extends the `APIRouter` protocol and requires the router to have a `Response` type that conforms to the `CodableAPITokentype` protocol. Additionally, it requires the router to have an initializer with no arguments.
*/
@available(macOS 10.15, *)
public protocol RefreshTokenAPIRouter: APIRouter {
    associatedtype APIToken: RefreshableAPITokenType = BaseAPIToken

    init(previousToken: APIToken)

    func getToken(data: Data, response: HTTPResponse, apiService: some APIServiceType) throws -> APIToken
}

@available(macOS 10.15, *)
public extension RefreshTokenAPIRouter where Response: TokenAPIRouterResponse, Response.APIToken == APIToken, HeaderResponse == Void {
    func getToken(data: Data, response: HTTPResponse, apiService: some APIServiceType) throws -> APIToken {
        let decoded: Response = try apiService.getDecoded(from: data, decode: decode)
        return decoded.asAPIToken()
    }
}

@available(macOS 10.15, *)
public extension RefreshTokenAPIRouter where HeaderResponse: TokenAPIRouterResponse, HeaderResponse.APIToken == APIToken, Response == Void {
    func getToken(data: Data, response: HTTPResponse, apiService: some APIServiceType) throws -> APIToken {
        let decoded: HeaderResponse = try apiService.getDecodedHeaderResponse(from: response, decode: decode)
        return decoded.asAPIToken()
    }
}

@available(macOS 10.15, *)
public protocol TokenAPIRouterResponse: Codable {
    associatedtype APIToken: RefreshableAPITokenType = BaseAPIToken

    func asAPIToken() -> APIToken
}

@available(macOS 10.15, *)
extension TokenAPIRouterResponse where Self == APIToken {
    func asAPIToken() -> APIToken { self }
}
