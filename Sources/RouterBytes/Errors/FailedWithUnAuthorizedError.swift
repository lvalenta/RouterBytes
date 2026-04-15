//
//  FailedWithUnAuthorizedError.swift
//  
//
//  Created by Lukáš Valenta on 27.06.2023.
//

import Foundation

public struct FailedWithUnAuthorizedError: Error {
    @usableFromInline let reason: Error

    public init(reason: Error) {
        self.reason = reason
    }
}
