//
//  HTTPRequest+cURL.swift
//  
//
//  Created by Lukáš Valenta on 30.04.2023.
//

import Foundation
import HTTPTypes

public extension HTTPRequest {
    /// Returns a string representation of the HTTPRequest in cURL format.
    ///
    /// - Parameter pretty: A flag that indicates whether to include newlines in the output.
    ///                     When `true`, the output is formatted with newlines for improved readability.
    ///                     The default value is `false`.
    ///
    /// - Returns: A string representation of the HTTPRequest in cURL format.
    ///
    /// - Note: This function generates a cURL command that mimics the original HTTPRequest, including headers and
    ///         the request method. The generated cURL command can be copied and executed in a shell environment,
    ///         allowing you to reproduce the original request.
    ///
    ///         If the request has a non-empty HTTP body and the content type is application/json, the function
    ///         generates a `--data` option with a JSON-encoded string representation of the body.
    ///
    /// - Warning: This function may expose sensitive data, such as authentication tokens, in the generated cURL output.
    ///
    func cURL(body: Data? = nil, pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : " "
        lazy var newLineCount = newLine.count
        let methodOption = (pretty ? "--request " : "-X ") + self.method.rawValue
        let urlOption: String = (pretty ? "--url " : "") + "\'\(self.url?.absoluteString ?? "")\'"
        
        var cURL = "curl "
        var header = ""
        var data: String = ""
        
        for field in headerFields {
            header += (pretty ? "--header " : " -H ") + "\'\(field.name.rawName): \(field.value)\'\(newLine)"
        }

        if !header.isEmpty {
            header.removeLast(newLineCount)
        }
        

        if let body = body?.asJSONString(pretty: pretty), !body.isEmpty {
            data = "--data '\(body)'"
        }
        
        cURL += "\(methodOption)\(methodOption.isEmpty ? "" : newLine)\(urlOption)\(pretty ? "\\\n" : "")\(header)\(header.isEmpty ?  "" : newLine)\(data)"
        
        let endsWithNewLine = cURL.suffix(newLineCount) == newLine
        
        guard !endsWithNewLine else {
            return String(cURL.dropLast(newLineCount))
        }
    
        return cURL
    }
}
