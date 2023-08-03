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
    enum TagParent {
        case Comments
        case ImagePreview
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 72, height: 90)
        layout.minimumInteritemSpacing = 6
        layout.scrollDirection = .horizontal

        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = nil
        collection.showsHorizontalScrollIndicator = false
        collection.register(TagFriendCell.self, forCellWithReuseIdentifier: TagFriendCell.reuseID)
        collection.register(TagFriendsLoadingCell.self, forCellWithReuseIdentifier: TagFriendsLoadingCell.reuseID)
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        collection.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        return collection
    }()
    private var userList: [UserProfile] = []
    private lazy var queryUsers: [UserProfile] = []
    private var delegate: TagFriendsDelegate?
    private var allowSearch = true
    var tagParent: TagParent = .Comments
    private var searchText: String = "" {
        didSet {
            runQuery()
        }
    }
    private var textColor: UIColor = .white
    private var refreshStatus: RefreshStatus = .refreshEnabled

    private var maskLayer: CAGradientLayer?

    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        collectionView.delegate = self
        collectionView.dataSource = self
        addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.width.bottom.equalToSuperview()
            $0.height.equalTo(90)
        }
    }

    override func layoutSubviews() {
        if tagParent == .Comments {
            if maskLayer == nil {
                maskLayer = CAGradientLayer()
                maskLayer?.frame = bounds
                maskLayer?.colors = [
                    UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 0.0).cgColor,
                    UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 0.85).cgColor,
                    UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
                ]
                maskLayer?.locations = [0, 0.25, 1]
                maskLayer?.startPoint = CGPoint(x: 0.5, y: 0)
                maskLayer?.endPoint = CGPoint(x: 0.5, y: 1.0)
                layer.insertSublayer(maskLayer ?? CALayer(), at: 0)
            } else {
                maskLayer?.frame = bounds
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setUp(userList: [UserProfile], textColor: UIColor, backgroundColor: UIColor? = nil, delegate: TagFriendsDelegate, allowSearch: Bool, tagParent: TagParent, searchText: String) {
        self.userList = userList
        self.textColor = textColor
        self.delegate = delegate
        self.allowSearch = allowSearch
        self.tagParent = tagParent
        self.searchText = searchText

        if let backgroundColor {
            collectionView.backgroundColor = backgroundColor
        }
    }

    func runQuery() {
        queryUsers.removeAll()

        let adjustedFriends = userList
        let usernameList = adjustedFriends.map({ $0.username })
        let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: .caseInsensitive) != nil
        })

        for username in filteredUsernames {
            if let friend = adjustedFriends.first(where: { $0.username == username }) { self.queryUsers.append(friend) }
        }

        queryUsers.removeDuplicates()

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.queryAllUsers), object: nil)
        if searchText.count > 1, allowSearch {
            refreshStatus = .activelyRefreshing
            perform(#selector(self.queryAllUsers), with: nil, afterDelay: 0.65)
        }
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    @objc func queryAllUsers() {
        Task {
            let users = try? await self.userService?.getUsersFrom(searchText: searchText, limit: 8)
            for user in users ?? [] {
                if self.shouldAppendUser(id: user.id ?? "", searchText: searchText) {
                    self.queryUsers.append(user)
                }
            }
            self.reloadCollection()
        }
    }

    private func shouldAppendUser(id: String, searchText: String) -> Bool {
        return queryValid(searchText: searchText) && !self.queryUsers.contains(where: { $0.id == id }) && id != UserDataModel.shared.uid
    }

    private func queryValid(searchText: String) -> Bool {
        return searchText == self.searchText && searchText != ""
    }

    private func reloadCollection() {
        queryUsers.removeDuplicates()
        refreshStatus = .refreshEnabled
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
}

extension TagFriendsView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row < queryUsers.count, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TagFriendCell.reuseID, for: indexPath) as? TagFriendCell {
            cell.setUp(user: queryUsers[indexPath.row])
            cell.textColor = textColor
            return cell
        } else if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TagFriendsLoadingCell.reuseID, for: indexPath) as? TagFriendsLoadingCell {
            cell.activityIndicator.startAnimating()
            return cell
        }

        return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return refreshStatus == .activelyRefreshing ? queryUsers.count + 1 : queryUsers.count
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedUser = queryUsers[indexPath.row]
        delegate?.finishPassing(selectedUser: selectedUser)
    }
}

