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
    private var myMapButton: MyMapButton!
    private var tableView: UITableView!
    private var heightConstraint: Constraint? = nil
    
    private var progressBar: UIView!
    private var progressFill: UIView!
    
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
    
    func setUpNavBar() {
        navigationItem.title = "Choose a map"
        
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
            $0.addTarget(self, action: #selector(shareTap), for: .touchUpInside)
            view.addSubview($0)
        }
        postButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-48)
            $0.leading.trailing.equalToSuperview().inset(64)
            $0.height.equalTo(58)
        }
        
        myMapButton = MyMapButton {
            $0.addTarget(self, action: #selector(myMapTap), for: .touchUpInside)
            view.addSubview($0)
        }
        myMapButton.snp.makeConstraints {
            $0.top.equalTo(45)
            $0.leading.equalTo(17)
            $0.trailing.equalToSuperview().inset(25)
            $0.height.equalTo(61)
        }
    }
    
    func addTableView() {
        tableView = UITableView {
            $0.backgroundColor = nil
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
            $0.separatorStyle = .none
            $0.dataSource = self
            $0.delegate = self
            $0.showsVerticalScrollIndicator = false
            $0.register(CustomMapsHeader.self, forHeaderFooterViewReuseIdentifier: "MapsHeader")
            $0.register(CustomMapUploadCell.self, forCellReuseIdentifier: "MapCell")
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        tableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(myMapButton.snp.bottom).offset(22)
            $0.bottom.equalTo(postButton.snp.top).offset(-20)
        }
    }
    
    func addProgressBar() {
        progressBar = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
            $0.layer.cornerRadius = 6
            $0.layer.borderWidth = 2
            $0.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            $0.isHidden = true
            view.addSubview($0)
        }
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.bottom.equalTo(postButton.snp.top).offset(-20)
            $0.height.equalTo(18)
        }
        
        progressFill = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 6
            progressBar.addSubview($0)
        }
        progressFill.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(1)
            $0.width.equalTo(0)
            $0.height.equalTo(16)
        }
    }
    
    func getCustomMaps() {
        customMaps = UserDataModel.shared.userInfo.mapsList.sorted(by: {$0.userTimestamp.seconds > $1.userTimestamp.seconds})
    }
    
    func reloadTable() {
        customMaps.sort(by: {$0.userTimestamp.seconds > $1.userTimestamp.seconds})
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func enablePostButton() {
        postButton.isEnabled = myMapButton.buttonSelected || UploadPostModel.shared.postObject.mapID != ""
    }

    @objc func myMapTap() {
        myMapButton.buttonSelected = !myMapButton.buttonSelected
        UploadPostModel.shared.postObject.hideFromFeed = !myMapButton.buttonSelected
        enablePostButton()
    }
            
    @objc func shareTap() {
        
        postButton.isEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false

        /// make sure all post values are set for upload
        /// make sure there is a spot object attached to this post if posting to a spot
        /// need to enable create new spot
        UploadPostModel.shared.setFinalPostValues()
        if newMap == nil && UploadPostModel.shared.mapObject != nil { UploadPostModel.shared.setFinalMapValues() }

        let uid = uid
        let post = UploadPostModel.shared.postObject!
        let spot = UploadPostModel.shared.spotObject
        let map = UploadPostModel.shared.mapObject
        let newMap = self.newMap != nil
        progressBar.isHidden = false

        let fullWidth = self.progressBar.bounds.width - 2
        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadPostImage(post.postImage, postID: post.id!, progressFill: self.progressFill, fullWidth: fullWidth) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUpload")
                    self.runFailedUpload()
                    return
                }
                
                UploadPostModel.shared.postObject.imageURLs = imageURLs
                UploadPostModel.shared.postObject.timestamp = Firebase.Timestamp(date: Date())
                let post = UploadPostModel.shared.postObject!
                
                self.uploadPost(post: post)

                if spot != nil {
                    var spot = spot!
                    spot.imageURL = imageURLs.first ?? ""
                    self.uploadSpot(post: post, spot: spot, submitPublic: false)
                }
                
                if map != nil {
                    var map = map!
                    if map.imageURL == "" { map.imageURL = imageURLs.first ?? "" }
                    map.postImageURLs.append(imageURLs.first ?? "")
                    self.uploadMap(map: map, newMap: newMap, post: post)
                }
                
                let visitorList = spot?.visitorList ?? []
                self.setUserValues(poster: uid, post: post, spotID: spot?.id ?? "", visitorList: visitorList, mapID: map?.id ?? "")
                            
                Mixpanel.mainInstance().track(event: "SuccessfulPostUpload")
                /// enable upload animation to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.popToMap()
                }
            }
        }
    }
            
    func runFailedUpload() {
        showFailAlert()
        saveToDrafts()
    }
    
    func saveToDrafts() {
        let post = UploadPostModel.shared.postObject!
        let spot = UploadPostModel.shared.spotObject
        let map = UploadPostModel.shared.mapObject
        
        let selectedImages = post.postImage
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else { return }
        
        let managedContext =
        appDelegate.persistentContainer.viewContext
        
        var imageObjects : [ImageModel] = []
        
        var index: Int16 = 0
        for image in selectedImages {
            let im = ImageModel(context: managedContext)
            im.imageData = image.jpegData(compressionQuality: 0.5)
            im.position = index
            imageObjects.append(im)
            index += 1
        }
        
        var aspectRatios: [Float] = []
        for aspect in post.aspectRatios ?? [] { aspectRatios.append(Float(aspect)) }
        let postObject = PostDraft(context: managedContext)
        postObject.addedUsers = post.addedUsers
        postObject.aspectRatios = aspectRatios
        postObject.caption = post.caption
        postObject.city = post.city ?? ""
        postObject.createdBy = post.createdBy
        postObject.frameIndexes = post.frameIndexes ?? []
        postObject.friendsList = post.friendsList
        postObject.hideFromFeed = post.hideFromFeed ?? false
        postObject.images = NSSet(array: imageObjects)
        postObject.inviteList = spot?.inviteList ?? []
        postObject.mapID = post.mapID
        postObject.mapName = post.mapName
        postObject.postLat = post.postLat
        postObject.postLong = post.postLong
        postObject.privacyLevel = post.privacyLevel
        postObject.spotID = spot?.id ?? ""
        postObject.spotLat = spot?.spotLat ?? 0.0
        postObject.spotLong = spot?.spotLong ?? 0.0
        postObject.spotName = spot?.spotName ?? ""
        postObject.spotPrivacy = spot?.privacyLevel ?? ""
        postObject.taggedUsers = post.taggedUsers
        postObject.taggedUserIDs = post.taggedUserIDs
        postObject.uid = uid
        print("spot id", spot?.id ?? "")
        
        postObject.visitorList = spot?.visitorList ?? []
        postObject.newSpot = UploadPostModel.shared.postType == .newSpot
        postObject.postToPOI = UploadPostModel.shared.postType == .postToPOI
        postObject.poiCategory = spot?.poiCategory ?? ""
        postObject.phone = spot?.phone ?? ""
        
        postObject.mapMemberIDs = map?.memberIDs ?? []
        postObject.mapSecret = map?.secret ?? false
        
        let timestamp = Timestamp()
        let seconds = timestamp.seconds
        postObject.timestamp = seconds
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
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
        newMap = map
        customMaps.append(map)
        selectMap(map: map)
    }
    
    func selectMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapSelectMap")
        UploadPostModel.shared.mapObject = map
        UploadPostModel.shared.postObject.mapID = map.id!
        UploadPostModel.shared.postObject.mapName = map.mapName
        
        DispatchQueue.main.async { self.tableView.reloadData() }
        enablePostButton()
    }
    
    func deselectMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapDeselectMap")
        UploadPostModel.shared.mapObject = nil
        UploadPostModel.shared.postObject.mapID = ""
        UploadPostModel.shared.postObject.mapName = ""
        
        DispatchQueue.main.async { self.tableView.reloadData() }
        enablePostButton()
    }
}

