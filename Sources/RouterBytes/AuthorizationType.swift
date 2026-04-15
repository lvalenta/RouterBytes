//
//  AuthorizationType.swift
//  
//
//  Created by Lukáš Valenta on 28.04.2023.
//

import Foundation

/// The type of authorization used for a network request.
public enum BearerAuthorizationType: Sendable {

    /// No authorization used for the request.
    case none
    
    /// Bearer authorization used for the request.
    case bearer(TokenAuthorizationType)
}

public enum TokenAuthorizationType: Sendable {
    /// Access token used for bearer authorization.
    case accessToken

    /// Refresh token used for bearer authorization.
    case refreshToken
}
