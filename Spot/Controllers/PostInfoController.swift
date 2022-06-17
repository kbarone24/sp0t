//
//  PostInfoController.swift
//  Spot
//
//  Created by Kenny Barone on 4/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreLocation
import MapKit
import Geofirestore
import IQKeyboardManagerSwift

class PostInfoController: UIViewController {
    
    var navView: UIView!
    var mapContainer: UIView!
    var cancelButton, doneButton: UIButton!
    
    var postInfoSeg: PostInfoSeg!
    var pickerContainer: UIView!
    
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    
    var searchPan: UIPanGestureRecognizer!
    
    var selectedSegmentIndex = 0
    var tableView: UITableView!
    
    /// use all local values for local objects and only apply to singleton on done tap
    lazy var spotObjects: [MapSpot] = []
    lazy var querySpots: [MapSpot] = []
    
    lazy var friendObjects: [UserProfile] = []
    lazy var queryFriends: [UserProfile] = []
    
    lazy var tagObjects: [Tag] = []
    lazy var queryTags: [Tag] = []
    lazy var selectedTag = ""
    
    var queried = false
    var readyToDismiss = true
    var searchTextGlobal = ""
    var postLocation: CLLocation!

    /// nearby spot fetch variables
    let db = Firestore.firestore()
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    
    var circleQuery: GFSCircleQuery?
    var search: MKLocalSearch!
    let searchFilters: [MKPointOfInterestCategory] = [.airport, .amusementPark, .aquarium, .bakery, .beach, .brewery, .cafe, .campground, .foodMarket, .library, .marina, .museum, .movieTheater, .nightlife, .nationalPark, .park, .restaurant, .store, .school, .stadium, .theater, .university, .winery, .zoo]

    var cancelOnDismiss = false
    var queryReady = true
    
    var nearbyEnteredCount = 0
    var noAccessCount = 0
    var nearbyRefreshCount = 0
    var appendCount = 0
    
    /// spot search fetch
    var searchRefreshCount = 0
    var spotSearching = false
    
        
    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = .white
        presentationController?.delegate = self
        
