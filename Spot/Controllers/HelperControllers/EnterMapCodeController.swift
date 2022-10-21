//
//  EnterMapCodeController.swift
//  Spot
//
//  Created by Kenny Barone on 9/14/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import UIKit

protocol MapCodeDelegate {
    func finishPassing(newMapID: String)
}

class EnterMapCodeController: UIViewController {
    var textField: UITextField!
    var enterButton: UIButton!
    var errorBox: ErrorBox!

    var delegate: MapCodeDelegate?
    let db = Firestore.firestore()

    init() {
        super.init(nibName: nil, bundle: nil)
        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpView() {
        view.backgroundColor = .white
        let exitButton = UIButton {
            $0.setImage(UIImage(named: "CancelButtonGray"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
            view.addSubview($0)
        }
        exitButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(4)
            $0.height.width.equalTo(46)
        }

        let inviteLabel = UILabel {
            $0.text = "Invited to a map?"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 25)
            $0.textAlignment = .center
            view.addSubview($0)
        }
        inviteLabel.snp.makeConstraints {
            $0.top.equalTo(150)
            $0.centerX.equalToSuperview()
        }

        let subtitle = UILabel {
            $0.text = "Enter your code to join"
            $0.textColor = UIColor(red: 0.712, green: 0.712, blue: 0.712, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 16)
            $0.textAlignment = .center
            view.addSubview($0)
        }
        subtitle.snp.makeConstraints {
            $0.top.equalTo(inviteLabel.snp.bottom).offset(4)
            $0.centerX.equalToSuperview()
        }

        textField = UITextField {
            $0.borderStyle = .roundedRect
            $0.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            var placeholderText = NSMutableAttributedString()
            placeholderText = NSMutableAttributedString(string: "Enter map code", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Medium", size: 21) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor(red: 0.733, green: 0.733, blue: 0.733, alpha: 1)
            ])
            $0.attributedPlaceholder = placeholderText
            $0.keyboardType = .alphabet
            $0.autocorrectionType = .no
            $0.autocapitalizationType = .none
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 21)
            $0.textColor = UIColor(red: 0.292, green: 0.292, blue: 0.292, alpha: 1)
            $0.textAlignment = .center
            $0.delegate = self
            view.addSubview($0)
        }
        textField.snp.makeConstraints {
            $0.top.equalTo(subtitle.snp.bottom).offset(30)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(50)
        }

        enterButton = UIButton {
            $0.layer.cornerRadius = 8
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.setTitle("Enter", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 16)
            $0.addTarget(self, action: #selector(enterTap), for: .touchUpInside)
            $0.alpha = 0.3
            $0.isEnabled = false
            view.addSubview($0)
        }
        enterButton.snp.makeConstraints {
            $0.top.equalTo(textField.snp.bottom).offset(25)
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.height.equalTo(51)
        }

        errorBox = ErrorBox {
            $0.isHidden = true
            view.addSubview($0)
        }
        errorBox.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(enterButton.snp.bottom).offset(15)
            $0.height.equalTo(errorBox.label.snp.height).offset(12)
        }
    }

    @objc func cancelTap() {
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }

    @objc func enterTap() {
        checkForCode(code: textField.text ?? "") { [weak self] mapID in
            guard let self = self else { return }
            if mapID != nil {
                self.delegate?.finishPassing(newMapID: mapID!)
                let uid = UserDataModel.shared.uid
                self.db.collection("maps").document(mapID!).updateData(["memberIDs": FieldValue.arrayUnion([uid]), "likers": FieldValue.arrayUnion([uid])])
                DispatchQueue.main.async { self.dismiss(animated: true) }

            } else {
                self.errorBox.isHidden = false
                self.errorBox.message = "Invalid code"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self else { return }
                    self.errorBox.isHidden = true
                }
            }
        }
    }

    func checkForCode(code: String, completion: @escaping(_ mapID: String?) -> Void) {
        db.collection("maps").whereField("joinCode", isEqualTo: code).getDocuments { snap, _ in
            if snap?.documents.count ?? 0 == 0 { completion(nil); return }
            if let doc = snap?.documents.first {
                completion(doc.documentID)
                return
            } else { completion(nil); return }
        }
    }
}

extension EnterMapCodeController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        let enabled = textField.text?.count ?? 0 > 2
        enterButton.isEnabled = enabled
        enterButton.alpha = enabled ? 1.0 : 0.3
    }
}
