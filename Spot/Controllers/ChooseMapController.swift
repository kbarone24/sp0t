//
//  ChooseMapController.swift
//  Spot
//
//  Created by Kenny Barone on 5/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI
import SnapKit
import Mixpanel

class ChooseMapController: UIViewController {
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore = Firestore.firestore()
    
    var newMap: CustomMap?
    private lazy var customMaps: [CustomMap] = []
    
    private var buttonView: UIView!
    private var postButton: UIButton!
    private var friendsMapButton: FriendsMapButton!
    private var tableView: ChooseMapTableView!
    private var bottomMask: UIView!
    private var heightConstraint: Constraint? = nil
    
    private var progressBar: ProgressBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
            
        addButtons()
        addTableView()
        addProgressBar()
        
        DispatchQueue.global(qos: .userInitiated).async { self.getCustomMaps() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = .white
        setUpNavBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ChooseMapOpen")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        addBottomMask()
    }
    
    func setUpNavBar() {
        navigationItem.title = "Post to maps"
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.addWhiteBackground()
        
        let barButtonItem = UIBarButtonItem(image: UIImage(named: "BackArrowDark"), style: .plain, target: self, action: #selector(backTap(_:)))
        navigationItem.leftBarButtonItem = barButtonItem
        
        if let mapNav = navigationController as? MapNavigationController {
            mapNav.requiredStatusBarStyle = .darkContent
        }

    }
    
    func addButtons() {
        /// work bottom to top laying out views
        postButton = PostButton {
            $0.addTarget(self, action: #selector(postTap), for: .touchUpInside)
            view.addSubview($0)
        }
        postButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-48)
            $0.leading.trailing.equalToSuperview().inset(49)
            $0.height.equalTo(58)
        }
        
        friendsMapButton = FriendsMapButton {
            $0.addTarget(self, action: #selector(friendsMapTap), for: .touchUpInside)
            view.addSubview($0)
        }
        friendsMapButton.snp.makeConstraints {
            $0.top.equalTo(45)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(62)
        }
    }
    
    func addTableView() {
        tableView = ChooseMapTableView {
            $0.dataSource = self
            $0.delegate = self
            view.addSubview($0)
        }
        tableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(friendsMapButton.snp.bottom).offset(38)
            $0.bottom.equalTo(postButton.snp.top)
        }
    }
    
    func addProgressBar() {
        progressBar = ProgressBar {
            $0.isHidden = true
            view.addSubview($0)
        }
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.bottom.equalTo(postButton.snp.top).offset(-20)
            $0.height.equalTo(18)
        }
    }
    
    func getCustomMaps() {
        newMap = UploadPostModel.shared.mapObject
        customMaps = UserDataModel.shared.userInfo.mapsList.filter({$0.memberIDs.contains(UserDataModel.shared.uid)}).sorted(by: {$0.userTimestamp.seconds > $1.userTimestamp.seconds})
        
        if newMap != nil {
            newMap!.coverImage = UploadPostModel.shared.postObject.postImage.first ?? UIImage() /// new map image not set when going through new map flow
            customMaps.insert(newMap!, at: 0)
            if newMap!.secret { toggleFriendsMap() }
        }
        
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
        
    func enablePostButton() {
        postButton.isEnabled = friendsMapButton.buttonSelected || UploadPostModel.shared.postObject.mapID != ""
    }

    @objc func friendsMapTap() {
        toggleFriendsMap()
        HapticGenerator.shared.play(.light)
    }
    
    func toggleFriendsMap() {
        friendsMapButton.buttonSelected.toggle()
        UploadPostModel.shared.postObject.hideFromFeed = !friendsMapButton.buttonSelected
        enablePostButton()
    }
    
    func addBottomMask() {
        if bottomMask != nil { return }
        bottomMask = UIView {
            $0.backgroundColor = nil
            $0.isUserInteractionEnabled = false
            view.addSubview($0)
        }
        view.bringSubviewToFront(postButton)
        let _ = CAGradientLayer {
            $0.frame = CGRect(x: 0, y: postButton.frame.minY - 120, width: UIScreen.main.bounds.width, height: 120)
            $0.colors = [
                UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor,
                UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 0.0)
            $0.endPoint = CGPoint(x: 0.5, y: 1.0)
            $0.locations = [0, 1]
            bottomMask.layer.addSublayer($0)
        }
    }
            
    @objc func postTap() {
        postButton.isEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false

        /// make sure all post values are set for upload
        /// make sure there is a spot object attached to this post if posting to a spot
        /// need to enable create new spot
        UploadPostModel.shared.setFinalPostValues()
        if UploadPostModel.shared.mapObject != nil { UploadPostModel.shared.setFinalMapValues() }
        let newMap = self.newMap != nil
        
        progressBar.isHidden = false
        view.bringSubviewToFront(progressBar)
        let fullWidth = self.progressBar.bounds.width - 2
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadPostImage(UploadPostModel.shared.postObject.postImage, postID: UploadPostModel.shared.postObject.id!, progressFill: self.progressBar.progressFill, fullWidth: fullWidth) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUpload")
                    self.runFailedUpload()
                    return
                }
                UploadPostModel.shared.postObject.imageURLs = imageURLs
                self.uploadPostToDB(newMap: newMap)
                /// enable upload animation to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    HapticGenerator.shared.play(.soft)
                    self.popToMap()
                }
            }
        }
    }
            
    func runFailedUpload() {
        showFailAlert()
        UploadPostModel.shared.saveToDrafts()
    }
        
    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style{
            case .default:
                self.popToMap()
            case .cancel:
                self.popToMap()
            case .destructive:
                self.popToMap()
            @unknown default:
                fatalError()
            }}))
        present(alert, animated: true, completion: nil)
    }

    @objc func backTap(_ sender: UIBarButtonItem) {
        /// reset new map object to show empty selection next time user comes through
        UploadPostModel.shared.setMapValues(map: nil)
        self.navigationController?.popViewController(animated: true)
    }
    
    func popToMap() {
        UploadPostModel.shared.destroy()
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}

