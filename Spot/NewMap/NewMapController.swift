//
//  NewMapController.swift
//  Spot
//
//  Created by Kenny Barone on 6/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import IQKeyboardManagerSwift
import Mixpanel
import UIKit

protocol NewMapDelegate: AnyObject {
    func finishPassing(map: CustomMap)
    func toggle(cancel: Bool)
}

class NewMapController: UIViewController {
    let uid: String = UserDataModel.shared.uid
    var mapObject: CustomMap?
    var delegate: NewMapDelegate?

    lazy var nameField: UITextField = {
        let view = UITextField()
        view.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        view.attributedPlaceholder = NSAttributedString(string: "Name map...", attributes: [NSAttributedString.Key.foregroundColor: UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 0.6)])
        view.font = UIFont(name: "SFCompactText-Heavy", size: 22)
        view.textAlignment = .center
        view.tintColor = UIColor(named: "SpotGreen")
        view.autocapitalizationType = .sentences
        view.spellCheckingType = .no
        view.delegate = self
        return view
    }()
    private lazy var collaboratorLabel: UILabel = {
        let label = UILabel()
        label.text = "Add sp0tters"
        label.textColor = UIColor(red: 0.521, green: 0.521, blue: 0.521, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()
    lazy var collaboratorsCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 18
        layout.itemSize = CGSize(width: 62, height: 85)
        layout.sectionInset = UIEdgeInsets(top: 0, left: margin, bottom: 0, right: margin)

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = nil
        view.delegate = self
        view.dataSource = self
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 100)
        view.register(MapMemberCell.self, forCellWithReuseIdentifier: "MapMemberCell")
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        return view
    }()

    private lazy var mapTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "Map type"
        label.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()
    lazy var mapPrivacySlider = MapPrivacySlider()
    lazy var mapPrivacyView = MapPrivacyView()

    var nextButton: UIButton?
    var createButton: UIButton?

    lazy var keyboardPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(keyboardPan(_:)))
        pan.isEnabled = false
        return pan
    }()
    var readyToDismiss = true
    var presentedModally = false

    let margin: CGFloat = 18
    var actionButton: UIButton {
        return presentedModally ? nextButton ?? UIButton() : createButton ?? UIButton()
    }

    init(mapObject: CustomMap?) {
        super.init(nibName: nil, bundle: nil)
        if mapObject == nil {
            addMapObject()
        } else {
            self.mapObject = mapObject
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        presentationController?.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if presentedModally { setUpNavBar() }
        enableKeyboardMethods()
        delegate?.toggle(cancel: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameField.becomeFirstResponder()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.toggle(cancel: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disableKeyboardMethods()
    }

    func addMapObject() {
        guard let post = UploadPostModel.shared.postObject else { return }
        // most values will be set in updatePostLevelValues
        mapObject = CustomMap(
            id: UUID().uuidString,
            founderID: uid,
            imageURL: "",
            likers: [uid],
            mapName: "",
            memberIDs: [uid],
            posterDictionary: [:],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            postLocations: [],
            postTimestamps: [],
            secret: false,
            spotIDs: [],
            memberProfiles: [UserDataModel.shared.userInfo],
            coverImage: UIImage()
        )
        if !(post.addedUsers?.isEmpty ?? true) {
            mapObject?.memberIDs.append(contentsOf: post.addedUsers ?? [])
            mapObject?.likers.append(contentsOf: post.addedUsers ?? [])
            mapObject?.memberProfiles?.append(contentsOf: post.addedUserProfiles ?? [])
        }
    }

    func setUpView() {
        view.backgroundColor = UIColor(named: "SpotBlack")

        nameField.delegate = self
        nameField.text = mapObject?.mapName ?? ""
        view.addSubview(nameField)
        let screenSizeOffset: CGFloat = UserDataModel.shared.screenSize == 2 ? 20 : 0
        let topOffset: CGFloat = presentedModally ? 15 + screenSizeOffset : 30 + screenSizeOffset
        nameField.snp.makeConstraints {
            $0.top.equalTo(topOffset)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.height.equalTo(50)
        }

        view.addSubview(collaboratorLabel)
        collaboratorLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(nameField.snp.bottom).offset(31)
            $0.height.equalTo(18)
        }

        collaboratorsCollection.delegate = self
        collaboratorsCollection.dataSource = self
        view.addSubview(collaboratorsCollection)
        collaboratorsCollection.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(collaboratorLabel.snp.bottom).offset(8)
            $0.height.equalTo(90)
        }

        view.addSubview(mapTypeLabel)
        mapTypeLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(collaboratorsCollection.snp.bottomMargin).offset(20)
            $0.height.equalTo(18)
        }

        mapPrivacySlider.delegate = self
        view.addSubview(mapPrivacySlider)
        mapPrivacySlider.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(mapTypeLabel.snp.bottom).offset(8)
            $0.height.equalTo(28)
        }

        view.addSubview(mapPrivacyView)
        mapPrivacyView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(mapPrivacySlider.snp.bottom).offset(12)
            $0.height.equalTo(40)
        }

        if presentedModally {
            nextButton = NextButton()
            nextButton?.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
            nextButton?.isEnabled = false
            view.addSubview(nextButton ?? UIButton())

            nextButton?.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-100)
                $0.leading.trailing.equalToSuperview().inset(margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }

        } else {
            createButton = CreateMapButton()
            createButton?.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
            createButton?.isEnabled = false
            view.addSubview(createButton ?? UIButton())

            createButton?.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-100)
                $0.leading.trailing.equalToSuperview().inset(margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }
        }
        view.addGestureRecognizer(keyboardPan)

        // private: 0, public: 1, community: 2
        let tag = (mapObject?.secret ?? false) ? 0 : (mapObject?.communityMap ?? false) ? 2 : 1
        togglePrivacy(tag: tag)
    }

    func setUpNavBar() {
        title = "Create a map"
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.addWhiteBackground()

        let barButtonItem = UIBarButtonItem(image: UIImage(named: "BackArrowDark"), style: .plain, target: self, action: #selector(backTapped))
        navigationItem.leftBarButtonItem = barButtonItem

        if let mapNav = navigationController as? MapNavigationController {
            mapNav.requiredStatusBarStyle = .darkContent
        }
    }
}
