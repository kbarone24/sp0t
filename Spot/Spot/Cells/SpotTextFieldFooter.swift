//
//  SpotFooterView.swift
//  Spot
//
//  Created by Kenny Barone on 7/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage
import Mixpanel

protocol SpotTextFieldFooterDelegate: AnyObject {
    func textAreaTap()
    func cameraTap()
}

class SpotTextFieldFooter: UIView {
    private lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var textArea: UITextField = {
        let view = UITextField()
        view.backgroundColor = UIColor(red: 0.217, green: 0.217, blue: 0.217, alpha: 1)
        view.setLeftPaddingPoints(17)
        view.textColor = UIColor(red: 0.621, green: 0.618, blue: 0.618, alpha: 1)
        view.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 21)
        view.layer.cornerRadius = 22
        view.layer.masksToBounds = true
        view.textAlignment = .left
        view.isEnabled = false
        return view
    }()

    private lazy var textButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(textAreaTap), for: .touchUpInside)
        return button
    }()

    private lazy var cameraButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setImage(UIImage(named: "CameraOutletButton"), for: .normal)
        button.addTarget(self, action: #selector(cameraTap), for: .touchUpInside)
        return button
    }()

    weak var delegate: SpotTextFieldFooterDelegate?

    init (parent: SpotPostParent) {
        super.init(frame: .zero)

        backgroundColor = SpotColors.HeaderGray.color
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad), name: NSNotification.Name(("UserProfileLoad")), object: nil)

        addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(8)
            $0.top.equalTo(10)
            $0.width.equalTo(37.33)
            $0.height.equalTo(42)
        }
        setAvatarImage()

        addSubview(textArea)
        textArea.snp.makeConstraints {
            $0.top.equalTo(15)
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8)
            $0.trailing.equalTo(-20)
            $0.height.equalTo(44)
        }

        addSubview(cameraButton)
        cameraButton.snp.makeConstraints {
            $0.centerY.equalTo(textArea).offset(-1)
            $0.trailing.equalTo(textArea).offset(-16)
            $0.height.equalTo(40.8)
            $0.width.equalTo(35.7)
        }

        addSubview(textButton)
        textButton.snp.makeConstraints {
            $0.leading.top.bottom.equalTo(textArea)
            $0.trailing.equalTo(cameraButton.snp.leading).offset(-6)
        }

        switch parent {
        case .PopPage:
            textArea.text = "what's poppin"
        default:
            textArea.text = "sup..."
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        avatarImage.sd_cancelCurrentImageLoad()
    }

    @objc func textAreaTap() {
        Mixpanel.mainInstance().track(event: "SpotPageTextAreaTap")
        delegate?.textAreaTap()
    }

    @objc func cameraTap() {
        print("camera tap")
        Mixpanel.mainInstance().track(event: "SpotPageCameraTap")
        delegate?.cameraTap()
    }

    @objc func notifyUserLoad() {
        setAvatarImage()
    }

    private func setAvatarImage() {
        let userAvatar = UserDataModel.shared.userInfo.getAvatarImage()
        avatarImage.image = userAvatar
    }
}
