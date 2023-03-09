//
//  FriendRequestCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Mixpanel
import UIKit
import SDWebImage

final class FriendRequestCell: UICollectionViewCell {
    var friendRequest: UserNotification?
    weak var collectionDelegate: FriendRequestCollectionCellDelegate?
    weak var notificationControllerDelegate: NotificationsDelegate?
    var accepted = false

    private lazy var activityIndicator = UIActivityIndicatorView()
    private lazy var profilePic: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = false
        view.layer.cornerRadius = self.frame.width / 4
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.isUserInteractionEnabled = true
        return view
    }()
    private lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.contentMode = UIView.ContentMode.scaleAspectFill
        return view
    }()

    private lazy var senderUsername: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.textAlignment = .center
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return label
    }()

    private lazy var senderContactName: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 12.5)
        return label
    }()

    private lazy var timestamp: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
        label.textColor = UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1)
        return label
    }()

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CancelButtonGray"), for: .normal)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private lazy var acceptButton: UIButton = {
        let button = UIButton()
        button.setTitle("Accept", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
        button.addTarget(self, action: #selector(acceptTap), for: .touchUpInside)
        button.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        button.layer.cornerRadius = 11.5
        return button
    }()
    lazy var acceptedImage = UIImageView(image: UIImage(named: "AddedFriendIcon"))
    lazy var acceptedLabel: UILabel = {
        let label = UILabel()
        label.text = "Accepted"
        label.textColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 15)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpView() {
        profilePic.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTap)))
        contentView.addSubview(profilePic)
        profilePic.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(24)
            $0.height.width.equalTo(self.frame.width / 2)
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.leading).offset(-3)
            $0.bottom.equalTo(profilePic.snp.bottom).offset(3)
            $0.width.equalTo(self.frame.width * 0.12)
            $0.height.equalTo((self.frame.width * 0.12) * 1.7)
        }

        contentView.addSubview(senderContactName)

        senderUsername.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.profileTap)))
        contentView.addSubview(senderUsername)

        contentView.addSubview(timestamp)
        timestamp.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-8)
            $0.top.equalToSuperview().offset(10)
        }

        contentView.addSubview(acceptButton)
        acceptButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(23)
            $0.height.equalTo(37)
            $0.bottom.equalToSuperview().offset(-13)
        }

        contentView.addSubview(acceptedLabel)
        acceptedLabel.isHidden = true
        acceptedLabel.snp.makeConstraints {
            $0.centerY.equalTo(acceptButton)
            $0.centerX.equalToSuperview().offset(10.5)
        }

        contentView.addSubview(acceptedImage)
        acceptedImage.isHidden = true
        acceptedImage.snp.makeConstraints {
            $0.centerY.equalTo(acceptButton)
            $0.trailing.equalTo(acceptedLabel.snp.leading).offset(-4)
        }

        contentView.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalToSuperview()
            $0.width.height.equalTo(32)
        }
    }

    func setValues(notification: UserNotification) {
        self.friendRequest = notification
        guard let userInfo = notification.userInfo else { return }
        self.backgroundColor = UIColor(red: 0.094, green: 0.094, blue: 0.094, alpha: 1)
        self.layer.borderColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1).cgColor
        self.layer.borderWidth = 1
        self.layer.cornerRadius = 14

        let url = userInfo.imageURL
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profilePic.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        let avatarURL = userInfo.avatarURL ?? ""
        if avatarURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: avatarURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

        senderContactName.isHidden = userInfo.contactInfo == nil
        let contactName = userInfo.contactInfo?.fullName ?? ""
        senderContactName.attributedText = (contactName).getAttributedStringWithImage(image: UIImage(named: "NotificationsContactImage") ?? UIImage(), topOffset: -2, addExtraSpace: true)
        senderUsername.text = friendRequest?.userInfo?.username
        timestamp.text = friendRequest?.timestamp.toString(allowDate: false) ?? ""

        setStatus(status: notification.status ?? "")
        makeUsernameConstraints()
    }

    private func makeUsernameConstraints() {
        senderUsername.snp.removeConstraints()
        let topOffset: CGFloat = senderContactName.isHidden ? 17 : 6

        senderUsername.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(profilePic.snp.bottom).offset(topOffset)
            $0.width.lessThanOrEqualToSuperview().inset(16)
        }

        if !senderContactName.isHidden {
            senderContactName.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.top.equalTo(senderUsername.snp.bottom).offset(6)
                $0.width.lessThanOrEqualToSuperview().inset(16)
            }
        }
    }

    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestUserTap")
        collectionDelegate?.getProfile(userProfile: friendRequest?.userInfo ?? UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: ""))
    }

    @objc func cancelTap() {
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestRemoved")
        collectionDelegate?.deleteFriendRequest(sender: self, accepted: accepted)
    }

    @objc func acceptTap() {
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestAccepted")
        accepted = true
        setStatus(status: "accepted")

        guard let friend = friendRequest?.userInfo else { return }
        let notiID = friendRequest?.id ?? ""
        collectionDelegate?.acceptFriend(friend: friend, notiID: notiID)
    }

    private func setStatus(status: String) {
        let pending = status == "pending"
        acceptButton.isHidden = !pending
        acceptedImage.isHidden = pending
        acceptedLabel.isHidden = pending
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profilePic.sd_cancelCurrentImageLoad()
        avatarImage.sd_cancelCurrentImageLoad()
    }

    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }

    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
}
