//
//  ActivityCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//
import Contacts
import Firebase
import FirebaseFirestore
import Mixpanel
import UIKit
import SDWebImage

protocol ContactCellDelegate: AnyObject {
    func contactCellProfileTap(user: UserProfile)
    func addFriend(user: UserProfile)
    func removeSuggestion(user: UserProfile)
}

class ContactCell: UITableViewCell {
    var contact: UserProfile?
    weak var delegate: ContactCellDelegate?

    lazy var status: FriendStatus = .none {
        didSet {
            switch status {
            case .none:
                statusButton.backgroundColor = UIColor(named: "SpotGreen")
                let title = NSMutableAttributedString(string: "Add", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
                statusButton.setAttributedTitle(title, for: .normal)
                statusButton.addTarget(self, action: #selector(addTap), for: .touchUpInside)
                removeButton.isHidden = false
            case .friends:
                statusButton.backgroundColor = .clear
                let title = NSMutableAttributedString(string: "Friends", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor(red: 0.371, green: 0.371, blue: 0.371, alpha: 1)
                ])
                statusButton.setAttributedTitle(title, for: .normal)
                statusButton.removeTarget(self, action: #selector(addTap), for: .touchUpInside)
                removeButton.isHidden = true
            case .pending:
                statusButton.backgroundColor = .clear
                let title = NSMutableAttributedString(string: "Pending", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor(red: 0.371, green: 0.371, blue: 0.371, alpha: 1)
                ])
                statusButton.setAttributedTitle(title, for: .normal)
                statusButton.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
                statusButton.removeTarget(self, action: #selector(addTap), for: .touchUpInside)
                removeButton.isHidden = true
            }
            setStatusConstraints()
        }
    }

    lazy var cellType: CellType = .contact

    private lazy var contactImage: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 56 / 2
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return label
    }()

    private lazy var numberLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Medium", size: 13.5)
        return label
    }()

