//
//  ConfirmCodeController.swift
//  Spot
//
//  Created by Kenny Barone on 3/24/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth
import Mixpanel
import UIKit

class ConfirmCodeController: UIViewController {
    var newUser: NewUser?
    lazy var codeType: CodeType = .logIn

    lazy var verificationID = ""

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "LandingPageBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        // TODO: change font (UniversCEMedium-Bold)
        let label = UILabel()
        label.textColor = UIColor(red: 0.054, green: 0.054, blue: 0.054, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 22)
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private lazy var codeField: UITextField = {
        // TODO: change font (UniversLTBlack-Oblique)
        let textField = PaddedTextField()
        textField.font = UIFont(name: "UniversCE-Black", size: 27)
        textField.textAlignment = .center
        textField.tintColor = UIColor(named: "SpotGreen")
        textField.textColor = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 1)
        var placeholderText = NSMutableAttributedString()
        placeholderText = NSMutableAttributedString(string: "00000", attributes: [
            NSAttributedString.Key.font: UIFont(name: "UniversCE-Black", size: 27) as Any,
            NSAttributedString.Key.foregroundColor: UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 0.25)
        ])
        textField.attributedPlaceholder = placeholderText
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        return textField
    }()
    private lazy var confirmButton: UIButton = {
        let button = SignUpPillButton(text: "")
        button.alpha = 0.4
        button.addTarget(self, action: #selector(confirmTapped(_:)), for: .touchUpInside)
        return button
    }()
    // only shows for delete account
    private lazy var cancelButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        button.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
        return button
    }()

    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.919, green: 0.919, blue: 0.919, alpha: 1)
        return view
    }()

    private lazy var activityIndicator = UIActivityIndicatorView(style: .medium)
    private lazy var errorBox = ErrorBox()

    var cancelOnDismiss = false
    let sp0tb0tID = "T4KMLe3XlQaPBJvtZVArqXQvaNT2"
    var deleteAccountDelegate: DeleteAccountDelegate?
    
    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()
    
    private lazy var postService: PostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.postService)
        return service
    }()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableKeyboardMethods()
        DispatchQueue.main.async { self.codeField.becomeFirstResponder() }
        Mixpanel.mainInstance().track(event: "ConfirmCodeOpen")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disableKeyboardMethods()
    }

    func enableKeyboardMethods() {
        cancelOnDismiss = false
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        cancelOnDismiss = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        setUpNavBar()
    }

    func setUpNavBar() {
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = UIColor.black
    }
    
    func setUpViews() {
        view.backgroundColor = .white

        view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        titleLabel.text = codeType == .deleteAccount ? "Enter code to delete your account" : "Enter your code"
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview().offset(-200)
            $0.centerX.equalToSuperview()
            $0.width.lessThanOrEqualToSuperview().offset(-28)
        }

        view.addSubview(codeField)
        codeField.addTarget(self, action: #selector(codeChanged(_:)), for: .editingChanged)
        codeField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.top.equalTo(titleLabel.snp.bottom).offset(54)
            $0.height.equalTo(40)
        }

        view.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.height.equalTo(3)
            $0.width.equalTo(codeField.snp.width)
            $0.top.equalTo(codeField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }

        let titleString = codeType == .logIn ? "Log in" : codeType == .newAccount ? "Next" : "Delete Account"
        confirmButton.setTitle(titleString, for: .normal)
        if codeType == .deleteAccount {
            confirmButton.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        }
        view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }

        activityIndicator.isHidden = true
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.color = UIColor(red: 0.358, green: 0.357, blue: 0.357, alpha: 0.7)
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(bottomLine.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        errorBox.isHidden = true
        view.addSubview(errorBox)
        errorBox.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(bottomLine.snp.bottom).offset(15)
            $0.height.equalTo(errorBox.label.snp.height).offset(12)
        }

        if codeType == .deleteAccount {
            view.addSubview(cancelButton)
            cancelButton.snp.makeConstraints {
                $0.top.leading.equalTo(5)
                $0.height.width.equalTo(40)
            }
        }
    }

    @objc func backTapped() {
        DispatchQueue.main.async { self.dismiss(animated: false, completion: nil) }
    }

    @objc func codeChanged(_ sender: UITextField) {
        confirmButton.alpha = sender.text?.count ?? 0 != 6 ? 0.4 : 1.0
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        if cancelOnDismiss { return }
        // new spot name view editing when textview not first responder
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.confirmButton.snp.removeConstraints()
            self.confirmButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height - 20)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        // new spot name view editing when textview not first responder
        if cancelOnDismiss { return }
        animateWithKeyboard(notification: notification) { _ in
            self.confirmButton.snp.removeConstraints()
            self.confirmButton.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(49)
                $0.bottom.equalToSuperview().offset(-30)
            }
        }
    }

    @objc func confirmTapped(_ sender: UIButton) {
        guard let code = codeField.text?.trimmingCharacters(in: .whitespaces) else { return }
        if code.count != 6 { showError(message: "Invalid code"); return }

        let phoneCredential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code)

        activityIndicator.startAnimating()
        sender.isUserInteractionEnabled = false

        checkForUsername { available in
            // want to check to make sure no one took this username while user was authenticating
            if !available { self.showError(message: "Username taken"); return }
            Auth.auth().signIn(with: phoneCredential) { (authResult, err) in
                if err == nil && authResult != nil {

                    if self.codeType == .logIn {
                        Mixpanel.mainInstance().track(event: "ConfirmCodeLoginSuccess")
                        DispatchQueue.main.async { self.animateHome() }
                        return

                    } else if self.codeType == .newAccount {
                        self.getInitialFriends { friendIDs in
                            Mixpanel.mainInstance().track(event: "ConfirmCodeNewAccountSuccess")
                            self.saveUserToFirebase(friendIDs: friendIDs)
                            self.setInitialValues(friendIDs: friendIDs)
                            self.presentAvatarSelection()
                        }

                    } else if self.codeType == .deleteAccount {
                        DispatchQueue.main.async {
                            self.dismiss(animated: true)
                            self.deleteAccountDelegate?.finishPassing()
                        }
                    }

                } else {
                    Mixpanel.mainInstance().track(event: "ConfirmCodeInvalidCode")
                    sender.isUserInteractionEnabled = true
                    self.showError(message: "Invalid code")
                }
            }
        }
    }

    func checkForUsername(completion: @escaping(_ available: Bool) -> Void) {
        if newUser == nil { completion(true); return}
        let db = Firestore.firestore()
        let usersRef = db.collection("usernames")
        let query = usersRef.whereField("username", isEqualTo: newUser?.username ?? "")
        query.getDocuments { snap, _ in
            completion(snap?.documents.count ?? 0 == 0)
        }
    }

    func showError(message: String) {
        self.activityIndicator.stopAnimating()
        self.errorBox.isHidden = false
        self.errorBox.message = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.errorBox.isHidden = true
        }
    }

    func saveUserToFirebase(friendIDs: [String]) {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let username = newUser?.username ?? ""
        let lowercaseName = newUser?.name.lowercased() ?? ""
        let nameKeywords = lowercaseName.getKeywordArray()
        let usernameKeywords = username.getKeywordArray()
        var topFriends = [String: Any]()
        for friend in friendIDs {
            let value = friend == sp0tb0tID ? 0 : 5
            topFriends[friend] = value
        }

        // give user random avatar so they dont show up blank if they quit
        let randomAvatar = AvatarGenerator.shared.getBaseAvatars().randomElement()
        let url = randomAvatar?.getURL() ?? ""
        let family = randomAvatar?.family.rawValue ?? ""
        let pendingFriendRequests = [String]()

        let values = ["name": newUser?.name ?? "",
                      "username": newUser?.username ?? "",
                      "phone": newUser?.phone ?? "",
                      "userBio": "",
                      "friendsList": friendIDs,
                      "spotScore": 1,
                      "admin": false,
                      "lowercaseName": lowercaseName,
                      "imageURL": "",
                      "currentLocation": "",
                      "verifiedPhone": true,
                      "pendingFriendRequests": pendingFriendRequests,
                      "usernameKeywords": usernameKeywords,
                      "nameKeywords": nameKeywords,
                      "topFriends": topFriends,
                      "avatarURL": url,
                      "avatarFamily": family,
                      "avatarItem": "",
                      "newAvatarNoti": true,
                      "lastSeen": Timestamp(),
                      "lastHereNow": "",
        ] as [String: Any]

        db.collection("users").document(uid).setData(values, merge: true)

        let defaults = UserDefaults.standard // save verfiied phone login to user defaults
        defaults.set(newUser?.phone ?? "", forKey: "phoneNumber")

        let docID = UUID().uuidString
        db.collection("usernames").document(docID).setData(["username": newUser?.username ?? ""])
    }

    func presentAvatarSelection() {
        let avi = AvatarSelectionController(sentFrom: .create, family: nil)
        DispatchQueue.main.async {
            self.view.endEditing(true)
            self.activityIndicator.stopAnimating()
            self.navigationController?.pushViewController(avi, animated: true)
        }
    }

    func animateHome() {
        DispatchQueue.main.async {
            self.view.endEditing(true)
            self.activityIndicator.stopAnimating()
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                    return
                }
            self.navigationController?.popToRootViewController(animated: false)
            let homeScreenController = HomeScreenController(viewModel: HomeScreenViewModel(serviceContainer: ServiceContainer.shared))
            let navigationController = UINavigationController(rootViewController: homeScreenController)
            window.rootViewController = navigationController
            window.makeKeyAndVisible()
        }
    }
}

