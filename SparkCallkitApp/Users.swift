
import Foundation

enum User {
    case wilma, xavier
    
    func displayName() -> String {
        switch self {
        case .wilma:
            return "Wilma"
        case .xavier:
            return "Xavier"
        }
    }
    
    func jwt() -> String {
        switch self {
        case .wilma:
            return "TODO PUT A JWT TOKEN HERE"
        case .xavier:
            return "TODO PUT A JWT TOKEN HERE"
        }
    }
    
    func userToCall() -> User {
        switch self {
        case .wilma:
            return .xavier
        case .xavier:
            return .wilma
        }
    }

    func sparkId() -> String {
        let realm = "TODO PUT REALM FOR JWT USERS HERE"
        
        switch self {
        case .wilma:
            return "wilma@\(realm)"
        case .xavier:
            return "xavier@\(realm)"
        }
    }
}
