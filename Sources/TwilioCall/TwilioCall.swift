import Foundation
import Combine
import UIKit

public class TwilioCall: NSObject {
    
    private let callManager = CallManager.default
    
    private(set) var application: UIApplication!
    
    // shared instance
    public static let shared = TwilioCall()
    private override init() {}
    
    
    public func configure(for application: UIApplication, tokenEndPoint: String) {
        self.application = application
        callManager.configure(endpoint: tokenEndPoint)
    }
}