extension ChooseMapController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return customMaps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath) as? CustomMapUploadCell {
            let map = customMaps[indexPath.row]
            cell.setUp(map: map, selected: UploadPostModel.shared.postObject.mapID == map.id!, beginningCell: indexPath.row == 0, endCell: indexPath.row == customMaps.count - 1)
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 72
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MapsHeader") as? CustomMapsHeader else { return UIView() }
        header.mapsEmpty = customMaps.isEmpty
        return header
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let map = customMaps[indexPath.row]
        map.id == UploadPostModel.shared.postObject.mapID ? deselectMap(map: map) : selectMap(map: map)
    }
}

class CustomMapsHeader: UITableViewHeaderFooterView {
    var customMapsLabel: UILabel!
    var newMapButton: UIButton!
    var plusIcon: UIImageView!
    var mapLabel: UILabel!
    var mapsEmpty: Bool = true {
        didSet {
            if !mapsEmpty { customMapsLabel.isHidden = false }
        }
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView
                
        customMapsLabel = UILabel {
            $0.text = "CUSTOM MAPS"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.isHidden = true
            addSubview($0)
        }
        customMapsLabel.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.bottom.equalToSuperview().inset(6)
        }

        newMapButton = UIButton {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.addTarget(self, action: #selector(newMapTap(_:)), for: .touchUpInside)
            $0.layer.cornerRadius = 11
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1).cgColor
            addSubview($0)
        }
        newMapButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(26)
            $0.bottom.equalToSuperview().inset(10)
            $0.width.equalTo(119)
            $0.height.equalTo(38)
        }

        plusIcon = UIImageView {
            $0.image = UIImage(named: "PlusIcon")
            newMapButton.addSubview($0)
        }
        plusIcon.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.width.height.equalTo(15)
            $0.centerY.equalToSuperview()
        }
        
        mapLabel = UILabel {
            $0.text = "New map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 15.5)
            newMapButton.addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(plusIcon.snp.trailing).offset(8)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func newMapTap(_ sender: UIButton) {
        if let chooseMapVC = viewContainingController() as? ChooseMapController {
            if let newMapVC = chooseMapVC.storyboard?.instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
                newMapVC.delegate = chooseMapVC
                chooseMapVC.present(newMapVC, animated: true)
            }
        }
    }
}

