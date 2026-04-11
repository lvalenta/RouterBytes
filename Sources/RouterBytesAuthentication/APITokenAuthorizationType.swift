//
//  APITokenAuthorizationType.swift
//  
//
//  Created by Lukáš Valenta on 03.06.2023.
//

import Foundation
import RouterBytes

@available(macOS 10.15.0, *)
public protocol APITokenAuthorizationType {
    func authorizedRequest(request: HTTPRequest, with provider: some APITokenProvider) async throws -> HTTPRequest
}

@available(macOS 10.15.0, *)
extension RouterBytes.AuthorizationType: APITokenAuthorizationType {
    public func authorizedRequest(request: HTTPRequest, with provider: some APITokenProvider) async throws -> HTTPRequest {
        switch self {
        case let .bearer(tokenType):
            let apiToken = try await provider.apiToken
            let token: String

            switch tokenType {
            case .accessToken:
                token = apiToken.accessToken.description
            case .refreshToken:
                if let apiToken = apiToken as? (any RefreshableAPITokenType) {
                    token = apiToken.refreshToken.description
                } else {
                    assertionFailure("APIToken is not refreshable") // TODO: Find out a typesafe way if possible
                    token = ""
                }
            }
            
            return request.withBearerToken(token)
        case .none:
            return request
        }
    }
}
