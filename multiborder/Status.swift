//
//  Status.swift
//  multiborder
//
//  Created by Adam Pearce on 10/29/24.
//

import Foundation
import SwiftUI

public enum SavingStatus {
    case unsaved
    case saving
    case success
    case failed(SavingError)
    
    var isUnsaved: Bool {
        return switch self {
            case .unsaved: true
            default: false
        }
    }
    
    var isSaving: Bool {
        return switch self {
            case .saving: true
            default: false
        }
    }
    
    var isSuccess: Bool {
        return switch self {
            case .success: true
            default: false
        }
    }
    
    var isFailed: Bool {
        return switch self {
            case .failed: true
            default: false
        }
    }
}

public enum LoadingStatus {
    case unloaded
    case loading
    case finished(Image)
    case failed(Error)
    
    var isUnloaded: Bool {
        return switch self {
            case .unloaded: true
            default: false
        }
    }
    
    var isLoading: Bool {
        return switch self {
            case .loading: true
            default: false
        }
    }
    
    var isFinished: Bool {
        return switch self {
            case .finished: true
            default: false
        }
    }
    
    var isFailed: Bool {
        return switch self {
            case .failed: true
            default: false
        }
    }
}

public enum LoadingError: Error {
    case contentTypeNotSupported
}

public enum SavingError: Error {
    case general(String)
}
