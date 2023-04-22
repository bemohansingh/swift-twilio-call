//
//  TokenGenerator.swift
//  TwilioVoiceCallApp
//
//  Created by bemohansingh on 06/05/2021.
//

import Foundation
import Combine

enum TokenError: LocalizedError {
    case error(Error)
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .error(let error):
            return error.localizedDescription
        case .custom(let msg):
            return msg
        }
    }
}

struct TokenResult {
    var error: TokenError?
    var success: Bool
    var token: VoiceToken
}

final class TokenGenerator {
    
    // shared instance
    static let `default` = TokenGenerator()
    private init() { }
    
    // the endpoint for the token
    private var generatorEndpoint = ""
    
    // setter for the endpoint
    func setEndpoint(endpoint: String) {
        generatorEndpoint = endpoint
    }
    
    func generateAccessToken(info: TwilioInfoIdentifiable, completion: @escaping (TokenResult) -> Void) {
        guard let request = buildRequest(info: info) else {
            completion(TokenResult(error: TokenError.custom("The request for the given url string cannot be constructed"), success: false, token: VoiceToken()))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(TokenResult(error: TokenError.error(error), success: false, token: VoiceToken()))
            } else if let data = data {
                do {
                    let object = try JSONDecoder().decode(VoiceToken.self, from: data)
                    log(object)
                    completion(TokenResult(error: nil, success: true, token: object))
                } catch {
                    completion(TokenResult(error: TokenError.custom(error.localizedDescription), success: false, token: VoiceToken()))
                }
            } else {
                completion(TokenResult(error: TokenError.custom("Something went wrong"), success: false, token: VoiceToken()))
            }
        }
        task.resume()
    }
    
    private func buildRequest(info: TwilioInfoIdentifiable) -> URLRequest? {
        let urlWithParameters = getURLWithParams(params: info.parameters)
        guard let url = URL(string: urlWithParameters) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }
    
    private func getURLWithParams(params: [String: String]) -> String {
        guard let url = URL(string: generatorEndpoint) else {
            return generatorEndpoint
        }
        
        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var queryItems = urlComponents.queryItems ?? [URLQueryItem]()
            params.forEach { param in
                queryItems.append(URLQueryItem(name: param.key, value: "\(param.value)"))
            }
            urlComponents.queryItems = queryItems
            return urlComponents.url?.absoluteString ?? generatorEndpoint
        }
        return generatorEndpoint
    }
}
