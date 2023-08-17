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
        view.text = "sup..."
        view.setLeftPaddingPoints(17)
        view.textColor = UIColor(red: 0.621, green: 0.618, blue: 0.618, alpha: 1)
        view.font =  SpotFonts.SFCompactRoundedRegular.fontWith(size: 19)
        view.layer.cornerRadius = 24
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
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CameraOutletButton"), for: .normal)
        button.addTarget(self, action: #selector(cameraTap), for: .touchUpInside)
        return button
    }()

    weak var delegate: SpotTextFieldFooterDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad), name: NSNotification.Name(("UserProfileLoad")), object: nil)

        addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(8)
            $0.top.equalTo(10)
            $0.width.equalTo(37.33)
            $0.height.equalTo(42)
        }
        setAvatarImage()

        addSubview(cameraButton)
        cameraButton.snp.makeConstraints {
            $0.top.equalTo(10)
            $0.trailing.equalTo(-16)
            $0.height.width.equalTo(54)
        }

        addSubview(textArea)
        textArea.snp.makeConstraints {
            $0.top.equalTo(15)
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8)
            $0.trailing.equalTo(cameraButton.snp.leading).offset(-7)
            $0.height.equalTo(44)
        }

        addSubview(textButton)
        textButton.snp.makeConstraints {
            $0.edges.equalTo(textArea)
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