class CustomMapUploadCell: UITableViewCell {
    var pillView: UIView!
    var mapImage: UIImageView!
    var nameLabel: UILabel!
    var selectedImage: UIImageView!
    
    func setUp(map: CustomMap, selected: Bool, beginningCell: Bool, endCell: Bool) {
        backgroundColor = .white
        selectionStyle = .none
        
        if pillView != nil { pillView.removeFromSuperview() }
        pillView = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1).cgColor
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 12
            var maskedCorners = CACornerMask()
            if beginningCell { maskedCorners.insert([.layerMaxXMinYCorner, .layerMinXMinYCorner]) }
            if endCell { maskedCorners.insert([.layerMinXMaxYCorner, .layerMaxXMaxYCorner]) }
            $0.layer.maskedCorners = maskedCorners
            contentView.addSubview($0)
        }
        pillView.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.trailing.equalToSuperview().inset(25)
            $0.top.bottom.equalToSuperview()
        }
        
        if mapImage != nil { mapImage.removeFromSuperview() }
        mapImage = UIImageView {
            $0.layer.cornerRadius = 17
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill

            let url = map.imageURL
            if map.coverImage != UIImage () {
                $0.image = map.coverImage
            } else if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
            }
            pillView.addSubview($0)
        }
        mapImage.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.height.width.equalTo(34)
            $0.centerY.equalToSuperview()
        }
        
        if selectedImage != nil { selectedImage.removeFromSuperview() }
        let buttonImage = selected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
        selectedImage = UIImageView {
            $0.image = buttonImage
            pillView.addSubview($0)
        }
        selectedImage.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(14)
            $0.height.width.equalTo(29)
            $0.centerY.equalToSuperview()
        }

        nameLabel = UILabel {
            $0.text = map.mapName
            $0.textColor = .black
            $0.lineBreakMode = .byTruncatingTail
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            pillView.addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(mapImage.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualTo(selectedImage.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
        }
    }
}

class MyMapButton: UIButton {
    var avatarImage: UIImageView!
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
        backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        layer.cornerRadius = 17.5
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1).cgColor
        
        avatarImage = UIImageView {
            $0.image = UserDataModel.shared.userInfo.avatarPic
            $0.contentMode = .scaleAspectFill
            addSubview($0)
        }
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(7)
            $0.width.equalTo(26)
            $0.height.equalTo(37.5)
            $0.centerY.equalToSuperview()
        }
        
        mapLabel = UILabel {
            $0.text = "My map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(4)
            $0.top.equalTo(10)
        }
        
        detailLabel = UILabel {
            $0.text = "Friends can see your map"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14)
            addSubview($0)
        }
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(mapLabel.snp.leading)
            $0.top.equalTo(mapLabel.snp.bottom).offset(1)
        }
        
        let buttonImage = buttonSelected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
        selectedImage = UIImageView {
            $0.image = buttonImage
            addSubview($0)
        }
        selectedImage.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(14)
            $0.height.width.equalTo(29)
            $0.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PostButton: UIButton {
    var postIcon: UIImageView!
    var postText: UILabel!
    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.5
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotGreen")
        layer.cornerRadius = 15
        
        postIcon = UIImageView {
            $0.image = UIImage(named: "PostIcon")
            addSubview($0)
        }
        postIcon.snp.makeConstraints {
            $0.leading.equalTo(self.snp.centerX).offset(-27.5)
            $0.top.equalTo(16)
            $0.height.equalTo(21.5)
            $0.width.equalTo(16)
        }
        
        postText = UILabel {
            $0.text = "Post"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16.5)
            addSubview($0)
        }
        postText.snp.makeConstraints {
            $0.leading.equalTo(postIcon.snp.trailing).offset(6)
            $0.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FailedUploadView {
    
}

