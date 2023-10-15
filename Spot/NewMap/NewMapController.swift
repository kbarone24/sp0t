//
//  CreateMapController.swift
//  Spot
//
//  Created by Kenny Barone on 10/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import Mixpanel
import UIKit

protocol NewMapDelegate: AnyObject {
    func finishPassing(map: CustomMap)
}

class NewMapController: UIViewController {
    let uid: String = UserDataModel.shared.uid
    var mapObject: CustomMap?
    var delegate: NewMapDelegate?

    lazy var nameField: UITextField = {
        let view = UITextField()
        view.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        view.attributedPlaceholder = NSAttributedString(string: "Name map...", attributes: [NSAttributedString.Key.foregroundColor: UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 0.6)])
        view.font = SpotFonts.SFCompactRoundedHeavy.fontWith(size: 22)
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
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 14)
        return label
    }()
    lazy var collaboratorsCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 18
        layout.itemSize = CGSize(width: 62, height: 84)
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
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 14)
        return label
    }()
    lazy var mapPrivacySlider = MapPrivacySlider()
    lazy var mapPrivacyView = MapPrivacyView()

    var createButton: UIButton?

    lazy var keyboardPan: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(keyboardPan(_:)))
        pan.isEnabled = false
        return pan
    }()
    var readyToDismiss = true
    var passedMap = false

    let margin: CGFloat = 18
    var actionButton: UIButton {
        return createButton ?? UIButton()
    }

    init(mapObject: CustomMap?, delegate: NewMapDelegate?) {
        super.init(nibName: nil, bundle: nil)
        if mapObject == nil {
            addMapObject()
        } else {
            self.mapObject = mapObject
            passedMap = true
        }
        self.delegate = delegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        presentationController?.delegate = self
        edgesForExtendedLayout = [.top]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enableKeyboardMethods()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disableKeyboardMethods()
    }

    func addMapObject() {
        // most values will be set in updatePostLevelValues
        mapObject = CustomMap(uid: UserDataModel.shared.uid)
        mapObject?.newMap = true
    }

    func setUpView() {
        view.backgroundColor = UIColor(named: "SpotBlack")

        nameField.delegate = self
        nameField.text = mapObject?.mapName ?? ""
        view.addSubview(nameField)
        let screenSizeOffset: CGFloat = UserDataModel.shared.screenSize == 2 ? 20 : UserDataModel.shared.screenSize == 1 ? 0 : -20
        let presentationOFfset: CGFloat = screenSizeOffset
        let topOffset: CGFloat = 30 + presentationOFfset
        let edgeInset: CGFloat = 18
        nameField.snp.makeConstraints {
            $0.top.equalTo(topOffset)
            $0.leading.trailing.equalToSuperview().inset(edgeInset)
            $0.height.equalTo(50)
        }

        let collaboratorOffset: CGFloat = UserDataModel.shared.screenSize == 0 ? 14 : 24
        view.addSubview(collaboratorLabel)
        collaboratorLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(nameField.snp.bottom).offset(collaboratorOffset)
            $0.height.equalTo(18)
        }

        collaboratorsCollection.delegate = self
        collaboratorsCollection.dataSource = self
        view.addSubview(collaboratorsCollection)
        collaboratorsCollection.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(collaboratorLabel.snp.bottom).offset(8)
            $0.height.equalTo(85)
        }

        let mapTypeOffset: CGFloat = UserDataModel.shared.screenSize == 0 ? 10 : 18
        view.addSubview(mapTypeLabel)
        mapTypeLabel.snp.makeConstraints {
            $0.leading.equalTo(margin)
            $0.top.equalTo(collaboratorsCollection.snp.bottom).offset(mapTypeOffset)
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

        view.addGestureRecognizer(keyboardPan)

        // community: 0, public: 1, private: 2
        let tag = (mapObject?.secret ?? false) ? 2 : (mapObject?.communityMap ?? false) ? 0 : 1
        mapPrivacyView.set(privacyLevel: UploadPrivacyLevel(rawValue: tag) ?? .Private)
        mapPrivacySlider.setSelected(position: MapPrivacySlider.SliderPosition(rawValue: tag) ?? .right)
        togglePrivacy(tag: tag)
    }
}
