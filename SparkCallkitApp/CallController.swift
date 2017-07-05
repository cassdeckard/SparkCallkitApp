import UIKit
import SparkSDK

class CallController: UIViewController {
    private let spark: Spark
    private let jwtAuthentication = JWTAuthenticator()
    private let user: User
    
    let localMediaView = MediaRenderView()
    let remoteMediaView = MediaRenderView()
    
    var activeCall: Call?
    
    let usernameLabel: UILabel = {
        let label = UILabel()
        
        label.textColor = .black
        
        return label
    }()
    
    let callButton: UIButton = {
        let button = UIButton()
        
        button.setTitle("Make Call", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.setTitleColor(.lightGray, for: .disabled)
        button.backgroundColor = .gray
        button.isEnabled = false
        
        return button
    }()
    
    let endCallButton: UIButton = {
        let button = UIButton()
        
        button.setTitle("End Call", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .gray
        button.isHidden = true
        
        return button
    }()

    init(user: User) {
        self.user = user
        spark = Spark(authenticator: jwtAuthentication)
        
        usernameLabel.text = "Hello, \(user.displayName())!"
        
        super.init(nibName: nil, bundle: nil)
        
        startClient(jwt: user.jwt())
        
        view.backgroundColor = .white
        
        view.addSubview(usernameLabel)
        view.addSubview(callButton)
        view.addSubview(endCallButton)
        view.addSubview(remoteMediaView)
        view.addSubview(localMediaView)
        
        remoteMediaView.backgroundColor = .red
        localMediaView.backgroundColor = .green
        
        callButton.addTarget(self, action: #selector(startCall), for: .touchUpInside)
        endCallButton.addTarget(self, action: #selector(hangupCall), for: .touchUpInside)
        
        setUpCallHandlers()
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
        
        endCallButton.sizeToFit()
        endCallButton.frame.origin.x = view.frame.midX - endCallButton.frame.width / 2
        endCallButton.frame.origin.y = callButton.frame.maxY + 40
        
        remoteMediaView.frame.origin.y = view.frame.midY
        remoteMediaView.frame.size.width = view.frame.width
        remoteMediaView.frame.size.height = view.frame.height / 2
        
        localMediaView.frame.size.width = remoteMediaView.frame.width * 0.5
        localMediaView.frame.size.height = remoteMediaView.frame.height * 0.5
        localMediaView.frame.origin.y = view.frame.height - localMediaView.frame.height
    }
    
    func startClient(jwt: String) {
        jwtAuthentication.authorizedWith(jwt: jwt)
        if jwtAuthentication.authorized {
            UIApplication.shared.registerForRemoteNotifications()
            spark.phone.register() { [weak self] error in
                if let error = error {
                    print(">>>> error: \(error)")
                } else {
                    self?.callButton.isEnabled = true
                    self?.spark.phone.requestVideoCodecActivation()
                    print(">>>> registration successful")
                }
            }
        }
    }
    
    func setUpCallHandlers() {
        spark.phone.onIncoming = { [unowned self] call in
            self.callButton.isEnabled = false
            
            print(">>>> callIncoming")
            
            call.onDisconnected = { [unowned self] reason in
                print(">>>> callDisconnected")
                self.callIsEnded()
            }
            
            self.activeCall = call
            
            call.answer(option: .audioVideo(local: self.localMediaView, remote: self.remoteMediaView), completionHandler: { [unowned self] error in
                if let error = error {
                    print(">>>> error answering call: \(error)")
                } else {
                    print(">>>> call answered successfully")
                    self.endCallButton.isHidden = false
                }
            })

        }
    }

    
    func startCall() {
        callButton.isEnabled = false
        
        spark.phone.dial(user.userToCall().sparkId(), option: .audioVideo(local: localMediaView, remote: remoteMediaView)) { [weak self] response in
            //completion handler
            
            switch response {
            case .success(let call):
                
                self?.endCallButton.isHidden = false
                self?.activeCall = call
                
                call.onRinging = {
                    print(">>>> callRinging")
                }
                
                call.onConnected = {
                    print(">>>> callConnected")
                }
                
                call.onDisconnected = { reason in
                    print(">>>> callDisconnected")
                    self?.callIsEnded()
                }
                
            case .failure(_):
                print(">>>>> failure...")
                self?.callIsEnded()
            }

        }
    }
    
    func hangupCall() {
        print(">>>>> End Call()")
        
        if let call = activeCall {
            if call.direction == .incoming && call.status == .ringing {
                call.reject { error in
                    print(">>>>> reject error: \(String(describing: error))")
                }
            } else {
                call.hangup { error in
                    print(">>>>> hangup error: \(String(describing: error))")
                }
            }
        }
        
        callIsEnded()
    }
    
    func callIsEnded() {
        endCallButton.isHidden = true
        callButton.isEnabled = true
        activeCall = nil
    }
}
