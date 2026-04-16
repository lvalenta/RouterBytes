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
    associatedtype APIToken: APITokenType
    func authorizedRequest(request: HTTPRequest, with apiToken: APIToken) async throws -> HTTPRequest
    func authorizedRequest(request: HTTPRequest, with provider: some APITokenProvider<APIToken>) async throws -> HTTPRequest
}
