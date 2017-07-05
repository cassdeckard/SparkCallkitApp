import UIKit
import CallKit
import SparkSDK

class CallController: UIViewController {
    fileprivate let spark: Spark
    private let jwtAuthentication = JWTAuthenticator()
    fileprivate let user: User
    
    let localMediaView = MediaRenderView()
    let remoteMediaView = MediaRenderView()
    
    fileprivate let callProvider: CXProvider
    fileprivate let callController: CXCallController
    
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
        
        let providerConfiguration = CXProviderConfiguration(localizedName: "Patient Central")
        providerConfiguration.supportedHandleTypes = [.generic]
        providerConfiguration.supportsVideo = true
        providerConfiguration.ringtoneSound = "Ringtone.caf"
        callProvider = CXProvider(configuration: providerConfiguration)
        
        callController = CXCallController()
        
        super.init(nibName: nil, bundle: nil)
        
        callProvider.setDelegate(self, queue: nil)
        
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
        endCallButton.addTarget(self, action: #selector(hangUp), for: .touchUpInside)
        
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
    
    public func hangUp() {
        if let uuid = activeCall?.uuid {
            let endCallAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction()
            transaction.addAction(endCallAction)
            
            requestTransaction(transaction)
        }
    }
    
    private func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                print("UNEXPECTED FAILURE: Error requesting transaction: \(error)")
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

            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = CXHandle(type: .generic, value: self.user.userToCall().displayName())
            callUpdate.hasVideo = true
            
            self.callProvider.reportNewIncomingCall(with: call.uuid, update: callUpdate) { [unowned self] error in
                if error == nil {
                    self.activeCall = call
                }
            }

        }
    }

    func startCall() {
        callButton.isEnabled = false
        
        spark.phone.dial(user.userToCall().sparkId(), option: .audioVideo(local: localMediaView, remote: remoteMediaView)) { [unowned self] response in
            
            guard case .success(let call) = response else {
                self.activeCall = nil
                return
            }
            
            self.activeCall = call
            self.endCallButton.isHidden = false
            
            call.onRinging = {
                print(">>>> callRinging")
            }
            
            call.onConnected = {
                print(">>>> callConnected")
                self.callProvider.reportOutgoingCall(with: call.uuid, startedConnectingAt: Date())
            }
            
            call.onDisconnected = { reason in
                print(">>>> callDisconnected")
                self.callIsEnded()
            }
            
            let handle = CXHandle(type: .generic, value: self.user.userToCall().displayName())
            let startCallAction = CXStartCallAction(call: call.uuid, handle: handle)
            startCallAction.isVideo = true
            
            let transaction = CXTransaction()
            transaction.addAction(startCallAction)
            self.requestTransaction(transaction)
        }
    }
    
    func hangupOrRejectCall() {
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

extension CallController: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let _ = self.activeCall else {
            action.fail()
            return
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if let call = activeCall {
            call.answer(option: .audioVideo(local: self.localMediaView, remote: self.remoteMediaView), completionHandler: { [unowned self] error in
                if let error = error {
                    print(">>>> error answering call: \(error)")
                    action.fail()
                } else {
                    print(">>>> call answered successfully")
                    self.endCallButton.isHidden = false
                    action.fulfill()
                }
            })
        } else {
            action.fail()
        }

    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        hangupOrRejectCall()
        action.fulfill()
    }
}
