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

protocol FriendRequestCellDelegate: AnyObject {
    func deleteFriendRequest(sender: AnyObject?, accepted: Bool)
    func getProfile(userProfile: UserProfile)
    func acceptFriend(friend: UserProfile, notiID: String)
}

final class FriendRequestCell: UICollectionViewCell {
    var friendRequest: UserNotification?
    weak var collectionDelegate: FriendRequestCellDelegate?
    var accepted = false

    private lazy var activityIndicator = UIActivityIndicatorView()
    private lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = true
        view.contentMode = UIView.ContentMode.scaleAspectFill
        return view
    }()

    private lazy var senderUsername: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.textAlignment = .center
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 17)
        return label
    }()

    private lazy var senderContactName: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 12.5)
        return label
    }()

    private lazy var timestamp: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 14.5)
        label.textColor = UIColor(red: 0.696, green: 0.696, blue: 0.696, alpha: 1)
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setImage(UIImage(named: "CancelButtonGray"), for: .normal)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private lazy var acceptButton: UIButton = {
        let button = UIButton()
        button.setTitle("Accept", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 15)
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
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 15)
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
        avatarImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTap)))
        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(24)
            $0.width.equalTo(48)
            $0.height.equalTo(54)
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
            $0.leading.trailing.equalToSuperview().inset(21)
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

        let image = userInfo.getAvatarImage()
        if image != UIImage() {
            avatarImage.image = image
        } else if let avatarURL = userInfo.avatarURL, avatarURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
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
        let topOffset: CGFloat = senderContactName.isHidden ? 18 : 12

        senderUsername.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(avatarImage.snp.bottom).offset(topOffset)
            $0.width.lessThanOrEqualToSuperview().inset(16)
        }

        if !senderContactName.isHidden {
            senderContactName.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.top.equalTo(senderUsername.snp.bottom).offset(10)
                $0.width.lessThanOrEqualToSuperview().inset(16)
            }
        }
    }

    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "NotificationsFriendRequestUserTap")
        collectionDelegate?.getProfile(userProfile: friendRequest?.userInfo ?? UserProfile())
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
        avatarImage.sd_cancelCurrentImageLoad()
    }

    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
    }

    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
}
