//
//  SpotViewController.swift
//  Spot
//
//  Created by kbarone on 4/18/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation
import Photos
import MapKit
import Mixpanel
import FirebaseUI
import Geofirestore

//add create post delegate
class SpotViewController: UIViewController {
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    var spotID: String!
    var spotObject: MapSpot!
    var spotName: String!
    lazy var friendVisitors: [UserProfile] = []
    lazy var postsList: [MapPost] = []
    
    lazy var shadowScroll = UIScrollView() /// receives all touch events to allow for smooth scrolling between segments
    var tableView: UITableView!
    var addToSpotButton: UIButton!
    var activityIndicator: CustomActivityIndicator!
    
    lazy var tableScrollNeeded = false /// table scroll needed used when drawer goes to full screen
    unowned var mapVC: MapViewController!
    
    let db: Firestore! = Firestore.firestore()
    var listener1, listener2, listener3: ListenerRegistration!
    
    lazy var halfScreenUserCount = 0
    lazy var fullScreenUserCount = 0
    lazy var halfScreenUserHeight: CGFloat = 0
    lazy var fullScreenUserHeight: CGFloat = 0
    lazy var sec0Height: CGFloat = 0
    var expandUsers = false, usersMoreNeeded = false

    lazy var postIndex = 0
    
    var editMask: UIView!
    var editView: UIView!
    var editedSpot: MapSpot!
    lazy var editSpotMode = false
    lazy var editedImage = false /// determines whether edit controller should update the cover image in DB
    
    lazy var active = true ///  false if there is a child view receiving events
    lazy var presentFriends = false /// true if user is returning from a profile tapped through the visitor list
    