extension ChooseMapController: NewMapDelegate {
    func finishPassing(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapCreateNew")
        /// only select if map was just created, update on edit
        if newMap == nil {
            customMaps.insert(map, at: 0)
        } else {
            customMaps[0] = map
        }
        
        newMap = map
        selectMap(map: map)
    }
    
    func selectMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapSelectMap")
        UploadPostModel.shared.setMapValues(map: map)
        /// if private map, make sure mymapbutton is deselected, if public, make sure selected
        if map.secret && friendsMapButton.buttonSelected { toggleFriendsMap() }
        DispatchQueue.main.async { self.tableView.reloadData() }
        enablePostButton()
    }
    
    func deselectMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapDeselectMap")
        UploadPostModel.shared.setMapValues(map: nil)
        
        DispatchQueue.main.async { self.tableView.reloadData() }
        enablePostButton()
    }
}

extension ChooseMapController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newMap != nil ? customMaps.count : customMaps.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath) as? CustomMapUploadCell {
            let index = newMap != nil ? indexPath.row : indexPath.row - 1
            /// map will be nil for row "-1" which represents the add spot row
            let map = customMaps[safe: index]
            let selected = UploadPostModel.shared.postObject.mapID == map?.id ?? "_"
            cell.setUp(map: map, selected: selected, newMap: newMap != nil)
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let index = indexPath.row - 1
        let map = customMaps[safe: index]
        if map == nil, let newMapVC = storyboard?.instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
            newMapVC.delegate = self
            newMapVC.mapObject = newMap
            DispatchQueue.main.async { self.present(newMapVC, animated: true) }
        } else {
            map!.id == UploadPostModel.shared.postObject.mapID ? deselectMap(map: map!) : selectMap(map: map!)
            HapticGenerator.shared.play(.light)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MapsHeader") as? CustomMapsHeader else { return UIView() }
        return header
    }
}

class ChooseMapTableView: UITableView {
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        backgroundColor = nil
        contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        separatorStyle = .none
        showsVerticalScrollIndicator = false
        register(CustomMapUploadCell.self, forCellReuseIdentifier: "MapCell")
        register(CustomMapsHeader.self, forHeaderFooterViewReuseIdentifier: "MapsHeader")
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FriendsMapButton: UIButton {
    var friendsMapIcon: UIImageView!
    var mapLabel: UILabel!
    var detailLabel: UILabel!
    var selectedImage: UIImageView!
    var buttonSelected: Bool = true {
        didSet {
            let buttonImage = buttonSelected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
            selectedImage.image = buttonImage
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil
        
        friendsMapIcon = UIImageView {
            $0.image = UIImage(named: "FriendsMapIcon")
            $0.contentMode = .scaleAspectFill
            addSubview($0)
        }
        friendsMapIcon.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.width.equalTo(60)
            $0.height.equalTo(62)
        }
        
        mapLabel = UILabel {
            $0.text = "Friends map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(friendsMapIcon.snp.trailing).offset(4)
            $0.top.equalTo(18)
        }
        
        let buttonImage = buttonSelected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
        selectedImage = UIImageView {
            $0.image = buttonImage
            addSubview($0)
        }
        selectedImage.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(22)
            $0.height.width.equalTo(33)
            $0.centerY.equalToSuperview()
        }
        
        detailLabel = UILabel {
            $0.text = "You and your friends shared world"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14)
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.7
            addSubview($0)
        }
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(mapLabel.snp.leading)
            $0.top.equalTo(mapLabel.snp.bottom).offset(1)
            $0.trailing.lessThanOrEqualTo(selectedImage.snp.leading).offset(-8)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