extension ConfirmCodeController {
    func getInitialFriends(completion: @escaping (_ friendIDs: [String]) -> Void) {
        var initialFriends: [String] = [sp0tb0tID]
        let db = Firestore.firestore()
        let phone = newUser?.phone.formatNumber() ?? ""
        db.collection("users").whereField("sentInvites", arrayContains: phone).getDocuments { snap, _ in
            guard let snap = snap else { completion(initialFriends); return }
            for doc in snap.documents {
                initialFriends.append(doc.documentID)
            }
            completion(initialFriends)
        }
    }

    func setInitialValues(friendIDs: [String]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let timestamp = Timestamp(date: Date())

        for friendID in friendIDs {
            friendService?.addFriendToFriendsList(userID: friendID, friendID: uid, completion: nil)

            db.collection("users").document(friendID).collection("notifications").addDocument(data: [
                "status": "accepted",
                "timestamp": timestamp,
                "senderID": uid,
                "senderUsername": newUser?.username ?? "",
                "type": "friendRequest",
                "seen": false
            ])
            
            db.collection("users").document(uid).collection("notifications").addDocument(data: [
                "status": "accepted",
                "timestamp": timestamp,
                "senderID": friendID,
                "senderUsername": "",
                "type": "friendRequest",
                "seen": false
            ])

            /*
            // call on frontend for immediate post adjust
            if friendID != sp0tb0tID {
                DispatchQueue.global().async { [weak self] in
                    self?.postService?.adjustPostFriendsList(userID: uid, friendID: friendID, completion: nil)
                }
            }
            */
        }
    }
    
    // https://www.advancedswift.com/animate-with-ios-keyboard-swift/
    private func animateWithKeyboard(
        notification: NSNotification,
        animations: ((_ keyboardFrame: CGRect) -> Void)?
    ) {
        // Extract the duration of the keyboard animation
        let durationKey = UIResponder.keyboardAnimationDurationUserInfoKey
        let duration = notification.userInfo?[durationKey] as? Double ?? 0

        // Extract the final frame of the keyboard
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        let keyboardFrameValue = notification.userInfo?[frameKey] as? NSValue

        // Extract the curve of the iOS keyboard animation
        let curveKey = UIResponder.keyboardAnimationCurveUserInfoKey
        let curveValue = notification.userInfo?[curveKey] as? Int ?? 0
        let curve = UIView.AnimationCurve(rawValue: curveValue) ?? .easeIn

        // Create a property animator to manage the animation
        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            // Perform the necessary animation layout updates
            animations?(keyboardFrameValue?.cgRectValue ?? .zero)

            // Required to trigger NSLayoutConstraint changes
            // to animate
            self.view?.layoutIfNeeded()
        }

        // Start the animation
        animator.startAnimation()
    }
}