    deinit {
        print("deinit spot")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        NotificationCenter.default.post(name: Notification.Name("SpotPageAppear"), object: nil, userInfo: nil)
        
        setUpTable()
        setUpNavBar()

        if spotObject != nil {
            runInitialFuncs()
        } else {
            getSpotInfo()
        }
                
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAddressChange(_:)), name: NSNotification.Name("SpotAddressChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyImageChange(_:)), name: NSNotification.Name("ImageChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditPost(_:)), name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeletePost(_:)), name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUsersChange(_:)), name: NSNotification.Name("UserListRemove"), object: nil)
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if children.count != 0 { return } /// edge case if entering from background or from edit location
        
        mapVC.spotViewController = self
        mapVC.profileViewController = nil
        mapVC.nearbyViewController = nil
        mapVC.customTabBar.tabBar.isHidden = true
        mapVC.hideNearbyButtons()

        Mixpanel.mainInstance().track(event: "SpotPageOpen")
        ///pass back from camera or other stacked view controller
        
        self.addToSpotButton != nil ? resetView() : addAddToSpot()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
                
        if self.isMovingFromParent { removeListeners() }
        addToSpotButton.isHidden = true
        cancelDownloads()
    }
    
    func cancelDownloads() {
        if let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? GuestbookCollectionCell {
            for postCell in cell.postsCollection.visibleCells {
                guard let safeCell = postCell as? GuestbookCell else { return }
                safeCell.imagePreview.sd_cancelCurrentImageLoad()
            }
        }
    }
    
    func runInitialFuncs() {
        getFriendVisitors()
        DispatchQueue.global(qos: .userInitiated).async { self.getSpotPosts() }
    }

    func getSpotInfo() {
        
        db.collection("spots").document(spotID).getDocument { (snap, err) in
            guard let doc = snap else { return }
            do {

                let spot = try doc.data(as: MapSpot.self)
                guard var spotInfo = spot else { return }
                
                spotInfo.id = self.spotID
                self.spotObject = spotInfo
                               
                /// (MAP) set selected spotID, add spot annotation to spot annotations
                /// (MAP) remove existing annotations, add spot annotation
                let infoPass = ["spot": spotInfo as Any] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("OpenSpotFromPost"), object: nil, userInfo: infoPass)
                
                self.runInitialFuncs()
                if self.editSpotMode { self.presentEditSpot()}
                
                DispatchQueue.main.async { self.tableView.reloadData() }
                
            } catch { return }
        }
    }
    
    // edit spot adress change
    @objc func notifyAddressChange(_ sender: NSNotification) {
        if let info = sender.userInfo as? [String: Any] {
            guard let coordinate = info["coordinate"] as? CLLocationCoordinate2D else { return }
            print("notify add change")
            if let editVC = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "EditSpot") as? EditSpotController {
                editVC.spotVC = self
                editVC.mapVC = self.mapVC
                let spot = self.editedSpot == nil ? self.spotObject : self.editedSpot
                editVC.spotObject = spot
                editVC.spotObject.spotLat = coordinate.latitude
                editVC.spotObject.spotLong = coordinate.longitude
                self.present(editVC, animated: false, completion: nil)
                self.editedSpot = nil
            }
        }
    }
    
    
    //edit spot image change
    @objc func notifyImageChange(_ sender: NSNotification) {
        if let info = sender.userInfo as? [String: Any] {
            guard let image = info["image"] as? UIImage else { return }
            if let editVC = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "EditSpot") as? EditSpotController {
                
                editVC.spotVC = self
                editVC.mapVC = self.mapVC
                
                let spot = self.editedSpot == nil ? self.spotObject : self.editedSpot
                editVC.spotObject = spot
                editVC.spotObject.spotImage = image
                print("set edited image")
                
                self.present(editVC, animated: false, completion: nil)
                self.editedSpot = nil
                self.editedImage = true
            }
        }
    }
    
    @objc func notifyEditPost(_ sender: NSNotification) {
        // edit from edit post
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            if let index = postsList.firstIndex(where: {$0.id == newPost.id}) {
                self.postsList[index] = newPost
                self.tableView.reloadData()
            }
        } else if let info = sender.userInfo as? [String: Any] {
            // edit from edit spot
            guard let postID = info["postID"] as? String else { return }
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                self.postsList[index].spotName = info["spotName"] as? String ?? ""
                self.postsList[index].inviteList = info["inviteList"] as? [String] ?? []
                self.postsList[index].spotLat = info["spotLat"] as? Double ?? 0.0
                self.postsList[index].spotLong = info["spotLong"] as? Double ?? 0.0
                self.postsList[index].spotPrivacy = info["spotPrivacy"] as? String ?? ""
                self.tableView.reloadData()
            }
        }
    }
    
    @objc func notifyDeletePost(_ sender: NSNotification) {

        /// only one delete from spotVC so use single delete function
        if let postIDs = sender.userInfo?.first?.value as? [String] {
            guard let postID = postIDs.first else { return }
            
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                
                self.postsList.remove(at: index)
                self.postsList.sort(by: {$0.seconds > $1.seconds})
                self.tableView.reloadData()
                if postsList.count == 0 { return } /// cancel post page funcs on spotDelete
                
                if let postVC = self.children.first as? PostViewController {
                    
                    postVC.postsList = self.postsList
                    postVC.tableView.beginUpdates()
                    postVC.tableView.deleteRows(at: [IndexPath(row: postVC.selectedPostIndex, section: 0)], with: .bottom)
                    postVC.tableView.endUpdates()
                    
                    /// scroll table to previous row if necessary 
                    if postVC.selectedPostIndex >= postVC.postsList.count {
                        postVC.selectedPostIndex = max(0, postVC.postsList.count - 1)
                        postVC.tableView.scrollToRow(at: IndexPath(row: postVC.selectedPostIndex, section: 0), at: .top, animated: true)
                        postVC.tableView.reloadData()
                    }

                    let mapPass = ["selectedPost": postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.spot] as [String : Any]
                    NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                }
            }
            
            if let index = self.mapVC.postsList.firstIndex(where: {$0.id == postID}) {
                self.mapVC.postsList.remove(at: index)
                self.mapVC.postsList.sort(by: {$0.seconds > $1.seconds})
            }
        }
    }
    
    @objc func notifyUsersChange(_ sender: NSNotification) {
        self.friendVisitors.removeAll(where: {$0.id == uid})
        if tableView != nil { tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none )}
    }
    
    func addAddToSpot() {
        ///add addToSpot button over the top of custom tab bar
        
        let addY = mapVC.largeScreen ? UIScreen.main.bounds.height - 89 : UIScreen.main.bounds.height - 74
        let addX = mapVC.largeScreen ? UIScreen.main.bounds.width - 73 : UIScreen.main.bounds.width - 69
        addToSpotButton = UIButton(frame: CGRect(x: addX, y: addY, width: 55, height: 55))
        addToSpotButton.setImage(UIImage(named: "AddToSpotButton"), for: .normal)
        addToSpotButton.addTarget(self, action: #selector(addToSpotTap(_:)), for: .touchUpInside)
        mapVC.view.addSubview(addToSpotButton)
        
        mapVC.unhideSpotButtons()
    }
    
    func getFriendVisitors() {
        //get invite list for a private spot to show # of friends
        if spotObject.privacyLevel == "invite" {
            for visitor in spotObject.inviteList ?? [] {
                if let friend = mapVC.friendsList.first(where: {$0.id == visitor}) {
                    self.friendVisitors.append(friend)
                    if self.friendVisitors.count == self.spotObject.inviteList?.count { getUsersSize() }

                } else {
                    print("visitor", visitor)
                    self.getUser(id: visitor) { [weak self] (user) in
                        guard let self = self else { return }
                        self.friendVisitors.append(user)
                        if self.friendVisitors.count == self.spotObject.inviteList?.count  { self.getUsersSize() }
                    }
                }
            }
            
        } else {
            //get visitor list for a non private spot to show # of friend visitors
            for visitor in spotObject.visitorList {
                if let friend = mapVC.friendsList.first(where: {$0.id == visitor}) {
                    if !self.mapVC.adminIDs.contains(visitor) {
                        self.friendVisitors.append(friend)
                    }
                }
                else if visitor == self.uid { self.friendVisitors.append(self.mapVC.userInfo) }
                
                if visitor == spotObject.visitorList.last { getUsersSize() }
            }
        }
    }
    
    // this could be causing strong reference cycle need to check
    func getUser(id: String, completion: @escaping (_ user: UserProfile) -> Void) {
        ///supplemental get user method used for getting non-friends for private spots invite list
        self.db.collection("users").document(id).getDocument { (friendSnap, err) in
            do {
                let friendInfo = try friendSnap?.data(as: UserProfile.self)
                guard var info = friendInfo else { return }
                
                info.id = friendSnap!.documentID
                completion(info)
                
            } catch { return }
        }
    }
    
    func getUsersSize() {

        /// reset values in case spot was edited
        halfScreenUserCount = 0
        fullScreenUserCount = 0
        halfScreenUserHeight = 0
        fullScreenUserHeight = 0
        
        var stopIncrementingHalf = false
                
        var numberOfRows = 0
        /// 14 is the edge inset of the collection
        var lineWidth: CGFloat = 14
        print("visitor count", friendVisitors.count)
        for friend in friendVisitors {
            
            let userWidth = getWidth(name: friend.username)
            if lineWidth + userWidth + 14 > UIScreen.main.bounds.width || fullScreenUserCount == 0 {

                /// new row
                numberOfRows += 1
                
                if numberOfRows == 3 {
                    /// if this is the 3rd row, stop incrementing half screen size and half screen users and check if there will be room for the + more cell on half screen
                    let extraCount = friendVisitors.count - halfScreenUserCount
                    let moreWidth = getMoreWidth(extraCount: extraCount)
                    usersMoreNeeded = true
                    /// room for an extra user cell if more won't cause line overflow
                    if lineWidth + moreWidth + 14 < UIScreen.main.bounds.width { halfScreenUserCount += 1 }
                    stopIncrementingHalf = true
                }
                
                lineWidth = 14
                /// rowheightX + headerHeight + 5
                let rowHeight = CGFloat(numberOfRows * 34) + 37
                
                fullScreenUserHeight = rowHeight
                if !stopIncrementingHalf { halfScreenUserHeight = fullScreenUserHeight }
            }
            
         ///  x + 11 (spacing between cells)
            lineWidth += userWidth + 11
            fullScreenUserCount += 1
            if !stopIncrementingHalf { halfScreenUserCount = fullScreenUserCount }
            
            if friend.id == friendVisitors.last?.id {
                DispatchQueue.main.async { self.tableView.reloadData() }
            }

        }
    }
    
    func resizeTable(halfScreen: Bool, forceRefresh: Bool) {
        
        let closeOnRefresh = halfScreen && expandUsers
        if closeOnRefresh { expandUsers = false }
        
        /// only refresh when expanding or closing the section
        if closeOnRefresh || forceRefresh {
            tableView.reloadSections(IndexSet(0...0), with: .fade)
        }
    }
    
        
    func getWidth(name: String) -> CGFloat {
            
        let username = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 16))
        username.text = name
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.sizeToFit()
        return 30 + username.frame.width
    }
    
    func getMoreWidth(extraCount: Int) -> CGFloat {
        
        let moreLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 16))
        moreLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        moreLabel.text = "+ \(extraCount) more"
        moreLabel.sizeToFit()
        return moreLabel.frame.width + 15
    }

    func hideNavBar() {
        mapVC.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    @objc func addToSpotTap(_ sender: UIButton) {
        // push camera
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
            
            vc.mapVC = self.mapVC
            vc.spotObject = self.spotObject
            
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromTop
            mapVC.navigationController?.view.layer.add(transition, forKey: kCATransition)
            mapVC.navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    @objc func removeSpotPage(_ sender: UIBarButtonItem) {
        /// pop spot page on back tap
        removeSpotPage(delete: false)
    }
        
    func removeSpotPage(delete: Bool) {
        /// if delete, also exit the child posts page (posts will get deleted with the spot)
        Mixpanel.mainInstance().track(event: "SpotPageRemove")
        
        mapVC.navigationItem.title = ""
        mapVC.navigationItem.rightBarButtonItem = UIBarButtonItem()
        mapVC.navigationItem.leftBarButtonItem = UIBarButtonItem()
        
        active = false
        if editView != nil { exitEditOverview() }
        
        /// reset selectedSpotID and spotViewController for map filtering and drawer animations
        mapVC.selectedSpotID = ""
        mapVC.spotViewController = nil
        mapVC.hideSpotButtons()
        
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        
        if let postVC = parent as? PostViewController {
            postVC.resetView()
            if delete && postVC.postsList.count == 0 { postVC.exitPosts() }
        } else if let nearbyVC = parent as? NearbyViewController {
            nearbyVC.resetView()
        } else if let profileVC = parent as? ProfileViewController {
            mapVC.postsList.removeAll()
            profileVC.resetProfile()
        }
        
        self.removeFromParent()
    }
    
    func removeOnUpload() {
        /// remove spotVC after upload from addToSpot
        if addToSpotButton != nil { addToSpotButton.removeFromSuperview() }
        
        mapVC.navigationItem.leftBarButtonItem = UIBarButtonItem()
        mapVC.selectedSpotID = ""
        mapVC.spotViewController = nil
        
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
    }
    
    func resetView() {

        if self.children.count > 1 { return }
        
        mapVC.spotViewController = self
        mapVC.profileViewController = nil
        mapVC.nearbyViewController = nil
        
        mapVC.postsList = postsList
        mapVC.unhideSpotButtons()
        setUpNavBar()
        resetAnnos()
                
        /// enable / disable scroll
        adjustCollectionSize()

        /// reload table in case all images havent loaded
        if tableView != nil {
            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }
    
    func expandSpot() { /// custom  function on view reset to avoid content offset getting reset
        
        /// set content offset back to 0 to avoid weird scrolling
        if shadowScroll.contentOffset.y == 1 { shadowScroll.contentOffset.y = 0 }
        
        mapVC.prePanY = 0
        mapVC.customTabBar.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height )

        navigationController?.navigationBar.addBackgroundImage(alpha: 1.0)
        navigationController?.navigationBar.addShadow()
        navigationController?.navigationBar.isTranslucent = false
        
        shadowScroll.isScrollEnabled = tableScrollNeeded
        unhideSeparatorLine()
    }
    
    func setUpNavBar() {
        
        mapVC.hideNearbyButtons()
        mapVC.navigationItem.titleView = nil
        
        /// set title to spotName field which is only set when entering from post
        mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
        mapVC.navigationController?.navigationBar.isTranslucent = true
        mapVC.navigationController?.navigationBar.removeShadow()
        mapVC.navigationController?.navigationBar.removeBackgroundImage()
        
        mapVC.navigationItem.title = spotObject == nil ? spotName ?? "" : spotObject.spotName

        let backButton = UIBarButtonItem(image: UIImage(named: "CircleBackButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(removeSpotPage(_:)))
        backButton.imageInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 0)
        mapVC.navigationItem.leftBarButtonItem = backButton
        
        let editButton = UIBarButtonItem(image: UIImage(named: "MoreBarButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(showEditPicker(_:)))
        editButton.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -2)
        mapVC.navigationItem.rightBarButtonItem = editButton
        
        if addToSpotButton != nil { addToSpotButton.isHidden = false }
    }
    
    func resetAnnos() {
        /// add main target annotation and individual posts back to map
        active = true
        
        let annotations = mapVC.mapView.annotations
        mapVC.mapView.removeAnnotations(annotations)
        
        let selectedSpotAnno = MKPointAnnotation()
        let spotCoordinate = CLLocationCoordinate2D(latitude: spotObject.spotLat, longitude: spotObject.spotLong)
        
        selectedSpotAnno.coordinate = spotCoordinate
        mapVC.mapView.addAnnotation(selectedSpotAnno)
        
        for post in self.postsList {
            let annotation = CustomPointAnnotation()
            let lat = post.postLat
            let long = post.postLong
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
            mapVC.mapView.addAnnotation(annotation)
        }
        
        /// reset spot location
        let adjustedCoordinate = CLLocationCoordinate2D(latitude: spotObject.spotLat - 0.001, longitude: spotObject.spotLong)
        mapVC.mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 300, longitudinalMeters: 300), animated: false)
        mapVC.checkPostLocations(spotLocation: CLLocation(latitude: spotObject.spotLat, longitude: spotObject.spotLong))
    }
    
    func adjustCollectionSize() {
        
                
        let width = (UIScreen.main.bounds.width - 10.5) / 3
        let height = width * 1.374
        let numberOfRows = ((postsList.count - 1) / 3) + 1
        let guestbookHeight = (CGFloat(numberOfRows) * height) + 250
        
        let scrollY = guestbookHeight + fullScreenUserHeight + 200
        shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: scrollY)
        
        if guestbookHeight < UIScreen.main.bounds.height {
            tableScrollNeeded = false
            shadowScroll.isScrollEnabled = false
        } else {
            tableScrollNeeded = true
            if mapVC.customTabBar.view.frame.minY == 0 { shadowScroll.isScrollEnabled = true }
        }
        // if guestbook fills full screen, disable tableView scroll in map scroll
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            self.tableView.reloadData()
            self.mapVC.checkForSpotTutorial()
            
            /// animate to full if offset  > 1 (on refresh)
            self.shadowScroll.contentOffset.y > 0 ? self.expandSpot() : self.mapVC.animateToHalfScreen()
        }
    }
    
    func hideSeparatorLine() {
        guard let descriptionCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SpotDescriptionCell else { return }
        descriptionCell.bottomLine.isHidden = true
    }
    
    func unhideSeparatorLine() {
        guard let descriptionCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SpotDescriptionCell else { return }
        descriptionCell.bottomLine.isHidden = false
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //1. override tableView content offset when view isn't completely pulled to the top
        
        if mapVC.prePanY != mapVC.customTabBar.view.frame.minY { return }

        if scrollView.tag != 60 { return }
        
        DispatchQueue.main.async {
            
            guard let collectionCell = self.tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? GuestbookCollectionCell else { return }
                        
            let sec1Height = self.expandUsers ? self.fullScreenUserHeight + self.sec0Height : self.halfScreenUserHeight + self.sec0Height

            if scrollView.contentOffset.y < sec1Height {
                /// scrollView offset hasn't hit the posts collection yet so offset the tableview
                self.tableView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y), animated: false)
                collectionCell.postsCollection.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            } else {
                /// offset posts collection
                self.tableView.setContentOffset(CGPoint(x: 0, y: sec1Height), animated: false)
                collectionCell.postsCollection.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - sec1Height), animated: false)
            }
        }
    }
    
    
    func setUpTable() {
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        sec0Height = 96 - navBarHeight
        
        shadowScroll = UIScrollView(frame: CGRect(x: 0, y: -UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        shadowScroll.backgroundColor = nil
        shadowScroll.isScrollEnabled = false
        shadowScroll.isUserInteractionEnabled = true
        shadowScroll.showsVerticalScrollIndicator = false
        shadowScroll.delegate = self
        shadowScroll.tag = 60
        
        tableView = UITableView(frame: UIScreen.main.bounds)
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        tableView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        view.addSubview(tableView)
        tableView.reloadData()
        
        tableView.register(SpotDescriptionCell.self, forCellReuseIdentifier: "SpotDescription")
        tableView.register(SpotFriendsCollectionCell.self, forCellReuseIdentifier: "SpotFriendsCollectionCell")
        tableView.register(GuestbookCollectionCell.self, forCellReuseIdentifier: "GuestbookCollectionCell")
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 60, width: UIScreen.main.bounds.width, height: 30))
        tableView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        view.addGestureRecognizer(shadowScroll.panGestureRecognizer)
        tableView.removeGestureRecognizer(tableView.panGestureRecognizer)
    }
    
    func postEscape() {
        
        postIndex += 1
        
        if postIndex == spotObject.postIDs.count {
            adjustCollectionSize()
            mapVC.checkPostLocations(spotLocation: CLLocation(latitude: spotObject.spotLat, longitude: spotObject.spotLong))
            mapVC.checkForSpotTutorial()
        }
    }
    
    func getSpotPosts() {
        //sort on timestamp
        guard let spotID = spotObject.id else { return }
        // enter dispatch for each post on get post image, get user info, get comments
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            for doc in self.spotObject.postIDs {
                
                self.db.collection("posts").document(doc).getDocument { [weak self] (post, err) in
                    guard let self = self else { return }
                    /// post escape called every time a post is loaded to the collection
                    
                    do {
                        
                        let postInfo = try post?.data(as: MapPost.self)
                        guard var info = postInfo else { self.postEscape(); return }
                        
                        info.city = self.spotObject.city
                        info.seconds = info.timestamp.seconds
                        info.id = post!.documentID
                        info.spotID = spotID
                        info.spotName = self.spotObject.spotName
                                                
                        if self.spotObject.privacyLevel == "public" {
                            ///if this is a public spot, you shouldn't be able to see posts by people you aren't friends with unless the posts are public
                            if info.privacyLevel == "friends" && info.posterID != self.uid && info.createdBy != self.uid {
                                if !self.mapVC.friendIDs.contains(where: {$0 == info.posterID}) { self.postEscape(); return }
                            }
                        }
                        
                        var urls: [URL] = []
                        for postURL in info.imageURLs {
                            guard let url = URL(string: postURL) else { continue }
                            urls.append(url)
                        }
                        
                        /// get user from users friends list or fetch if not a friend
                        if let user = self.mapVC.friendsList.first(where: {$0.id == info.posterID}) {
                            info.userInfo = user
                            self.getComments(post: info)
                            
                        } else if info.posterID == self.uid {
                            info.userInfo = self.mapVC.userInfo
                            self.getComments(post: info)
                            
                        } else {
                            
                            var userLeaveCalled = false
                            
                            self.listener2 = self.db.collection("users").document(info.posterID).addSnapshotListener({  [weak self] (userSnap, err) in
                                
                                guard let self = self else { return }
                                
                                if err == nil {
                                    do {
                                        let profInfo = try userSnap?.data(as: UserProfile.self)
                                        guard var prof = profInfo else { self.postEscape(); return }
                                        
                                        prof.id = userSnap?.documentID
                                        info.userInfo = prof
                                        
                                        if !userLeaveCalled {
                                            userLeaveCalled = true
                                            self.getComments(post: info)
                                        }
                                        
                                    } catch { self.postEscape(); return }
                                } else { self.postEscape(); return }
                            })
                        }
                    } catch { self.postEscape(); return }
                }
            }
        }
    }
    
    func getComments(post: MapPost) {
        
        var info = post
        var commentList: [MapComment] = []
        var commentCount = 0

        let commentRef = self.db.collection("posts").document(post.id!).collection("comments").order(by: "timestamp", descending: true)

        self.listener3 = commentRef.addSnapshotListener({ [weak self] (commentSnap, err) in
            
            guard let self = self else { return }
            
            let docCount = commentSnap!.documents.count
            if docCount == 0 { self.postEscape(); return }
            
            for doc in commentSnap!.documents {
                
                do {

                    let commInfo = try doc.data(as: MapComment.self)
                    guard var commentInfo = commInfo else { return }
                    
                    commentInfo.id = doc.documentID
                    commentInfo.seconds = commentInfo.timestamp.seconds
                    commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)
                    
                    if !commentList.contains(where: {$0.id == doc.documentID}) {
                        commentList.append(commentInfo)
                        commentList.sort(by: {$0.seconds < $1.seconds})
                    }
                    
                    commentCount += 1; if commentCount == docCount {
                        info.commentList = commentList
                        self.loadPostToCollection(post: info)
                    }

                } catch {
                    commentCount += 1; if commentCount == docCount {
                        info.commentList = commentList
                        self.loadPostToCollection(post: info)
                    }
                    return
                }
            }
        })
    }
    
    func loadPostToCollection(post: MapPost) {
        
        if let index = postsList.firstIndex(where: {$0.id == post.id}) {
            
            postsList[index] = post
            mapVC.postsList = postsList
            DispatchQueue.main.async { self.tableView.reloadData() }
            
        } else {
            /// check that post wasn't recently deleted and still in cache
            if mapVC.deletedPostIDs.contains(post.id ?? "") { postEscape(); return }
            postsList.append(post)
            
            let annotation = CustomPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            postsList.sort(by: {$0.seconds > $1.seconds})
            mapVC.postsList = postsList
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.mapVC.mapView.addAnnotation(annotation)
            }
            
            postEscape()
        }
    }
    
    func openPostPage(index: Int) {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            /// set offset to 1 so spot stays full screen on open
            if self.mapVC.prePanY < 200 {
                if shadowScroll.contentOffset.y == 0 { shadowScroll.setContentOffset(CGPoint(x: 0, y: 1), animated: false)}
            }
            
            cancelDownloads()
            
            vc.postsList = self.postsList
            vc.selectedPostIndex = index
            
            mapVC.spotViewController = nil
            mapVC.hideSpotButtons()
            mapVC.toggleMapTouch(enable: true)
            
            active = false
            vc.mapVC = mapVC
            vc.parentVC = .spot
            vc.spotObject = spotObject
            
            addToSpotButton.isHidden = true
            
            vc.view.frame = UIScreen.main.bounds
            addChild(vc)
            view.addSubview(vc.view)
            vc.didMove(toParent: self)
            
            let infoPass = ["selectedPost": index, "firstOpen": true, "parentVC": PostViewController.parentViewController.spot] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
        }
    }
    
    func openProfile(user: UserProfile) {
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
          
            cancelDownloads()
            addToSpotButton.isHidden = true

            mapVC.customTabBar.tabBar.isHidden = true
            mapVC.spotViewController = nil
            mapVC.hideSpotButtons()
            
            vc.userInfo = user
            vc.mapVC = mapVC
            vc.id = user.id!
            
            vc.view.frame = UIScreen.main.bounds
            addChild(vc)
            view.addSubview(vc.view)
            vc.didMove(toParent: self)
            
        }
    }
    
    @objc func showEditPicker(_ sender: UIButton) {
        
        if spotObject == nil { return }
        let adminView = (spotObject.privacyLevel == "invite" || spotObject.privacyLevel == "friends") && uid == spotObject.founderID
        
        let editHeight: CGFloat = adminView ? 222 : 167
        editView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 112, y: UIScreen.main.bounds.height/2 - 180, width: 224, height: editHeight))
        editView.backgroundColor = UIColor(red: 0.11, green: 0.114, blue: 0.114, alpha: 1)
        
        editView.layer.borderColor = UIColor(red: 0.158, green: 0.158, blue: 0.158, alpha: 1).cgColor
        editView.layer.borderWidth = 1.25
        editView.layer.cornerRadius = 7.5
        
        editMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        editMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapExitEditOverview(_:)))
        tap.delegate = self
        editMask.addGestureRecognizer(tap)
        
        mapVC.view.addSubview(editMask)
        editMask.addSubview(editView)
        
        let postExit = UIButton(frame: CGRect(x: editView.frame.width - 32, y: 2, width: 30, height: 30))
        postExit.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        postExit.setImage(UIImage(named: "CancelButton"), for: .normal)
        postExit.addTarget(self, action: #selector(exitEditOverview(_:)), for: .touchUpInside)
        editView.addSubview(postExit)
        
        let directionsButton = UIButton(frame: CGRect(x: 60, y: 33, width: 102, height: 49))
        directionsButton.setImage(UIImage(named: "SpotPageDirections"), for: .normal)
        directionsButton.addTarget(self, action: #selector(directionsTap(_:)), for: .touchUpInside)
        editView.addSubview(directionsButton)
        
        if adminView {
            let editSpot = UIButton(frame: CGRect(x: 54, y: 93, width: 99.38, height: 49))
            editSpot.setImage(UIImage(named: "SpotPageEditSpot"), for: .normal)
            editSpot.backgroundColor = nil
            editSpot.addTarget(self, action: #selector(editSpotTapped(_:)), for: .touchUpInside)
            editSpot.imageView?.contentMode = .scaleAspectFit
            editView.addSubview(editSpot)
                        
            let deleteButton = UIButton(frame: CGRect(x: 57, y: 152, width: 112, height: 49))
            deleteButton.setImage(UIImage(named: "SpotPageDeleteSpot"), for: UIControl.State.normal)
            deleteButton.backgroundColor = nil
            deleteButton.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
            editView.addSubview(deleteButton)
            
        } else {
            /// add report button
            let reportButton = UIButton(frame: CGRect(x: 51, y: 90, width: 123, height: 49))
            reportButton.setImage(UIImage(named: "ReportSpotButton"), for: .normal)
            reportButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
            reportButton.contentHorizontalAlignment = .center
            reportButton.contentVerticalAlignment = .center
            reportButton.addTarget(self, action: #selector(reportSpotTap(_:)), for: .touchUpInside)
            editView.addSubview(reportButton)
        }
        
        mapVC.navigationController?.navigationBar.isUserInteractionEnabled = false
    }
    
    @objc func directionsTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "SpotGetDirections")
        UIApplication.shared.open(URL(string: "http://maps.apple.com/?daddr=\(spotObject.spotLat),\(spotObject.spotLong)")!)
    }
    
    func presentEditSpot() {
        if let editVC = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "EditSpot") as? EditSpotController {
            editVC.spotVC = self
            editVC.mapVC = self.mapVC
            editVC.spotObject = self.spotObject
            self.present(editVC, animated: true, completion: nil)
        }
    }
    
    @objc func editSpotTapped(_ sender: UIButton) {
        exitEditOverview()
        presentEditSpot()
    }
    
    @objc func tapExitEditOverview(_ sender: UIButton) {
        exitEditOverview()
    }
    
    @objc func exitEditOverview(_ sender: UIButton) {
        exitEditOverview()
    }
    
    func exitEditOverview() {
        for sub in editView.subviews {
            sub.removeFromSuperview()
        }
        editView.removeFromSuperview()
        editMask.removeFromSuperview()
        editView = nil
        mapVC.navigationController?.navigationBar.isUserInteractionEnabled = true
    }
    
    @objc func deleteTapped(_ sender: UIButton) {
        
        sender.isUserInteractionEnabled = false
        exitEditOverview()
        
        let alert = UIAlertController(title: "Delete Spot?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
                                        switch action.style{
                                        case .default:
                                            Mixpanel.mainInstance().track(event: "SpotDelete")
                                            self.makeDeletes()
                                            self.animateToRoot()
                                        case .cancel:
                                            print("cancel")
                                        case .destructive:
                                            print("destruct")
                                        @unknown default:
                                            fatalError()
                                        }}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func animateToRoot() {
        mapVC.navigationController?.navigationBar.isUserInteractionEnabled = true
        removeSpotPage(delete: true)
    }
    
    func removeListeners() {
        if listener1 != nil { listener1.remove() }
        if listener2 != nil { listener2.remove() }
        if listener3 != nil { listener3.remove() }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SpotAddressChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ImageChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UserListRemove"), object: nil)
    }
    
    func makeDeletes() {
        
        let postsCopy = self.postsList
        let spotCopy = self.spotObject!
        sendNotification()

        DispatchQueue.global(qos: .userInitiated).async {
            self.userDelete(spot: spotCopy)
            self.spotNotificationDelete(spot: spotCopy)
            self.postDelete(postsList: postsCopy, spotID: "")
            self.spotDelete(spotID: spotCopy.id!)
        }
    }
        
    
    func sendNotification() {
        /// send spot notis
        mapVC.deletedSpotIDs.append(spotObject.id!)
        let infoPass: [String: Any] = ["spotID": spotObject.id! as Any]
        NotificationCenter.default.post(name: Notification.Name("DeleteSpot"), object: nil, userInfo: infoPass)
        
        /// send post notis
        for post in postsList { mapVC.deletedPostIDs.append(post.id!) }
        let postIDs = postsList.map({$0.id!})
        print("append 1", postIDs)
        let postPass: [String: Any] = ["postIDs": postIDs as Any]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: postPass)
    }
    
    @objc func reportSpotTap(_ sender: UIButton) {
        let alert = UIAlertController(title: "Report spot", message: "Describe why you're reporting this spot:", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addTextField { (textField) in textField.text = "" }
        alert.addAction(UIAlertAction(title: "Report", style: .destructive, handler: { action in
                                        
                                        switch action.style{
                                        
                                        case .default:
                                            return
                                            
                                        case .cancel:
                                            self.exitEditOverview()
                                            
                                        case .destructive:
                                            let textField = alert.textFields![0]
                                            let spotID = self.spotID
                                            self.reportUser(reportedSpot: spotID!, description: textField.text ?? "")

                                        @unknown default:
                                            fatalError()
                                        }}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func reportUser(reportedSpot: String, description: String) {
        
        let db = Firestore.firestore()
        let uuid = UUID().uuidString
        
        db.collection("contact").document(uuid).setData(["type": "report spot", "reporterID" : uid, "reportedSpot": reportedSpot, "description": description])
        
        exitEditOverview()
    }

}

extension SpotViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        //only close view on maskView touch
        if editView != nil && touch.view?.isDescendant(of: editView) == true {
            return false
        }
        return true
    }
}

extension SpotViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return spotObject == nil ? 0 : 3
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.row {
        
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotDescription") as? SpotDescriptionCell else { return UITableViewCell() }
            cell.setUp(spot: spotObject, userLocation: mapVC.currentLocation)
            return cell
            
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotFriendsCollectionCell") as? SpotFriendsCollectionCell else { return UITableViewCell() }
            let height = self.expandUsers ? self.fullScreenUserHeight : self.halfScreenUserHeight
            cell.setUp(friendVisitors: friendVisitors, privacyLevel: spotObject.privacyLevel, halfScreenUserCount: halfScreenUserCount, fullScreenUserCount: fullScreenUserCount, usersMoreNeeded: usersMoreNeeded, expandUsers: expandUsers, collectionHeight: height)
            return cell
            
        case 2:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "GuestbookCollectionCell") as? GuestbookCollectionCell else { return UITableViewCell() }
            cell.setUp(posts: postsList, spotID: self.spotID)
            return cell

        default:
            return UITableViewCell()
            
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return 98
        case 1:
            return expandUsers ? fullScreenUserHeight : halfScreenUserHeight
        case 2:
            return UIScreen.main.bounds.height
        default:
            return 0
        }
    }
}

