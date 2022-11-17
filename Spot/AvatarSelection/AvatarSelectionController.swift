//
//  FriendRequestCollectionCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import Mixpanel
import UIKit

class AvatarSelectionController: UIViewController {
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    private lazy var avatars: [String] = ["Bear", "Bunny", "Cow", "Deer", "Dog", "Elephant", "Giraffe", "Lion", "Monkey", "Panda", "Pig", "Tiger"].shuffled()
    private lazy var friendRequests: [UserNotification] = []

    private var centerCell: AvatarCell?
    private lazy var centerAvi = CGPoint(x: 0.0, y: 0.0)
    private lazy var sentFrom: SentFrom = .map
    var onDoneBlock: ((String, String) -> Void)?

    private let myCollectionViewFlowLayout = MyCollectionViewFlowLayout()
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 189), collectionViewLayout: UICollectionViewLayout())
        collectionView.backgroundColor = .white
        collectionView.isScrollEnabled = true
        collectionView.allowsSelection = true
        collectionView.collectionViewLayout = self.myCollectionViewFlowLayout
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(AvatarCell.self, forCellWithReuseIdentifier: "AvatarCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        collectionView.translatesAutoresizingMaskIntoConstraints = true
        return collectionView
    }()

    enum SentFrom {
        case create
        case map
        case edit
    }

    init(sentFrom: SentFrom) {
        super.init(nibName: nil, bundle: nil)
        self.sentFrom = sentFrom
        if sentFrom == .edit {
            navigationItem.hidesBackButton = false
            for i in 0..<(avatars.count) {
                let userAvatarURL = UserDataModel.shared.userInfo.avatarURL ?? ""
                let url = AvatarURLs.shared.getURL(name: avatars[i])
                if userAvatarURL == url {
                    avatars.swapAt(i, 5)
                }
            }
        } else {
            navigationItem.hidesBackButton = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUp()
        DispatchQueue.main.async { self.collectionView.scrollToItem(at: IndexPath(item: 5, section: 0), at: .centeredHorizontally, animated: false) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "AvatarSelectionAppeared")
        DispatchQueue.main.async {
            if self.centerCell != (self.collectionView.cellForItem(at: IndexPath(item: 5, section: 0)) as? AvatarCell) {
                if let cell = self.collectionView.cellForItem(at: IndexPath(item: 5, section: 0)) as? AvatarCell {
                    self.centerCell = cell
                    self.centerCell?.transformToLarge()
                }
            }
        }

        let layoutMargins: CGFloat = self.collectionView.layoutMargins.left + self.collectionView.layoutMargins.left
        let sideInset = (self.view.frame.width / 2) - layoutMargins
        self.collectionView.contentInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
    }

    func setUpFriendRequests(friendRequests: [UserNotification]) {
        self.friendRequests = friendRequests
    }

    func setUp() {
        // hardcode cell height in case its laid out before view fully appears
        // hard code body height so mask stays with cell change
        resetCell()

        let title = UILabel {
            $0.text = "Choose your avatar"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 18)
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            view.addSubview($0)
        }
        title.snp.makeConstraints {
            $0.top.equalToSuperview().offset(138)
            $0.centerX.equalToSuperview()
        }

        let subTitle = UILabel {
            $0.text = "This is how you'll be displayed on the map"
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.addSubview($0)
        }
        subTitle.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(9.05)
            $0.centerX.equalToSuperview()
        }

        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.top.equalTo(subTitle.snp.bottom).offset(16)
            $0.width.equalToSuperview()
            $0.height.equalTo(95)
        }

        let selectButton = UIButton {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            var customButtonTitle = NSMutableAttributedString()
            if sentFrom == .create {
                customButtonTitle = NSMutableAttributedString(string: "Create account", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
            } else {
                customButtonTitle = NSMutableAttributedString(string: "Select", attributes: [
                    NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ])
            }
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.setImage(nil, for: .normal)
            $0.addTarget(self, action: #selector(selectedTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        selectButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(78)
            $0.height.equalTo(52)
            $0.top.equalTo(collectionView.snp.bottom).offset(50)
        }

        if sentFrom == .edit {
            let backButton = UIButton {
                $0.setTitle("Cancel", for: .normal)
                $0.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
                $0.titleLabel?.font = UIFont(name: "SFCompactText-Medium", size: 14)
                $0.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
                view.addSubview($0)
            }
            backButton.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(22)
                $0.top.equalToSuperview().offset(60)
            }
        }
    }

    @objc func dismissAction(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "AvatarSelectionDismiss")
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }

    func resetCell() {
        collectionView.removeFromSuperview()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.collectionView.layoutSubviews()
        }

        guard scrollView is UICollectionView else {
            return }
        // finding cell at the center
        DispatchQueue.main.async { [self] in
            let center = self.view.convert(self.collectionView.center, to: self.collectionView)
            if let indexPath = self.collectionView.indexPathForItem(at: center) {
                Mixpanel.mainInstance().track(event: "AvatarSelectionScrollNewAvatar")
                if let cell = self.collectionView.cellForItem(at: indexPath) as? AvatarCell {
                    self.centerCell = cell
                    self.centerCell?.transformToLarge()
                }
            }
        }
    }

    func transformToStandard() {
        centerCell?.transformToStandard()
    }

    @objc func selectedTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "AvatarSelectionSelectTap")
        let avatarURL = AvatarURLs.shared.getURL(name: centerCell?.avatar ?? "")
        if sentFrom != .edit {
            UserDataModel.shared.userInfo.avatarURL = avatarURL
            UserDataModel.shared.userInfo.avatarPic = UIImage(named: centerCell?.avatar ?? "") ?? UIImage()
            let db = Firestore.firestore()
            db.collection("users").document(uid).updateData(["avatarURL": avatarURL])
        }

       /* if sentFrom == .map {
            self.navigationController?.popViewController(animated: true)

        } else */ if sentFrom == .map || sentFrom == .create {
            let vc = SearchContactsOverviewController()
            self.navigationController?.pushViewController(vc, animated: true)

        } else {
            onDoneBlock?(avatarURL, centerCell?.avatar ?? "")
            self.presentingViewController?.dismiss(animated: false, completion: nil)
        }
    }
}

