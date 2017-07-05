import UIKit
import SparkSDK

class CallController: UIViewController {
    private let spark: Spark
    private let jwtAuthentication = JWTAuthenticator()

    init(jwtToken: String) {
        spark = Spark(authenticator: jwtAuthentication)
        
        super.init(nibName: nil, bundle: nil)
        
        startClient(jwt: jwtToken)
        
        view.backgroundColor = .white
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        spark.phone.deregister { (error) in
            print(">>>> Spark phone deregistration complete with success=\(String(describing: error))")
        }
        jwtAuthentication.deauthorize()
    }
    
    public func startClient(jwt: String) {
        jwtAuthentication.authorizedWith(jwt: jwt)
        if jwtAuthentication.authorized {
            UIApplication.shared.registerForRemoteNotifications()
            spark.phone.register() { [weak self] error in
                if let error = error {
                    print(">>>> error: \(error)")
                } else {
                    //enable call button
                    print(">>>> registration successful")
                }
            }
        }
    }

}
