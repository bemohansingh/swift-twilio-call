//
//  CallError.swift
//  
//
//  Created by bemohansingh on 10/05/2021.
//

import Foundation

public enum CallError: LocalizedError {
    case micPermissionDenied
    case error(Error)
    
    public var errorDescription: String? {
        switch self {
        case .micPermissionDenied:
            return "The permission to microphone is denied"
        case .error(let error):
            return error.localizedDescription
        }
    }
}