        addNavButtons()
        addMap()
        setInitialValues()
        addPicker()
        runChooseSpotFetch()
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enable = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = false /// disable for textview sticking to keyboard
    }
    
    func addNavButtons() {
        
        navView = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40)
            view.addSubview($0)
        }
        
        cancelButton = UIButton {
            $0.frame = CGRect(x: 3, y: 6, width: 33, height: 33)
            $0.setImage(UIImage(named: "PostInfoCancel"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            $0.imageView?.contentMode = .scaleAspectFill
            navView.addSubview($0)
        }
        
        doneButton = UIButton {
            $0.frame = CGRect(x: navView.bounds.width - 63, y: 10, width: 53, height: 30)
            $0.setTitle("Done", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Heavy", size: 17)
            $0.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(doneTap(_:)), for: .touchUpInside)
            navView.addSubview($0)
        }
    }
    
    func addMap() {
        mapContainer = UIView {
            $0.frame = CGRect(x: 0, y: navView.frame.maxY, width: UIScreen.main.bounds.width, height: 170)
            $0.backgroundColor = .black
            view.addSubview($0)
        }
    }
    
    func addPicker() {
                
        postInfoSeg = PostInfoSeg {
            $0.frame = CGRect(x: 0, y: mapContainer.frame.maxY, width: UIScreen.main.bounds.width, height: 50)
            $0.setSelected(index: selectedSegmentIndex)
            view.addSubview($0)
        }
        
        pickerContainer = UIView {
            $0.frame = CGRect(x: 0, y: postInfoSeg.frame.maxY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - mapContainer.frame.maxY)
            view.addSubview($0)
        }
        
        searchBarContainer = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
            pickerContainer.addSubview($0)
        }
        
        searchBar = UISearchBar {
            $0.frame = CGRect(x: 16, y: 6, width: UIScreen.main.bounds.width - 32, height: 36)
            $0.tintColor = UIColor(red: 0.396, green: 0.396, blue: 0.396, alpha: 1)
            $0.searchTextField.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            $0.searchTextField.leftView?.tintColor = UIColor(red: 0.396, green: 0.396, blue: 0.396, alpha: 1)
            $0.delegate = self
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.placeholder = " Search"
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 3
            $0.keyboardDistanceFromTextField = 250
            pickerContainer.addSubview($0)
        }
        
        tableView = UITableView {
            $0.frame = CGRect(x: 0, y: searchBarContainer.frame.maxY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - pickerContainer.frame.minY + searchBarContainer.frame.height)
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 400, right: 0)
            $0.backgroundColor = .clear
            $0.separatorStyle = .none
            $0.delegate = self
            $0.dataSource = self
            $0.allowsSelection = false
            $0.showsVerticalScrollIndicator = false
            $0.register(ChooseSpotCell.self, forCellReuseIdentifier: "ChooseSpot")
            $0.register(ChooseSpotLoadingCell.self, forCellReuseIdentifier: "ChooseSpotLoading")
            $0.register(ChooseTagCell.self, forCellReuseIdentifier: "ChooseTag")
            $0.register(ChooseFriendsCell.self, forCellReuseIdentifier: "ChooseFriends")
            pickerContainer.addSubview($0)
        }
        
        searchPan = UIPanGestureRecognizer(target: self, action: #selector(searchPan(_:)))
        searchPan.delegate = self
        searchPan.isEnabled = false
        view.addGestureRecognizer(searchPan)

        setSelectedSegment(index: selectedSegmentIndex)
    }
    
    func setInitialValues() {
              
        let post = UploadPostModel.shared.postObject!
        
        // get top friends
        let sortedFriends = UserDataModel.shared.userInfo.topFriends.sorted(by: {$0.value > $1.value})
        let topFriends = Array(sortedFriends.map({$0.key}))

        /// match friend objects to id's
        for friend in topFriends {
            if var object = UserDataModel.shared.friendsList.first(where: {$0.id == friend}) {
                object.selected = post.addedUsers!.contains(where: {$0 == object.id})
                friendObjects.append(object)
            }
        }
        
        tagObjects = UploadPostModel.shared.sortedTags
        postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)
        
        selectedTag = UploadPostModel.shared.postObject.tag ?? ""
        
        if UploadPostModel.shared.spotObject != nil { spotObjects.append(UploadPostModel.shared.spotObject) }
    }
    
    func setSelectedSegment(index: Int) {
        /// reset table and search bar every time user switches between segs 
        selectedSegmentIndex = index
        emptySearch()
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func emptySearch() {
        /// reset search on each segment switch
        searchTextGlobal = ""
        searchBar.text = ""
        searchBar.resignFirstResponder()
        
        querySpots.removeAll()
        queryFriends.removeAll()
        queryTags.removeAll()
        
        spotSearching = false
        queried = false
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        DispatchQueue.main.async { self.dismiss(animated: true, completion: nil) }
    }
    
    @objc func doneTap(_ sender: UIButton) {
        /// set singleton values
        if let selectedSpot = spotObjects.first(where: {$0.selected!}) { UploadPostModel.shared.spotObject = selectedSpot } else { UploadPostModel.shared.spotObject = nil }
        setSpotValues()
        
        UploadPostModel.shared.postObject.addedUserProfiles.removeAll()
        UploadPostModel.shared.postObject.addedUsers!.removeAll()
        
        for friend in friendObjects {
            if friend.selected && !UploadPostModel.shared.postObject.addedUsers!.contains(friend.id!) { UploadPostModel.shared.postObject.addedUserProfiles.append(friend); UploadPostModel.shared.postObject.addedUsers!.append(friend.id!) }
        }
        
        UploadPostModel.shared.postObject.tag = selectedTag
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "PostInfoUpdate"), object: nil)
        resignFirstResponder()
        
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func setSpotValues() {
                
        let spot = UploadPostModel.shared.spotObject
        UploadPostModel.shared.postType = spot == nil ? .none : spot!.founderID == "" ? .postToPOI : .postToSpot
        
        /// set all spot level info for the upload object, all set to empty if no spot selected
        UploadPostModel.shared.postObject.createdBy = spot?.founderID ?? ""
        UploadPostModel.shared.postObject.spotID = spot?.id ?? ""
        UploadPostModel.shared.postObject.spotName = spot?.spotName ?? ""
        UploadPostModel.shared.postObject.spotLat = spot?.spotLat ?? 0.0
        UploadPostModel.shared.postObject.spotLong = spot?.spotLong ?? 0.0
        UploadPostModel.shared.postObject.spotPrivacy = spot?.privacyLevel ?? ""
        UploadPostModel.shared.postObject.inviteList = spot?.inviteList ?? []
    }
    
    
    @objc func searchPan(_ sender: UIPanGestureRecognizer) {
        /// remove keyboard on down swipe + vertical swipe > horizontal
        if abs(sender.translation(in: view).y) > abs(sender.translation(in: view).x) {
            searchBar.resignFirstResponder()
        }
    }
}

