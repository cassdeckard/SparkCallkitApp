import UIKit
import SparkSDK

class CallController: UIViewController {
    private let spark: Spark
    private let jwtAuthentication = JWTAuthenticator()
    
    let usernameLabel: UILabel = {
        let label = UILabel()
        
        label.textColor = .black
        
        return label
    }()
    
    let callButton: UIButton = {
        let button = UIButton()
        
        button.setTitle("Make Call", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .gray
        
        return button
    }()

    init(username: String, jwtToken: String) {
        spark = Spark(authenticator: jwtAuthentication)
        
        usernameLabel.text = "Hello, \(username)!"
        
        super.init(nibName: nil, bundle: nil)
        
        startClient(jwt: jwtToken)
        
        view.backgroundColor = .white
        
        view.addSubview(usernameLabel)
        view.addSubview(callButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        spark.phone.deregister { (error) in
            print(">>>> Spark phone deregistration complete with error=\(String(describing: error))")
        }
        jwtAuthentication.deauthorize()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard let navBarHeight = navigationController?.navigationBar.frame.height else { return }
        
        usernameLabel.sizeToFit()
        usernameLabel.frame.origin.x = view.frame.midX - usernameLabel.frame.width / 2
        usernameLabel.frame.origin.y = navBarHeight + 40
        
        callButton.sizeToFit()
        callButton.frame.origin.x = view.frame.midX - callButton.frame.width / 2
        callButton.frame.origin.y = usernameLabel.frame.maxY + 40
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
