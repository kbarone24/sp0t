//
//  FriendRequestCollectionCell.swift
//  Spot
//
//  Created by Shay Gyawali on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth
import Mixpanel
import UIKit

protocol AvatarSelectionDelegate: AnyObject {
    func finishPassing(avatar: AvatarProfile)
}

class AvatarSelectionController: UIViewController {
    enum SentFrom {
        case create
        case edit
        case spotscore
        case avatar
    }

    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    private lazy var avatars: [AvatarProfile] = []
    private lazy var friendRequests: [UserNotification] = []
    private lazy var sentFrom: SentFrom = .create

    private let initialRow = 0
    private let itemSize = CGSize(width: 71, height: 79.62)
    private lazy var selectedAvatar = AvatarProfile(family: .Bear, item: nil)

    weak var delegate: AvatarSelectionDelegate?

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "LandingPageBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = AvatarFlowLayout()
        layout.itemSize = itemSize
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = true
        collectionView.allowsSelection = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(AvatarCell.self, forCellWithReuseIdentifier: "AvatarCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        collectionView.translatesAutoresizingMaskIntoConstraints = true
        return collectionView
    }()

    private lazy var titleLabel: UILabel = {
        //TODO: replace with real font (UniversCE-Medium)
        let label = UILabel()
        label.font = UIFont(name: "UniversCE-Black", size: 22)
        label.textColor = UIColor(red: 0.054, green: 0.054, blue: 0.054, alpha: 1)
        view.addSubview(label)
        return label
    }()

    private lazy var actionButton = SignUpPillButton(text: "")

    private lazy var doneButton: SignUpPillButton = {
        let button = SignUpPillButton(text: "Done")
        button.addTarget(self, action: #selector(doneTap), for: .touchUpInside)
        return button
    }()

    init(sentFrom: SentFrom, family: AvatarFamily?) {
        super.init(nibName: nil, bundle: nil)
        self.sentFrom = sentFrom
        if sentFrom == .avatar, let family {
            // move base avatar to center
            avatars = AvatarGenerator.shared.getStylizedAvatars(family: family)

        } else {
            avatars = AvatarGenerator.shared.getBaseAvatars()
            // passed through avatar already tapped (from spotscore)
            if let family {
                avatars.sort(by: {
                    ($0.family == family) && ($1.family != family)
                })

            } else if sentFrom == .edit {
                // move user's current avatar to center, sort by unlock score after
                if let familyString = UserDataModel.shared.userInfo.avatarFamily, familyString != "" {
                    let avatarFamily = AvatarFamily(rawValue: familyString)
                    avatars.sort(by: {
                        ($0.family == avatarFamily) && ($1.family != avatarFamily)
                    })
                }
            }
        }
        selectedAvatar = avatars[initialRow]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("avatar deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUp()
        DispatchQueue.main.async {
            self.scrollToInitialRow()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "AvatarSelectionAppeared")

        let layoutMargins: CGFloat = self.collectionView.layoutMargins.left + self.collectionView.layoutMargins.left
        let sideInset = (self.view.frame.width / 2) - layoutMargins
        self.collectionView.contentInset = UIEdgeInsets(top: 0, left: sideInset, bottom: 0, right: sideInset)
    }

    private func setUpNavBar() {
        navigationItem.hidesBackButton = sentFrom == .create
        navigationController?.navigationBar.tintColor = .black
    }

    func setUp() {
        // hardcode cell height in case its laid out before view fully appears
        // hard code body height so mask stays with cell change
        view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(titleLabel)
        titleLabel.text = sentFrom == .avatar ? "Choose your style" : "Choose your avatar"
        titleLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview().offset(-130)
            $0.centerX.equalToSuperview()
        }

        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(24)
            $0.width.equalToSuperview()
            $0.height.equalTo(95)
        }

        if sentFrom == .avatar {
            actionButton = SignUpPillButton(text: "Done")
            actionButton.addTarget(self, action: #selector(doneTap), for: .touchUpInside)
        } else {
            actionButton = SignUpPillButton(text: "Next")
            actionButton.addTarget(self, action: #selector(nextTap), for: .touchUpInside)
        }
        view.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(51)
            $0.top.equalTo(collectionView.snp.bottom).offset(70)
        }
    }

    private func scrollToInitialRow() {
        let itemWidth = itemSize.width
        let centerPoint = (UIScreen.main.bounds.width / 2) - itemWidth / 2
        DispatchQueue.main.async {
            self.collectionView.setContentOffset(CGPoint(x: -centerPoint, y: 0), animated: false)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView is UICollectionView else {
            return }
        // finding cell at the center
        DispatchQueue.main.async { [self] in
            let center = self.view.convert(self.collectionView.center, to: self.collectionView)
            if let indexPath = self.collectionView.indexPathForItem(at: center) {
                if self.selectedAvatar != self.avatars[indexPath.row] {
                    Mixpanel.mainInstance().track(event: "AvatarSelectionScrollNewAvatar")
                    self.selectedAvatar = self.avatars[indexPath.row]
                    DispatchQueue.main.async { self.collectionView.reloadData() }
                    HapticGenerator.shared.play(.rigid)
                }
            }
        }
    }

    @objc func nextTap() {
        let vc = AvatarSelectionController(sentFrom: .avatar, family: selectedAvatar.family)
        vc.delegate = delegate
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func doneTap() {
        Mixpanel.mainInstance().track(event: "AvatarSelectionSelectTap")
        let db = Firestore.firestore()
        let avatarURL = selectedAvatar.getURL()
        db.collection("users").document(uid).updateData(["avatarURL": avatarURL])
        db.collection("users").document(uid).updateData(["avatarFamily" : selectedAvatar.family.rawValue])
        db.collection("users").document(uid).updateData(["avatarItem" : selectedAvatar.item?.rawValue ?? ""])

        UserDataModel.shared.userInfo.avatarURL = avatarURL
        UserDataModel.shared.userInfo.avatarFamily = selectedAvatar.family.rawValue
        UserDataModel.shared.userInfo.avatarItem = selectedAvatar.item?.rawValue ?? ""
        UserDataModel.shared.userInfo.avatarPic = UIImage(named: selectedAvatar.avatarName) ?? UIImage()

        if delegate == nil {
            let vc = SearchContactsController()
            self.navigationController?.pushViewController(vc, animated: true)

        } else {
            delegate?.finishPassing(avatar: selectedAvatar)
            DispatchQueue.main.async {
                self.navigationController?.popToRootViewController(animated: false)
            }
        }
    }
}

// MARK: delegate and data source protocol
extension AvatarSelectionController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return avatars.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AvatarCell", for: indexPath) as? AvatarCell else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }
        cell.setUp(avatar: avatars[indexPath.row], selected: avatars[indexPath.row] == selectedAvatar)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Mixpanel.mainInstance().track(event: "AvatarSelectionTapNewAvatar")
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
    }
}