class SpotDescriptionCell: UITableViewCell {
    
    var pullLine: UIButton!
    var tagView: UIView!
    var spotName: UILabel!
    var cityName: UILabel!
    var separatorView: UIView!
    var distanceLabel: UILabel!
    var bottomLine: UIView!
        
    func setUp(spot: MapSpot, userLocation: CLLocation) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        resetCell()
        
        let pullLine = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 23, y: 0, width: 46, height: 14.5))
        pullLine.contentEdgeInsets = UIEdgeInsets(top: 9, left: 5, bottom: 0, right: 5)
        pullLine.setImage(UIImage(named: "PullLine"), for: .normal)
        pullLine.addTarget(self, action: #selector(lineTap(_:)), for: .touchUpInside)
        addSubview(pullLine)
        
        if !spot.tags.isEmpty {

            tagView = UIView(frame: CGRect(x: 0, y: 15, width: 100, height: 24))
            tagView.backgroundColor = nil
            addSubview(tagView)
            
            var tagX = 14
            
            let tag1 = Tag(name: spot.tags[0])
            let tag1Icon = UIImageView(frame: CGRect(x: tagX, y: 0, width: 24, height: 24))
            tag1Icon.contentMode = .scaleAspectFit
            tag1Icon.image = tag1.image
            tagView.addSubview(tag1Icon)
            
            if spot.tags.count > 1 {
                
                tagX += 28
                
                let tag2 = Tag(name: spot.tags[1])
                let tag2Icon = UIImageView(frame: CGRect(x: tagX, y: 0, width: 24, height: 24))
                tag2Icon.contentMode = .scaleAspectFit
                tag2Icon.image = tag2.image
                tagView.addSubview(tag2Icon)
                
                if spot.tags.count > 2 {
                    
                    tagX += 28
                    
                    let tag3 = Tag(name: spot.tags[2])
                    let tag3Icon = UIImageView(frame: CGRect(x: tagX, y: 0, width: 24, height: 24))
                    tag3Icon.contentMode = .scaleAspectFit
                    tag3Icon.image = tag3.image
                    tagView.addSubview(tag3Icon)
                }
            }
        }
        
        let nameY: CGFloat = tagView == nil ? 28 : 42
        spotName = UILabel(frame: CGRect(x: 14, y: nameY, width: UIScreen.main.bounds.width - 28, height: 18))
        spotName.text = spot.spotName
        spotName.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 17.5)
        addSubview(spotName)
        
        cityName = UILabel(frame: CGRect(x: 14, y: spotName.frame.maxY + 3, width: UIScreen.main.bounds.width - 100, height: 14))
        cityName.text = spot.city ?? ""
        cityName.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        cityName.font = UIFont(name: "SFCamera-Regular", size: 13)
        cityName.sizeToFit()
        addSubview(cityName)
        
        var distanceX: CGFloat = 14
        if cityName.text != "" {
            separatorView = UIView(frame: CGRect(x: cityName.frame.maxX + 9, y: cityName.frame.midY - 0.7, width: 5, height: 2))
            separatorView.backgroundColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
            separatorView.layer.cornerRadius = 0.5
            addSubview(separatorView)
            
            distanceX = separatorView.frame.maxX + 9
        }
        
        let spotLocation = CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)
        let distance = spotLocation.distance(from: userLocation)
        
        distanceLabel = UILabel(frame: CGRect(x: distanceX, y: spotName.frame.maxY + 3, width: UIScreen.main.bounds.width - distanceX - 14, height: 14))
        distanceLabel.text = distance.getLocationString()
        distanceLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        distanceLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        distanceLabel.sizeToFit()
        addSubview(distanceLabel)
        
        bottomLine = UIView(frame: CGRect(x: 0, y: 88, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1)
        addSubview(bottomLine)
    }
    
    func resetCell() {
        if pullLine != nil { pullLine.setImage(UIImage(), for: .normal) }
        if tagView != nil { for sub in tagView.subviews { sub.removeFromSuperview() } }
        if spotName != nil { spotName.text = "" }
        if cityName != nil { cityName.text = "" }
        if distanceLabel != nil { distanceLabel.text = "" }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
    
    @objc func lineTap(_ sender: UIButton) {
        guard let spotVC = viewContainingController() as? SpotViewController else { return }
        spotVC.mapVC.animateToFullScreen()
    }
}

class SpotFriendsCollectionCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    var usersCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var friendVisitors: [UserProfile] = []
    var privacyLevel = ""
    var halfScreenUserCount = 0, fullScreenUserCount = 0
    var usersMoreNeeded = false
    var expandUsers = false
    
    func setUp(friendVisitors: [UserProfile], privacyLevel: String, halfScreenUserCount: Int, fullScreenUserCount: Int, usersMoreNeeded: Bool, expandUsers: Bool, collectionHeight: CGFloat) {
        
        self.selectionStyle = .none
        self.backgroundColor = UIColor(named: "SpotBlack")
        
        self.friendVisitors = friendVisitors
        self.privacyLevel = privacyLevel
        self.halfScreenUserCount = halfScreenUserCount
        self.fullScreenUserCount = fullScreenUserCount
        self.usersMoreNeeded = usersMoreNeeded
        self.expandUsers = expandUsers
        
        let usersLayout = LeftAlignedCollectionViewFlowLayout()
        usersLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 33)

        usersCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: collectionHeight)
        usersCollection.contentInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        usersCollection.delegate = self
        usersCollection.dataSource = self
        usersCollection.backgroundColor = nil
        usersCollection.register(SpotFriendsHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SpotFriendsHeader")
        usersCollection.register(SpotFriendsCell.self, forCellWithReuseIdentifier: "SpotFriendsCell")
        usersCollection.register(SpotPageMoreCell.self, forCellWithReuseIdentifier: "SpotPageMoreCell")
        usersCollection.isScrollEnabled = false
        usersCollection.bounces = false
        self.addSubview(usersCollection)
        
        usersCollection.reloadData()
        usersCollection.setCollectionViewLayout(usersLayout, animated: false)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return expandUsers ? fullScreenUserCount : halfScreenUserCount
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        /// add more button for halfscreen view with user overflow
        if indexPath.row == halfScreenUserCount - 1 && usersMoreNeeded && !expandUsers {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotPageMoreCell", for: indexPath) as? SpotPageMoreCell else { return UICollectionViewCell() }
            let trueHalf = usersMoreNeeded ? halfScreenUserCount - 1 : halfScreenUserCount
            cell.setUp(count: fullScreenUserCount - trueHalf)
            return cell
        }
        
        /// regular user cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotFriendsCell", for: indexPath) as? SpotFriendsCell else { return UICollectionViewCell() }
        guard let user = friendVisitors[safe: indexPath.row] else { return cell }
        cell.setUp(user: user)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if indexPath.row == halfScreenUserCount - 1 && usersMoreNeeded && !expandUsers {
            /// add +more button if users aren't going to fit on 2 lines for this section, and hasn't already been expanded
            let moreWidth = getMoreWidth(extraCount: fullScreenUserCount - halfScreenUserCount)
            return CGSize(width: moreWidth, height: 24)
        }
        
        guard let user = friendVisitors[safe: indexPath.row] else { return CGSize(width: 0, height: 0) }
        let width = getWidth(name: user.username)
        
        return CGSize(width: width, height: 24)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SpotFriendsHeader", for: indexPath) as? SpotFriendsHeader else { return UICollectionReusableView() }
        header.setUp(friendCount: friendVisitors.count, privacyLevel: privacyLevel)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let spotVC = self.viewContainingController() as? SpotViewController else { return }
        if spotVC.mapVC.prePanY < 200 { spotVC.shadowScroll.setContentOffset(CGPoint(x: 0, y: 1), animated: false)}
        
        if collectionView.cellForItem(at: indexPath) is SpotFriendsCell {
            
            guard let user = friendVisitors[safe: indexPath.row] else { return }
            
            spotVC.openProfile(user: user)
            
        } else {

            guard let spotVC = self.viewContainingController() as? SpotViewController else { return }
            /// more button tap -> expand to full and resize section
            spotVC.expandUsers = true
            if spotVC.mapVC.prePanY != 0 {
                spotVC.mapVC.animateSpotToFull(forceRefresh: true)
            } else {
                spotVC.resizeTable(halfScreen: false, forceRefresh: true)
            }
        }
    }
    
    func getWidth(name: String) -> CGFloat {
            
        let username = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 16))
        username.text = name
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.sizeToFit()
        return 30 + username.frame.width
    }
    
    func getMoreWidth(extraCount: Int) -> CGFloat {
        
        let moreLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 16))
        moreLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        moreLabel.text = "+ \(extraCount) more"
        moreLabel.sizeToFit()
        
        return moreLabel.frame.width + 15
    }
    
    override func prepareForReuse() {
        
        /// collection was getting readded and not removing cells 
        for cell in usersCollection.visibleCells {
            guard let cell = cell as? SpotFriendsCell else { return }
            if cell.username != nil { cell.username.text = "" }
            if cell.profilePic != nil { cell.profilePic.image = UIImage() }
        }
        
        guard let header = usersCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? SpotFriendsHeader else { return }
        if header.label != nil { header.label.text = "" }
        if header.privacyIcon != nil { header.privacyIcon.image = UIImage() }
        
        usersCollection = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    }
}

