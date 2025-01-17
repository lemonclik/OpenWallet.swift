//
//  ExtensionViewControllerURLChannel.swift
//  OpenWallet
//
//  Created by Yehor Popovych on 5/21/19.
//  Copyright © 2019 Tesseract Systems, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
#if !COCOAPODS
    @_exported import OpenWalletCore
#endif

public protocol ExtensionViewControllerURLChannelDelegate: class {
    
    func urlChannelGotResponse(channel: ExtensionViewControllerURLChannel, response: Data)
}

public class ExtensionViewControllerURLChannel: ExtensionViewControllerDataChannel {
    
    public let uti: String
    public let messageBase64: String
    public let callback: URL
    
    public weak var delegate: ExtensionViewControllerURLChannelDelegate?
    
    public init(request: URL) throws {
        guard let components = URLComponents(url: request, resolvingAgainstBaseURL: true) else {
            throw OpenWalletError.wrongParameters("can't parse URL options")
        }
        
        let cbUrl = components.queryItems?
            .first{ $0.name == "callback" }?.value
            .flatMap{URL(string: $0)}
        
        guard let callback = cbUrl else {
            throw OpenWalletError.wrongParameters("callback")
        }
        
        let msgOpt = components.queryItems?
            .first{ $0.name == "message" }?.value
        
        guard let message = msgOpt else {
            throw OpenWalletError.emptyRequest
        }
        
        guard let scheme = components.scheme else {
            throw OpenWalletError.wrongParameters("scheme")
        }
        
        let api = scheme
            .replacingOccurrences(of: "\(OPENWALLET_URL_API_PREFIX)-", with: "")
            .replacingOccurrences(of: "-", with: ".")
        
        // base64url encoding with sttripped padding https://tools.ietf.org/html/rfc4648#page-7
        var messageBase64 = message
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        if message.count % 4 > 0 {
            messageBase64 = messageBase64
                .appending(String(repeating: "=", count: (4 - message.count % 4)))
        }
        
        self.messageBase64 = messageBase64
        self.callback = callback
        self.uti = "\(OPENWALLET_API_PREFIX).\(api)"
    }
    
    public func sendResponse(provider: OpenURLProviderProtocol, data: Data) -> Bool {
        // base64url encoding with sttripped padding https://tools.ietf.org/html/rfc4648#page-7
        let base64 = data
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        
        let cb = self.callback.absoluteString + "#\(OPENWALLET_URL_API_PREFIX)-\(base64)"
        // Can be force unwrapped. callback is url, and we are adding proper anchor (urlencoded base64 is valid anchor symbols)
        return provider.open(url: URL(string: cb)!)
    }
    
    private func handleResponse(vc: ExtensionViewController, data: Data) {
        if let delegate = delegate {
            delegate.urlChannelGotResponse(channel: self, response: data)
        } else {
            let _ = sendResponse(provider: vc, data: data)
        }
    }
    
    public func response(viewController: ExtensionViewController, response: ResponseProtocol) {
        do {
            let string = try response.serialize()
            guard let data = string.data(using: .utf8) else {
                throw OpenWalletError.wrongParameters("can't encode utf8")
            }
            handleResponse(vc: viewController, data: data)
        } catch let err {
            let errorResponse: Response<Empty>
            switch err {
            case let error as OpenWalletError:
                errorResponse = Response(uti: response.uti, error: error)
            default:
                errorResponse = Response(uti: response.uti, error: .unknownError(err))
            }
            
            // Error response always can be converted to data
            handleResponse(
                vc: viewController,
                data: try! errorResponse.serialize().data(using: .utf8)!
            )
        }
    }
    
    public func rawRequest(for viewController: ExtensionViewController, response: @escaping (Result<(json: String, uti: String), OpenWalletError>) -> Void) {
        DispatchQueue.global().async {
            guard let data = Data(base64Encoded: self.messageBase64) else {
                response(.failure(.wrongParameters("can't decode base64")))
                return
            }
            guard let json = String(data: data, encoding: .utf8) else {
                response(.failure(.wrongParameters("can't read message utf8")))
                return
            }
            response(.success((json: json, uti: self.uti)))
        }
    }
}
