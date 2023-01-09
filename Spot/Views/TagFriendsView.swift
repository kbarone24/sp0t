//
//  TagFriendsView.swift
//  Spot
//
//  Created by Kenny Barone on 7/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import UIKit
import SDWebImage

protocol TagFriendsDelegate {
    func finishPassing(selectedUser: UserProfile)
}

final class TagFriendsView: UIView {
    var collectionView: UICollectionView!
    lazy var queryUsers: [UserProfile] = []
    var delegate: TagFriendsDelegate?
    var searchText: String = "" {
        didSet {
            runQuery()
        }
    }
    var textColor: UIColor = .white

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil

        let layout = UICollectionViewFlowLayout {
            $0.itemSize = CGSize(width: 80, height: 80)
            $0.minimumInteritemSpacing = 6
            $0.scrollDirection = .horizontal
        }
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = nil
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(TagFriendCell.self, forCellWithReuseIdentifier: "TagFriendCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        collectionView.delegate = self
        collectionView.dataSource = self
        addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func runQuery() {
        queryUsers.removeAll()

        var adjustedFriends = UserDataModel.shared.userInfo.friendsList
        adjustedFriends.removeAll(where: { $0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" }) /// remove bot
        let usernameList = adjustedFriends.map({ $0.username })
        let nameList = adjustedFriends.map({ $0.name })

        let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: .caseInsensitive) != nil
        })

        let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
            return dataString.range(of: searchText, options: .caseInsensitive) != nil
        })

        for username in filteredUsernames {
            if let friend = adjustedFriends.first(where: { $0.username == username }) { self.queryUsers.append(friend) }
        }

        for name in filteredNames {
            if let friend = adjustedFriends.first(where: { $0.name == name }) {
                /// chance that 2 people with same name won't show up in search rn
                if !self.queryUsers.contains(where: { $0.id == friend.id }) { self.queryUsers.append(friend) }
            }
        }
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }
}

extension TagFriendsView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagFriendCell", for: indexPath) as? TagFriendCell {
            cell.setUp(user: queryUsers[indexPath.row])
            cell.textColor = textColor
            return cell
        }
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return queryUsers.count
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedUser = queryUsers[indexPath.row]
        delegate?.finishPassing(selectedUser: selectedUser)
    }
}

final class TagFriendCell: UICollectionViewCell {
    var username: UILabel!
    
    private lazy var profileImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = .gray
        imageView.layer.cornerRadius = 62 / 2
        return imageView
    }()
    
    private lazy var avatarImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    var textColor: UIColor = .black {
        didSet {
            username.textColor = textColor
        }
    }

    func setUp(user: UserProfile) {
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: user.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        avatarImage.sd_setImage(with: URL(string: user.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])

        username.text = user.username
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil

        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.height.width.equalTo(62)
            $0.centerX.equalToSuperview()
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-10)
            $0.bottom.equalTo(profileImage).inset(-2)
            $0.height.equalTo(37.5)
            $0.width.equalTo(26)
        }

        username = UILabel {
            $0.textColor = textColor
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.textAlignment = .center
            $0.lineBreakMode = .byTruncatingTail
            contentView.addSubview($0)
        }
        username.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(profileImage.snp.bottom).offset(6)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
