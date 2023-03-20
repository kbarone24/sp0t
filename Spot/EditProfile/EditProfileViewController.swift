//
//  EditProfileViewController.swift
//  Spot
//
//  Created by Arnold on 7/8/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseStorageUI
import FirebaseFunctions
import Mixpanel
import UIKit

protocol EditProfileDelegate: AnyObject {
    func finishPassing(userInfo: UserProfile)
}

class EditProfileViewController: UIViewController {
    var avatarImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.isUserInteractionEnabled = true
        return view
    }()
    private lazy var avatarBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.183, green: 0.183, blue: 0.183, alpha: 1)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 103 / 2
        view.isUserInteractionEnabled = true
        return view
    }()
    private lazy var avatarEditButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "EditAvatar"), for: .normal)
        return button
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.text = "Username"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()

    private lazy var usernameField: UITextField = {
        // TODO: Change font UniversLT75Black-Oblique
        let field = UITextField()
        field.backgroundColor = UIColor(red: 0.183, green: 0.183, blue: 0.183, alpha: 1)
        field.layer.cornerRadius = 15
        field.textAlignment = .center
        field.textColor = .white
        field.font = UIFont(name: "UniversCE-Black", size: 22)
        field.textContentType = .name
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
        return field
    }()

    private lazy var statusLabel: UIButton = {
        let label = UIButton()
        label.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)
        label.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        label.setTitleColor(UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1), for: .normal)
        label.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.contentVerticalAlignment = .center
        label.contentHorizontalAlignment = .center
        label.isHidden = false
        return label
    }()

    private var accountOptionsButton: UIButton = {
        let button = UIButton()
        button.setTitle("Account options", for: .normal)
        button.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
        return button
    }()
    lazy var activityIndicator = UIActivityIndicatorView()

    weak var delegate: EditProfileDelegate?
    var userProfile: UserProfile?
    var usernameText = ""

    let db = Firestore.firestore()
    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    init(userProfile: UserProfile? = nil) {
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
        super.init(nibName: nil, bundle: nil)
        edgesForExtendedLayout = []
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: true)
        navigationItem.title = "Edit Profile"

        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTap))
        cancelButton.setTitleTextAttributes([.foregroundColor: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), .font: UIFont(name: "SFCompactText-Medium", size: 14) as Any], for: .normal)
        navigationItem.leftBarButtonItem = cancelButton

        setSave(enabled: true)
    }

    private func viewSetup() {
        view.backgroundColor = UIColor(named: "SpotBlack")

        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(avatarEditAction))
        avatarBackground.addGestureRecognizer(avatarTap)
        view.addSubview(avatarBackground)
        avatarBackground.snp.makeConstraints {
            $0.top.equalTo(34)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(103)
            $0.width.equalTo(103)
        }

        avatarImage.addGestureRecognizer(avatarTap)
        avatarBackground.addSubview(avatarImage)
        let url = userProfile?.avatarURL ?? ""
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 144, height: 162), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
        avatarImage.snp.makeConstraints {
            $0.top.equalTo(23)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(79.62)
            $0.width.equalTo(70.78)
        }

        avatarEditButton.addTarget(self, action: #selector(avatarEditAction), for: .touchUpInside)
        view.addSubview(avatarEditButton)
        avatarEditButton.snp.makeConstraints {
            $0.leading.equalTo(avatarBackground.snp.trailing).offset(-25)
            $0.bottom.equalTo(avatarBackground).offset(3)
            $0.width.height.equalTo(42)
        }

        usernameLabel.text = "Username"
        view.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarBackground.snp.bottom).offset(30)
            $0.centerX.equalToSuperview()
        }

        usernameField.text = "@" + (userProfile?.username ?? "")
        usernameText = userProfile?.username ?? ""
        view.addSubview(usernameField)
        usernameField.snp.makeConstraints {
            $0.top.equalTo(usernameLabel.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(38)
            $0.height.equalTo(50)
        }

        view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalTo(usernameField.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(200)
            $0.height.equalTo(30)
        }

        accountOptionsButton.addTarget(self, action: #selector(addActionSheet), for: .touchUpInside)
        view.addSubview(accountOptionsButton)
        accountOptionsButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(72)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(activityIndicator)
        activityIndicator.isHidden = true
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(usernameField.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(20)
        }
    }
}

extension EditProfileViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }

        var remove = text.count
        for x in text where x == "@" {
            remove -= 1
        }

        let currentCharacterCount = remove
        let newLength = currentCharacterCount + string.count - range.length
        return newLength <= 16
    }

    @objc func textChanged(_ sender: UITextField) {
        print("text changed")
        guard let text = sender.text else { return }
        if text.contains("$") && text.count == 1 {
            sender.text = ""
        } else if !text.hasPrefix("@") && !text.isEmpty {
            sender.text = "@" + text
        }

        setUsername(text: sender.text)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func setUsername(text: String?) {
        setEmpty()

        var lowercaseUsername = text?.lowercased() ?? ""
        lowercaseUsername = lowercaseUsername.trimmingCharacters(in: .whitespaces)
        lowercaseUsername.removeAll(where: { $0 == "@" })
        usernameText = lowercaseUsername
        // set to original username, no need for query
        if usernameText == userProfile?.username {
            setAvailable()
            return
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.runUsernameQuery), object: nil)
        self.perform(#selector(self.runUsernameQuery), with: nil, afterDelay: 0.4)
    }

    @objc func runUsernameQuery() {
        let localUsername = self.usernameText
        setEmpty()
        activityIndicator.startAnimating()

        userService?.usernameAvailable(username: localUsername) { (errorMessage) in
            if localUsername != self.usernameText { return } /// return if username field already changed
            if errorMessage != "" {
                self.setUnavailable(text: errorMessage)
            } else {
                self.setAvailable()
            }
        }
    }

    private func setAvailable() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = false
        statusLabel.setImage(UIImage(named: "UsernameAvailable"), for: .normal)
        statusLabel.setTitleColor(UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1), for: .normal)
        statusLabel.setTitle("Available", for: .normal)
        setSave(enabled: true)
    }

    private func setUnavailable(text: String) {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = false
        statusLabel.setImage(UIImage(named: "UsernameTaken"), for: .normal)
        statusLabel.setTitleColor(UIColor(red: 1, green: 0.376, blue: 0.42, alpha: 1), for: .normal)
        statusLabel.setTitle(text, for: .normal)
        setSave(enabled: false)
    }

    private func setSave(enabled: Bool) {
        if enabled {
            let doneButton = UIBarButtonItem(
                image: UIImage(named: "EditProfileSave")?.withRenderingMode(.alwaysOriginal),
                style: .done,
                target: self,
                action: #selector(doneTap)
            )
            navigationItem.rightBarButtonItem = doneButton
        } else {
            let doneButton = UIBarButtonItem(
                image: UIImage(named: "EditProfileSaveDisabled")?.withRenderingMode(.alwaysOriginal),
                style: .done,
                target: self,
                action: nil
            )
            navigationItem.rightBarButtonItem = doneButton
        }
    }

    private func setEmpty() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
        setSave(enabled: false)
    }
}
