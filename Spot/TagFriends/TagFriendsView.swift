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

protocol TagFriendsDelegate: AnyObject {
    func finishPassing(selectedUser: UserProfile)
}

final class TagFriendsView: UIView {
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 72, height: 90)
        layout.minimumInteritemSpacing = 6
        layout.scrollDirection = .horizontal

        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = nil
        collection.showsHorizontalScrollIndicator = false
        collection.register(TagFriendCell.self, forCellWithReuseIdentifier: "TagFriendCell")
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        collection.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        return collection
    }()
    private var userList: [UserProfile] = []
    private lazy var queryUsers: [UserProfile] = []
    private var delegate: TagFriendsDelegate?
    private var searchText: String = "" {
        didSet {
            runQuery()
        }
    }
    private var textColor: UIColor = .white

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil

        collectionView.delegate = self
        collectionView.dataSource = self
        addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setUp(userList: [UserProfile], textColor: UIColor, delegate: TagFriendsDelegate, searchText: String) {
        self.userList = userList
        self.textColor = textColor
        self.delegate = delegate
        self.searchText = searchText
    }

    func runQuery() {
        queryUsers.removeAll()

        var adjustedFriends = userList
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
    private lazy var username: UILabel = {
        let label = UILabel()
        label.textColor = textColor
        label.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        label.textAlignment = .center
        label.lineBreakMode = .byCharWrapping
        label.clipsToBounds = true
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private lazy var avatarImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        return imageView
    }()

    var textColor: UIColor = .black {
        didSet {
            username.textColor = textColor
        }
    }

    func setUp(user: UserProfile) {
        let image = user.getAvatarImage()
        if image != UIImage() {
            avatarImage.image = image
        } else {
            let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: user.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
        }

        username.text = user.username
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
            $0.height.equalTo(54)
            $0.width.equalTo(48)
        }

        contentView.addSubview(username)
        username.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(avatarImage.snp.bottom).offset(6)
         //   $0.bottom.lessThanOrEqualToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