extension PostInfoController: UIGestureRecognizerDelegate, UIAdaptivePresentationControllerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
                
        if gestureRecognizer.view == view, let gesture = gestureRecognizer as? UIPanGestureRecognizer {
            return shouldRecognize(searchPan: gesture)
            
        } else if otherGestureRecognizer.view == view, let gesture = gestureRecognizer as? UIPanGestureRecognizer {
            return shouldRecognize(searchPan: gesture)
        }
        
        return true
    }
    
    func shouldRecognize(searchPan: UIPanGestureRecognizer) -> Bool {
        /// down swipe with table not offset return true
        return tableView.contentOffset.y < 5 && searchPan.translation(in: view).y > 0
    }
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        /// dont want to recognize swipe to dismiss with keyboard active
        return readyToDismiss
    }
}

extension PostInfoController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        queried = searchText != ""
        searchTextGlobal = searchText
        
        switch selectedSegmentIndex {
        case 0:
            runSpotSearch(searchText: searchText)
        case 1:
            runFriendSearch(searchText: searchText)
        case 2:
            runTagSearch(searchText: searchText)
        default:
            return
        }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchPan.isEnabled = true
        readyToDismiss = false
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchPan.isEnabled = false
        /// lag on ready to dismiss to avoid double tap to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.readyToDismiss = true
        }
    }
}

extension PostInfoController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch selectedSegmentIndex {
        case 0: return 58
        case 1: return 63
        case 2: return 320
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch selectedSegmentIndex {
        case 0:
            return spotSearching ? 1 : queried ? querySpots.count : spotObjects.count
        case 1:
            return queried ? queryFriends.count : friendObjects.count
        case 2:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch selectedSegmentIndex {
            
        case 0:
            
            let current = queried ? querySpots : spotObjects

            if indexPath.row < current.count {
        
                if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpot", for: indexPath) as? ChooseSpotCell {
                    cell.setUp(spot: current[indexPath.row])
                    return cell
                }
                
            } else {
                /// loading indicator for spot search
                if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpotLoading", for: indexPath) as? ChooseSpotLoadingCell {
                    cell.setUp()
                    return cell
                }
            }
            
            return UITableViewCell()
            
