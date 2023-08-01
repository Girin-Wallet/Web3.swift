//
//  Web3HttpProvider.swift
//  Web3
//
//  Created by Koray Koska on 17.02.18.
//

import Foundation
import Dispatch

public struct Web3HttpProvider: Web3Provider {

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let queue: DispatchQueue

    let session: URLSession

    static let headers = [
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]

    public let rpcURL: String

    public init(rpcURL: String, session: URLSession = URLSession(configuration: .default)) {
        self.rpcURL = rpcURL
        self.session = session
        // Concurrent queue for faster concurrent requests
        self.queue = DispatchQueue(label: "Web3HttpProvider", attributes: .concurrent)
    }

    public func send<Params, Result>(request: RPCRequest<Params>, response: @escaping Web3ResponseCompletion<Result>) {
        queue.async {
            guard let body = try? self.encoder.encode(request) else {
                let err = Web3Response<Result>(status: .requestFailed)
                response(err)
                return
            }

            guard let url = URL(string: self.rpcURL) else {
                let err = Web3Response<Result>(status: .requestFailed)
                response(err)
                return
            }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody = body
            for (k, v) in type(of: self).headers {
                req.addValue(v, forHTTPHeaderField: k)
            }

            let task = self.session.dataTask(with: req) { data, urlResponse, error in
                guard let urlResponse = urlResponse as? HTTPURLResponse, let data = data, error == nil else {
                    let err = Web3Response<Result>(status: .serverError)
                    response(err)
                    return
                }

                let status = urlResponse.statusCode
                guard status >= 200 && status < 300 else {
                    // This is a non typical rpc error response and should be considered a server error.
                    let err = Web3Response<Result>(status: .serverError)
                    response(err)
                    return
                }

                guard let rpcResponse = try? self.decoder.decode(RPCResponse<Result>.self, from: data) else {
                    // We don't have the response we expected...
                    let err = Web3Response<Result>(status: .serverError)
                    response(err)
                    return
                }

                // We got the Result object
                let res = Web3Response(status: .ok, rpcResponse: rpcResponse)
                response(res)
            }
            task.resume()
        }
    }
}
