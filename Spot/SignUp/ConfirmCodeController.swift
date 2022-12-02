//
//  ConfirmCodeController.swift
//  Spot
//
//  Created by Kenny Barone on 3/24/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import IQKeyboardManagerSwift
import Mixpanel
import UIKit

class ConfirmCodeController: UIViewController {
    var newUser: NewUser?
    lazy var codeType: CodeType = .logIn

    lazy var verificationID = ""
    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 20)
        return label
    }()
    private lazy var codeField: UITextField = {
        let textField = PaddedTextField()
        textField.font = UIFont(name: "SFCompactText-Semibold", size: 27.5)
        textField.textAlignment = .center
        textField.tintColor = UIColor(named: "SpotGreen")
        textField.textColor = .black
        var placeholderText = NSMutableAttributedString()
        placeholderText = NSMutableAttributedString(string: "00000", attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 27.5) as Any,
            NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
        ])
        textField.attributedPlaceholder = placeholderText
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        return textField
    }()
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 9
        button.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
        button.alpha = 0.4
        return button
    }()
    // only shows for delete account
    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        return button
    }()

    private lazy var activityIndicator = CustomActivityIndicator()
    private lazy var errorBox = ErrorBox()

    var cancelOnDismiss = false
    let sp0tb0tID = "T4KMLe3XlQaPBJvtZVArqXQvaNT2"
    var deleteAccountDelegate: DeleteAccountDelegate?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableKeyboardMethods()
        DispatchQueue.main.async { self.codeField.becomeFirstResponder() }
        Mixpanel.mainInstance().track(event: "ConfirmCodeOpen")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = true
        disableKeyboardMethods()
    }

    func enableKeyboardMethods() {
        cancelOnDismiss = false
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.enable = false // disable for textView sticking to keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        cancelOnDismiss = true
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        setUpNavBar()
    }

    func setUpNavBar() {
        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white
        navigationController?.navigationBar.addWhiteBackground()

        let logo = UIImage(named: "OnboardingLogo")
        let imageView = UIImageView(image: logo)
        // imageView.contentMode = .scaleToFill
        imageView.snp.makeConstraints {
            $0.height.equalTo(32.9)
            $0.width.equalTo(78)

        }
        self.navigationItem.titleView = imageView

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrow"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
    }
    func setUpViews() {
        view.backgroundColor = .white

        label.text = codeType == .deleteAccount ? "Enter code to delete your account" : "Enter your code"
        view.addSubview(label)
        label.snp.makeConstraints {
            $0.top.equalToSuperview().offset(114)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(codeField)
        codeField.addTarget(self, action: #selector(codeChanged(_:)), for: .editingChanged)
        codeField.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.top.equalTo(label.snp.bottom).offset(30)
            $0.height.equalTo(40)
        }

        let bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            view.addSubview($0)
        }
        bottomLine.snp.makeConstraints {
            $0.height.equalTo(1.5)
            $0.width.equalTo(codeField.snp.width)
            $0.top.equalTo(codeField.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }

        let titleString = codeType == .logIn ? "Log in" : codeType == .newAccount ? "Next" : "Delete Account"
        let customButtonTitle = NSMutableAttributedString(string: titleString, attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 16) as Any,
            NSAttributedString.Key.foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        ])
        if codeType == .deleteAccount { confirmButton.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1) }
        confirmButton.setAttributedTitle(customButtonTitle, for: .normal)
        confirmButton.addTarget(self, action: #selector(confirmTapped(_:)), for: .touchUpInside)
        view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(49)
            $0.bottom.equalToSuperview().offset(-30)
        }

        activityIndicator.isHidden = true
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
            cancelButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
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
                        DispatchQueue.main.async { self.animateToMap() }
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

        let blankAvatarURL =
        "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F00000000resources%2FGroup%2021877(1).png?alt=media&token=5c102486-f5b2-41d7-83a0-96f8ffcddcbe"
        let values = ["name": newUser?.name ?? "",
                      "username": newUser?.username ?? "",
                      "phone": newUser?.phone ?? "",
                      "userBio": "",
                      "friendsList": friendIDs,
                      "spotScore": 0,
                      "admin": false,
                      "lowercaseName": lowercaseName,
                      "imageURL": blankAvatarURL,
                      "currentLocation": "",
                      "verifiedPhone": true,
                      "sentInvites": [],
                      "pendingFriendRequests": [],
                      "respondedToCampusMap": false,
                      "usernameKeywords": usernameKeywords,
                      "nameKeywords": nameKeywords,
                      "topFriends": topFriends,
                      "avatarURL": ""
        ] as [String: Any]

        db.collection("users").document(uid).setData(values, merge: true)

        let defaults = UserDefaults.standard // save verfiied phone login to user defaults
        defaults.set(newUser?.phone ?? "", forKey: "phoneNumber")

        let docID = UUID().uuidString
        db.collection("usernames").document(docID).setData(["username": newUser?.username ?? ""])
    }

    func presentAvatarSelection() {
        let avi = AvatarSelectionController(sentFrom: .create)
        DispatchQueue.main.async {
            self.view.endEditing(true)
            self.activityIndicator.stopAnimating()
            self.navigationController?.pushViewController(avi, animated: true)
        }
    }

    func animateToMap() {
        view.endEditing(true)
        activityIndicator.stopAnimating()

        let storyboard = UIStoryboard(name: "Map", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "MapVC") as? MapController else { return }
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen

        let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: false)
            window?.rootViewController = navController
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
            addFriendToFriendsList(userID: friendID, friendID: uid)

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
            // call on frontend for immediate post adjust
            if friendID != sp0tb0tID {
                DispatchQueue.global().async {
                    self.adjustPostFriendsList(userID: uid, friendID: friendID, completion: nil)
                }
            }
        }
    }
}