// MARK: delegate and data source protocol
extension AvatarSelectionController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 12
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AvatarCell", for: indexPath) as? AvatarCell else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }
        cell.setUp(avatar: avatars[indexPath.row])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Mixpanel.mainInstance().track(event: "AvatarSelectionTapNewAvatar")
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .left)
    }
}

final class MyCollectionViewFlowLayout: UICollectionViewFlowLayout {
    override func prepare() {
        super.prepare()
        scrollDirection = .horizontal
        minimumInteritemSpacing = 15
        itemSize = CGSize(width: 64, height: 91.4)
        // sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        // snap to center
        var offsetAdjustment = CGFloat.greatestFiniteMagnitude
        let horizontalOffset = proposedContentOffset.x + (collectionView?.contentInset.left ?? 0)
        let targetRect = CGRect(x: proposedContentOffset.x, y: 0, width: (collectionView?.bounds.size.width ?? 0), height: (collectionView?.bounds.size.height ?? 0))
        let layoutAttributesArray = super.layoutAttributesForElements(in: targetRect)
        layoutAttributesArray?.forEach({ (layoutAttributes) in
            let itemOffset = layoutAttributes.frame.origin.x
            if fabsf(Float(itemOffset - horizontalOffset)) < fabsf(Float(offsetAdjustment)) {
                offsetAdjustment = itemOffset - horizontalOffset
            }
        })
        return CGPoint(x: proposedContentOffset.x + offsetAdjustment + 10, y: proposedContentOffset.y)
    }
}
