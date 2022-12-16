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
import FirebaseUI
import Foundation
import Mixpanel
import UIKit

class ContactCell: UITableViewCell {
    var contact: UserProfile?
    lazy var status: FriendStatus = .none {
        didSet {
            switch status {
            case .none:
                statusButton.backgroundColor = UIColor(named: "SpotGreen")
                statusButton.setTitle("Add", for: .normal)
                statusButton.addTarget(self, action: #selector(addTap), for: .touchUpInside)
                removeButton.isHidden = false
            case .friends:
                statusButton.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
                statusButton.setTitle("Friends", for: .normal)
                statusButton.removeTarget(self, action: #selector(addTap), for: .touchUpInside)
                removeButton.isHidden = true
            case .pending:
                statusButton.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
                statusButton.setTitle("Pending", for: .normal)
                statusButton.removeTarget(self, action: #selector(addTap), for: .touchUpInside)
                removeButton.isHidden = true
            }
            setStatusConstraints()
        }
    }
    
    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()

    lazy var cellType: CellType = .contact

    private lazy var profileImage: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 56 / 2
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    private lazy var avatarImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.isHidden = false
        return imageView
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return label
    }()

    private lazy var statusButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
        button.layer.cornerRadius = 17
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        return button
    }()

    private lazy var removeButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "FindFriendsCancelButton"), for: .normal)
        button.addTarget(self, action: #selector(removeSuggestion), for: .touchUpInside)
        button.imageEdgeInsets = UIEdgeInsets(top: 2.5, left: 2.5, bottom: 2.5, right: 2.5)
        return button
    }()

    enum CellType {
        case contact
        case suggested
        case search
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        isUserInteractionEnabled = true

        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.height.width.equalTo(56)
            $0.top.equalToSuperview()
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-12)
            $0.bottom.equalTo(profileImage).inset(-2)
            $0.height.equalTo(33.9)
            $0.width.equalTo(33)
        }

        contentView.addSubview(removeButton)
        removeButton.snp.makeConstraints {
            $0.centerY.equalTo(profileImage.snp.centerY)
            $0.trailing.equalTo(-7.5)
            $0.height.width.equalTo(30)
        }

        contentView.addSubview(statusButton)

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(9)
            $0.trailing.lessThanOrEqualTo(statusButton.snp.leading).offset(-8)
            $0.centerY.equalTo(profileImage)
        }

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

        usernameLabel.text = contact.username

        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: contact.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        avatarImage.image = UIImage()
        if let avatarURL = contact.avatarURL, avatarURL != "" {
            let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: avatarURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
        }
    }

    func setStatusConstraints() {
        statusButton.snp.removeConstraints()
        statusButton.snp.makeConstraints {
            $0.centerY.equalTo(profileImage.snp.centerY)
            $0.height.equalTo(35)
            if status == .none && cellType != .search {
                $0.trailing.equalTo(removeButton.snp.leading).offset(-11)
                $0.width.equalTo(62)
            } else {
                $0.trailing.equalTo(-10)
                $0.width.equalTo(106)
            }
        }
    }

    @objc func addTap() {
        guard let receiverID = contact?.id else { return }
        Mixpanel.mainInstance().track(event: "ContactCellAddFriend")
        NotificationCenter.default.post(name: NSNotification.Name("ContactCellAddFriend"), object: nil, userInfo: ["receiverID": receiverID])

        friendService?.addFriend(receiverID: receiverID, completion: nil)
    }

    @objc func removeSuggestion() {
        guard let receiverID = contact?.id else { return }
        Mixpanel.mainInstance().track(event: "ContactCellHideUser")
        NotificationCenter.default.post(name: NSNotification.Name("ContactCellHideUser"), object: nil, userInfo: ["receiverID": receiverID])

        let db = Firestore.firestore()
        db.collection("users").document(UserDataModel.shared.uid).updateData(["hiddenUsers": FieldValue.arrayUnion([receiverID])])
    }

    @objc func openProfile() {
        print("open profile")
        if let vc = viewContainingController() as? FindFriendsController, let contact {
            vc.openProfile(user: contact)
        }
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // ignore touch area around action button + bottom touch area was being expanded off cell
        return touch.location(in: self).x < UIScreen.main.bounds.width - 90 && touch.location(in: self).y < 60
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImage.sd_cancelCurrentImageLoad()
        avatarImage.sd_cancelCurrentImageLoad()
    }
}