class SpotFriendsHeader: UICollectionReusableView {
    
    var label: UILabel!
    var privacyIcon: UIImageView!
    
    func setUp(friendCount: Int, privacyLevel: String) {
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 0, y: 7, width: 200, height: 16))
        label.text = "\(friendCount) friend"
        if friendCount != 1 { label.text! += "s" }
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 12)
        label.sizeToFit()
        addSubview(label)
        
        if privacyIcon != nil { privacyIcon.image = UIImage() }
        
        switch privacyLevel {
        
        case "friends":
            privacyIcon = UIImageView(frame: CGRect(x: label.frame.maxX + 7, y: 4, width: 98, height: 19))
            privacyIcon.image = UIImage(named: "SpotPageFriends")
        case "invite":
            privacyIcon = UIImageView(frame: CGRect(x: label.frame.maxX + 7, y: 4, width: 68, height: 19))
            privacyIcon.image = UIImage(named: "SpotPagePrivate")
        default:
            return
        }
        
        addSubview(privacyIcon)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class SpotPageMoreCell: UICollectionViewCell {
    
    var label: UILabel!
    
    func setUp(count: Int) {
        
        backgroundColor = nil
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 0, y: 3, width: 100, height: 16))
        label.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        label.text = "+ \(count) more"
        label.textColor = UIColor(named: "SpotGreen")
        label.sizeToFit()
        addSubview(label)
    }
}

