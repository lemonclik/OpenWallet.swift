//
//  KeychainAPI.swift
//  OpenWallet
//
//  Created by Yehor Popovych on 3/7/19.
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

public protocol KeychainRequestMessageProtocol: RequestMessageProtocol {
    static var method: String { get }
    var method: String { get }
}

public class KeychainRequest<Message: KeychainRequestMessageProtocol>: Request<Message> {
    public init(network: Network, id: UInt32, request: Message) {
        super.init(id: id, request: request, uti: "one.openwallet.keychain.\(network.uti)")
    }
    
    required public init(json: String, uti: String) throws {
        try super.init(json: json, uti: uti)
    }
}


extension OpenWallet {
    public func keychain<R: KeychainRequestMessageProtocol>(
        net: Network, request: R,
        response: @escaping (Result<R.Response, OpenWalletError>) -> Void
    ) {
        let req = KeychainRequest(network: net, id: requestId, request: request)
        self.request(req, response: response)
    }
}