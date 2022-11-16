//
//  AddFriendsView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Mixpanel
import UIKit

final class AddFriendsView: UIView {
    private lazy var note: UILabel = {
        let label = UILabel()
        label.text = "Add friends to your map"
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        return label
    }()
    private lazy var animals: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleToFill
        view.image = UIImage(named: "FriendsEmptyState")
        return view
    }()
    lazy var addFriendButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        button.layer.cornerRadius = 13
        button.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)
        let customButtonTitle = NSMutableAttributedString(string: "Find Friends", attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ])
        button.setAttributedTitle(customButtonTitle, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = false
        return button
    }()

    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = 17
        self.backgroundColor = .white

        addSubview(note)
        note.snp.makeConstraints {
            $0.top.equalToSuperview().offset(11)
            $0.centerX.equalToSuperview()
        }

        addSubview(animals)
        animals.snp.makeConstraints {
            $0.height.equalTo(53.12)
            $0.width.equalTo(151)
            $0.centerX.equalToSuperview().offset(-5)
            $0.centerY.equalToSuperview().offset(-10)
        }

        addSubview(addFriendButton)
        addFriendButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.bottom.equalToSuperview().offset(-13)
            $0.height.equalTo(39)
        }

        let cancel = UIButton {
            $0.setImage(UIImage(named: "ChooseSpotCancel"), for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(self.closeFindFriends(_:)), for: .touchUpInside)
            $0.isHidden = false
            addSubview($0)
        }

        cancel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-5)
            $0.top.equalToSuperview().offset(5)
            $0.height.width.equalTo(30)
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func closeFindFriends(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "MapControllerCloseFindFriends")
        self.removeFromSuperview()
    }
}