class SpotFriendsCell: UICollectionViewCell {
    
    var profilePic: UIImageView!
    var username: UILabel!
    
    func setUp(user: UserProfile) {
        
        backgroundColor = nil
        
        if profilePic != nil { profilePic.image = UIImage() }
        profilePic = UIImageView(frame: CGRect(x: 0, y: 0, width: 22, height: 22))
        profilePic.layer.cornerRadius = 11
        profilePic.layer.masksToBounds = true
        profilePic.contentMode = .scaleAspectFill
        self.addSubview(profilePic)
        
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        if username != nil { username.text = "" }
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 6, y: 3, width: self.bounds.width - 28, height: 16))
        username.text = user.username
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        username.sizeToFit()
        self.addSubview(username)
    }
    
    override func prepareForReuse() {
        /// cancel image fetch when cell leaves screen
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}


class GuestbookCollectionCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    
    lazy var postsList: [MapPost] = []
    let postsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    var spotID: String!
    
    func setUp(posts: [MapPost], spotID: String) {
        
        postsList = posts
        self.spotID = spotID
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        layout.scrollDirection = .vertical
        let width = (UIScreen.main.bounds.width - 10.5) / 3
        let height = width * 1.374
        
        layout.itemSize = CGSize(width: width, height: height)
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        layout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 29)
        
        postsCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        postsCollection.setCollectionViewLayout(layout, animated: false)
        postsCollection.delegate = self
        postsCollection.dataSource = self
        postsCollection.showsVerticalScrollIndicator = false
        postsCollection.backgroundColor = nil
        postsCollection.register(SpotPostsHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SpotPostsHeader")
        postsCollection.register(GuestbookCell.self, forCellWithReuseIdentifier: "GuestbookCell")
        postsCollection.isScrollEnabled = false
        postsCollection.bounces = false
        self.addSubview(postsCollection)
        
        postsCollection.removeGestureRecognizer(postsCollection.panGestureRecognizer)
        
        DispatchQueue.main.async { self.postsCollection.reloadData() }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return postsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GuestbookCell", for: indexPath) as? GuestbookCell else { return UICollectionViewCell() }
        
        if let post = postsList[safe: indexPath.row] {
            cell.setUp(post: post)
        }
            
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SpotPostsHeader", for: indexPath) as? SpotPostsHeader else { return UICollectionReusableView() }
        header.setUp(postCount: postsList.count)
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let spotVC = self.viewContainingController() as? SpotViewController {
            spotVC.openPostPage(index: indexPath.row)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        guard let cell = cell as? GuestbookCell else { return }
        guard let post = postsList[safe: indexPath.row] else { return }
        
        if cell.cachedImage.postID == post.id! && cell.cachedImage.image != UIImage() {
            cell.imagePreview.image = cell.cachedImage.image
            return
        }
        
        cell.imagePreview.image = UIImage()

        guard let url = post.imageURLs.first else { return }
        if url == "" { return }
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 300, height: 300), scaleMode: .aspectFill)
        cell.imagePreview.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, _, _, _) in
            if image != nil { cell.cachedImage.image = image!}
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        guard let cell = cell as? GuestbookCell else { return }
        guard let post = postsList[safe: indexPath.row] else { return }
        cell.cachedImage.postID = post.id!
        cell.imagePreview.sd_cancelCurrentImageLoad()
    }
}

class GuestbookCell: UICollectionViewCell {
    
    var postID: String!
    lazy var cachedImage: ((image: UIImage, postID: String)) = ((UIImage(), ""))
    lazy var imagePreview = UIImageView()
    
    func setUp(post: MapPost) {
        
        postID = post.id!
        
        self.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.00)
        self.layer.cornerRadius = 3
        self.clipsToBounds = true
        
        imagePreview.frame = self.bounds
        imagePreview.contentMode = .scaleAspectFill
        imagePreview.clipsToBounds = true
        self.addSubview(imagePreview)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}


class SpotPostsHeader: UICollectionReusableView {
    
    var label: UILabel!
    
    func setUp(postCount: Int) {
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 14, y: 3, width: 100, height: 16))
        label.text = "\(postCount) post"
        if postCount != 1 { label.text! += "s" }
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 12)
        addSubview(label)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