        case 1:
            
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseFriends", for: indexPath) as? ChooseFriendsCell {
                let current = queried ? queryFriends : friendObjects
                cell.setUp(friend: current[indexPath.row])
                return cell
            }
                
            return UITableViewCell()
            
        case 2:
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseTag", for: indexPath) as? ChooseTagCell {
                let current = queried ? queryTags : tagObjects
                cell.setUp(tags: current, selectedTag: selectedTag)
                return cell
            }
            return UITableViewCell()
            
        default:
            return UITableViewCell()
        }
    }
    
    func selectSpot(id: String) {
        if queried { for i in 0...querySpots.count - 1 { querySpots[i].selected = (querySpots[i].id == id && !(querySpots[i].selected!)) } }
        for i in 0...spotObjects.count - 1 { (spotObjects[i].selected = spotObjects[i].id == id && !(spotObjects[i].selected!)) }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func selectFriend(id: String) {
        if queried { if let i = queryFriends.firstIndex(where: {$0.id == id}) { queryFriends[i].selected = !queryFriends[i].selected } }
        if let i = friendObjects.firstIndex(where: {$0.id == id}) { friendObjects[i].selected = !friendObjects[i].selected }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func selectTag(name: String) {
        selectedTag = selectedTag == name ? "" : name
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
}

class PostInfoSeg: UIView {
    
    var spotsButton, friendsButton, tagsButton: UIButton!
    var bottomBar: UIView!
    var selectedSegmentIndex = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        /// end spacing - spacing of each button
        let spacing = (UIScreen.main.bounds.width - (31 + 36) - 80 - 97 - 74)/2
        
        spotsButton = UIButton {
            $0.frame = CGRect(x: 31, y: 12.5, width: 80, height: 30)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(spotsTap(_:)), for: .touchUpInside)
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            addSubview($0)
        }
        
        friendsButton = UIButton {
            $0.frame = CGRect(x: spotsButton.frame.maxX + spacing, y: 12.5, width: 97, height: 30)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            addSubview($0)
        }

        tagsButton = UIButton {
            $0.frame = CGRect(x: friendsButton.frame.maxX + spacing, y: 12.5, width: 74, height: 30)
            let tagsImage = selectedSegmentIndex == 2 ? UIImage(named: "PostInfoTagsSelected") : UIImage(named: "PostInfoTagsUnselected")
            $0.setImage(tagsImage, for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(tagsTap(_:)), for: .touchUpInside)
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            addSubview($0)
        }

        bottomBar = UIView {
            $0.frame = CGRect(x: 14, y: 48.5, width: UIScreen.main.bounds.width - 28, height: 1)
            $0.backgroundColor = UIColor(red: 0.902, green: 0.902, blue: 0.902, alpha: 1)
            $0.layer.cornerRadius = 9
            addSubview($0)
        }
        
        let selectedFrame: CGRect = selectedSegmentIndex == 0 ? spotsButton.frame : selectedSegmentIndex == 1 ? friendsButton.frame : tagsButton.frame
        bottomBar = UIView {
            $0.frame = CGRect(x: selectedFrame.minX - (106 - selectedFrame.width)/2, y: selectedFrame.maxY + 4.5, width: 116, height: 2.75)
            $0.backgroundColor = .black
            $0.layer.cornerRadius = 1
            addSubview($0)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func spotsTap(_ sender: UIButton) {
        setSelected(index: 0)
    }
    
    @objc func friendsTap(_ sender: UIButton) {
        setSelected(index: 1)
    }
    
    @objc func tagsTap(_ sender: UIButton) {
        setSelected(index: 2)
    }
    
    func setSelected(index: Int) {
        
        selectedSegmentIndex = index
        animateSegmentSwitch()
        
        guard let vc = viewContainingController() as? PostInfoController else { return }
        vc.setSelectedSegment(index: selectedSegmentIndex)
    }
    
    func animateSegmentSwitch() {
        let spotsImage = selectedSegmentIndex == 0 ? UIImage(named: "PostInfoSpotsSelected") : UIImage(named: "PostInfoSpotsUnselected")
        spotsButton.setImage(spotsImage, for: .normal)

        let friendsImage = selectedSegmentIndex == 1 ? UIImage(named: "PostInfoFriendsSelected") : UIImage(named: "PostInfoFriendsUnselected")
        friendsButton.setImage(friendsImage, for: .normal)

        let tagsImage = selectedSegmentIndex == 2 ? UIImage(named: "PostInfoTagsSelected") : UIImage(named: "PostInfoTagsUnselected")
        tagsButton.setImage(tagsImage, for: .normal)

        let selectedFrame: CGRect = selectedSegmentIndex == 0 ? spotsButton.frame : selectedSegmentIndex == 1 ? friendsButton.frame : tagsButton.frame
        
        UIView.animate(withDuration: 0.2) {
            self.bottomBar.frame = CGRect(x: selectedFrame.minX - (106 - selectedFrame.width)/2, y: selectedFrame.maxY + 4.5, width: 106, height: 2.75)
        }
    }
}