    private lazy var statusButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2.5, leading: 2.5, bottom: 2.5, trailing: 2.5)
        let button = UIButton(configuration: configuration)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
        button.layer.cornerRadius = 13
        button.layer.masksToBounds = true
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        return button
    }()

    private lazy var removeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2.5, leading: 2.5, bottom: 2.5, trailing: 2.5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "FindFriendsCancelButton"), for: .normal)
        button.addTarget(self, action: #selector(removeSuggestion), for: .touchUpInside)
        return button
    }()

    enum CellType {
        case contact
        case suggested
        case search
        case notifications
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(named: "SpotBlack")
        isUserInteractionEnabled = true
        selectionStyle = .none

        contentView.addSubview(contactImage)
        contactImage.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.height.width.equalTo(56)
            $0.top.equalToSuperview()
        }

        contentView.addSubview(removeButton)
        removeButton.snp.makeConstraints {
            $0.centerY.equalTo(contactImage.snp.centerY)
            $0.trailing.equalTo(-7.5)
            $0.height.width.equalTo(30)
        }

        contentView.addSubview(statusButton)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(numberLabel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(openProfile))
        tap.delegate = self
        contentView.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: setting up views
    func setUp(contact: UserProfile, friendStatus: FriendStatus, cellType: CellType) {
        self.contact = contact
        self.cellType = cellType
        self.status = friendStatus
        contactImage.image = UIImage()

        switch cellType {
        case .contact:
            usernameLabel.text = contact.contactInfo?.fullName ?? ""
            usernameLabel.snp.makeConstraints {
                $0.leading.equalTo(contactImage.snp.trailing).offset(9)
                $0.trailing.lessThanOrEqualTo(statusButton.snp.leading).offset(-8)
                $0.bottom.equalTo(contactImage.snp.centerY).offset(1)
            }

            numberLabel.isHidden = false
            numberLabel.text = contact.contactInfo?.realNumber ?? ""
            numberLabel.snp.makeConstraints {
                $0.leading.trailing.equalTo(usernameLabel)
                $0.top.equalTo(contactImage.snp.centerY).offset(1)
            }

            if let data = contact.contactInfo?.thumbnailData {
                contactImage.image = UIImage(data: data)
            } else {
                contactImage.image = UIImage(named: "BlankContact")?.withRenderingMode(.alwaysTemplate)
                contactImage.tintColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            }
        case .search, .suggested:
            numberLabel.isHidden = true
            usernameLabel.text = contact.username
            usernameLabel.snp.makeConstraints {
                $0.leading.equalTo(contactImage.snp.trailing).offset(9)
                $0.trailing.lessThanOrEqualTo(statusButton.snp.leading).offset(-8)
                $0.centerY.equalTo(contactImage).offset(1)
            }

            let image = contact.getAvatarImage()
            if image != UIImage() {
                contactImage.image = image
            } else if let avatarURL = contact.avatarURL, avatarURL != "" {
                let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFit)
                contactImage.sd_setImage(with: URL(string: avatarURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
            } else {
                contactImage.image = UIImage(named: "Bear")
            }

        case .notifications:
            usernameLabel.text = contact.contactInfo?.fullName ?? ""
            usernameLabel.snp.makeConstraints {
                $0.leading.equalTo(contactImage.snp.trailing).offset(9)
                $0.trailing.lessThanOrEqualTo(statusButton.snp.leading).offset(-8)
                $0.bottom.equalTo(contactImage.snp.centerY).offset(1)
            }

            numberLabel.isHidden = false
            numberLabel.text = "is on sp0t! Add them?"
            numberLabel.snp.makeConstraints {
                $0.leading.trailing.equalTo(usernameLabel)
                $0.top.equalTo(contactImage.snp.centerY).offset(1)
            }

            if let data = contact.contactInfo?.thumbnailData {
                contactImage.image = UIImage(data: data)
            } else {
                contactImage.image = UIImage(named: "BlankContact")?.withRenderingMode(.alwaysTemplate)
                contactImage.tintColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            }
        }
        updateImageConstraints()
    }

    private func setStatusConstraints() {
        statusButton.snp.removeConstraints()
        statusButton.snp.makeConstraints {
            $0.centerY.equalTo(contactImage.snp.centerY)
            $0.height.equalTo(35)
            if status == .none && cellType != .search {
                $0.trailing.equalTo(removeButton.snp.leading).offset(-9)
                $0.width.equalTo(54)
            } else {
                $0.trailing.equalTo(-10)
                $0.width.equalTo(106)
            }
        }
    }

    private func updateImageConstraints() {
        switch cellType {
        case .search, .suggested:
            contactImage.snp.updateConstraints {
                $0.height.equalTo(54)
                $0.width.equalTo(48)
            }
        case .contact:
            contactImage.snp.updateConstraints {
                $0.height.width.equalTo(56)
            }
        case .notifications:
            // update values for use in notification cell
            contactImage.snp.updateConstraints {
                $0.top.equalTo(14)
                $0.height.width.equalTo(38)
            }
            contactImage.layer.cornerRadius = 38 / 2
            numberLabel.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
            numberLabel.font = UIFont(name: "SFCompactText-Regular", size: 14.5)
        }
    }

    @objc func addTap() {
        guard let contact else { return }
        Mixpanel.mainInstance().track(event: "ContactCellAddFriend")
        delegate?.addFriend(user: contact)
    }

    @objc func removeSuggestion() {
        guard let contact else { return }
        Mixpanel.mainInstance().track(event: "ContactCellHideUser")
        delegate?.removeSuggestion(user: contact)
    }

    @objc func openProfile() {
        guard cellType != .contact, let contact else { return }
        Mixpanel.mainInstance().track(event: "ContactCellProfileTap")
        delegate?.contactCellProfileTap(user: contact)
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // ignore touch area around action button + bottom touch area was being expanded off cell
        return touch.location(in: self).x < UIScreen.main.bounds.width - 90 && touch.location(in: self).y < 60
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contactImage.sd_cancelCurrentImageLoad()
        usernameLabel.snp.removeConstraints()
        numberLabel.snp.removeConstraints()
    }
}
