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
    let db: Firestore! = Firestore.firestore()

    var spotID: String!
    var spotObject: MapSpot!
    var spotName: String!
    
    lazy var memberList: [UserProfile] = [] /// full profiles for visitorList (friends/public) or inviteList (invite)
    lazy var postsList: [MapPost] = []
    lazy var guestbookPreviews: [GuestbookPreview] = []
    lazy var postDates: [(date: String, seconds: Int64)] = []
    
    lazy var shadowScroll = UIScrollView() /// receives all touch events to allow for smooth scrolling between segments
    lazy var tableView = UITableView()
    var addToSpotButton: UIButton!
    var activityIndicator: CustomActivityIndicator!
    
    unowned var mapVC: MapViewController!
    
    var sec0Height: CGFloat = 0
    lazy var postIndex = 0
    var visitorIndex = 0
    var escapeIndex = 0
    var selectedIndex = 0
    
    var editMask: UIView!
    var editView: UIView!
    var editedSpot: MapSpot!
    var editSpotMode = false
    var editedImage = false /// determines whether edit controller should update the cover image in DB
    var openOnUpload = false /// bool to tell view to reset annotations on upload (patch fix)
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(notifyImageChange(_:)), name: NSNotification.Name("EditImageChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name("NewPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditPost(_:)), name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeletePost(_:)), name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUsersChange(_:)), name: NSNotification.Name("UserListRemove"), object: nil)
    }
    
    private lazy var spotPostsController: SpotPostsViewController = {
        let storyboard = UIStoryboard(name: "SpotPage", bundle: Bundle.main)
        var vc = storyboard.instantiateViewController(withIdentifier: "SpotPosts") as! SpotPostsViewController
        vc.spotVC = self
        vc.mapVC = mapVC
        self.addChild(vc)
        return vc
    }()
    
    private lazy var spotVisitorsController: SpotVisitorsViewController = {
        let storyboard = UIStoryboard(name: "SpotPage", bundle: Bundle.main)
        var vc = storyboard.instantiateViewController(withIdentifier: "SpotVisitors") as! SpotVisitorsViewController
        vc.spotVC = self
        vc.mapVC = mapVC
        self.addChild(vc)
        return vc
    }()
    
    private func remove(asChildViewController viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
    private func add(asChildViewController viewController: UIViewController) {
        addChild(viewController)
        viewController.didMove(toParent: self)
    }


    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if children.count > 2 { return } /// edge case if entering from background or from edit location
        
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
        if addToSpotButton != nil { addToSpotButton.isHidden = true }
        cancelDownloads()
    }
    
    func cancelDownloads() {
        spotPostsController.cancelDownloads()
        spotVisitorsController.cancelDownloads()
    }
    
    func runInitialFuncs() {
        
        if mapVC.userInfo == nil { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.getVisitorInfo(refresh: false)
            self.getSpotPosts()
        }
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
                
                self.present(editVC, animated: false, completion: nil)
                self.editedSpot = nil
                self.editedImage = true
            }
        }
    }
    
    @objc func notifyNewPost(_ sender: NSNotification) {
        /// new post on post upload
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            
            var post = newPost
            post.seconds = post.actualTimestamp?.seconds ?? post.timestamp.seconds /// adjust seconds to reflect spot page sorting
            postsList.append(post)
            postsList.sort(by: {$0.seconds > $1.seconds})

            
            var frameIndexes = post.frameIndexes ?? []
            if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }

            let date = getDateTimestamp(seconds: post.seconds)
            for i in 0...frameIndexes.count - 1 { guestbookPreviews.append(GuestbookPreview(postID: post.id!, frameIndex: frameIndexes[i], imageIndex: i, imageURL: post.imageURLs[frameIndexes[i]], seconds: post.seconds, date: date)) }
            guestbookPreviews.sort(by: {$0.seconds > $1.seconds})

            updatePostDates(date: date, seconds: post.seconds)
            
            self.tableView.reloadData()
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
                
                let postDate = getDateTimestamp(seconds: postsList[index].actualTimestamp?.seconds ?? postsList[index].seconds)
                
                self.postsList.remove(at: index)
                self.postsList.sort(by: {$0.seconds > $1.seconds})
                
                /// remove date section if this was the only post with that date
                var removeDate = true
                for post in postsList { if getDateTimestamp(seconds: post.actualTimestamp?.seconds ?? post.seconds) == postDate { removeDate = false } }
                if removeDate { self.postDates.removeAll(where: { $0.date == postDate })}
                
                self.guestbookPreviews.removeAll(where: {$0.postID == postID})
                guestbookPreviews.sort(by: {$0.seconds > $1.seconds})
                
                self.tableView.reloadData()
                if postsList.count == 0 { return } /// cancel post page funcs on spotDelete
                
                if let postVC = self.children.first(where: {$0.isKind(of: PostViewController.self)}) as? PostViewController {
                    
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
        /// only user post deleted from feed
        memberList.removeAll(where: {$0.id == uid})
        if selectedIndex == 1 { DispatchQueue.main.async { self.spotVisitorsController.visitorsCollection.reloadData() } }
    }
    
    func newPostReset(tags: [String]) {
        /// new post (hide from feed)
        spotObject.tags = tags
        if !spotObject.visitorList.contains(uid) { spotObject.visitorList.append(uid) }
        memberList.removeAll()
        getVisitorInfo(refresh: true)
    }
    
    func addAddToSpot() {
        
        ///add addToSpot button over the top of custom tab bar
        let addY = mapVC.largeScreen ? UIScreen.main.bounds.height - 89 : UIScreen.main.bounds.height - 74
        let addX = mapVC.largeScreen ? UIScreen.main.bounds.width - 73 : UIScreen.main.bounds.width - 69
        addToSpotButton = UIButton(frame: CGRect(x: addX, y: addY, width: 55, height: 55))
        addToSpotButton.setImage(UIImage(named: "AddToSpotButton"), for: .normal)
        addToSpotButton.addTarget(self, action: #selector(addToSpotTap(_:)), for: .touchUpInside)
        addToSpotButton.isHidden = selectedIndex == 1 || children.count > 2
        mapVC.view.addSubview(addToSpotButton)
        
        /// patch fix for annotations disappearing on hide from feed uploads
       if !mapVC.mapView.annotations.isEmpty && openOnUpload {
            openOnUpload = false
            let annotations = mapVC.mapView.annotations
            mapVC.mapView.removeAnnotations(annotations)
            mapVC.mapView.addAnnotations(annotations)
        }
    }
    
    func getVisitorInfo(refresh: Bool) {
        
        // get visitors for this spot
        visitorIndex = 0
        let list = spotObject.privacyLevel == "invite" ? spotObject.inviteList ?? [] : spotObject.visitorList
        
        for visitor in list {
            
            /// get visitor from user friendsList
            if let user = self.mapVC.friendsList.first(where: {$0.id == visitor}) {
                memberList.append(user)
                visitorEscape(refresh: refresh)
                
            /// get visitor from userInfo
            } else if visitor == uid {
                memberList.append(mapVC.userInfo)
                visitorEscape(refresh: refresh)
                
            } else {
                /// get visitor from db
                db.collection("users").document(visitor).getDocument{  [weak self] (userSnap, err) in
                    
                    guard let self = self else { return }
                    
                    if err == nil {
                        do {
                            let profInfo = try userSnap?.data(as: UserProfile.self)
                            guard var prof = profInfo else { self.postEscape(); return }
                            
                            prof.id = userSnap?.documentID
                            self.memberList.append(prof)
                            self.visitorEscape(refresh: refresh)
                            
                        } catch { self.visitorEscape(refresh: refresh); return }
                    } else { self.visitorEscape(refresh: refresh); return }
                }
            }
        }
    }
    
    func visitorEscape(refresh: Bool) {
        visitorIndex += 1
        if visitorIndex == spotObject.visitorList.count {
            if refresh && selectedIndex == 1 { DispatchQueue.main.async { self.spotVisitorsController.visitorsCollection.reloadData() }; return }
            escapeIndex += 1
            if escapeIndex == 2 { finishLoad() }
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
        moreLabel.font = UIFont(name: "SFCamera-Regular", size: 11.5)
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
    
    @objc func rightSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex == 1 {
            guard let header = tableView.headerView(forSection: 1) as? SpotSegHeader else { return }
            header.animateBar(index: 0)
        }
    }
    
    @objc func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex == 0 {
            guard let header = tableView.headerView(forSection: 1) as? SpotSegHeader else { return }
            header.animateBar(index: 1)
        }
    }
    
    func scrollSegmentToTop() {
        
        if mapVC.prePanY != 0 { return }
        
        if shadowScroll.contentOffset.y > sec0Height {
                        
            UIView.animate(withDuration: 0.2) {
                self.selectedIndex == 0 ? self.spotPostsController.postsCollection.setContentOffset(CGPoint(x: self.spotPostsController.postsCollection.contentOffset.x, y: 0), animated: false) : self.spotVisitorsController.visitorsCollection.setContentOffset(CGPoint(x: self.spotVisitorsController.visitorsCollection.contentOffset.x, y: 0), animated: false)
            } completion: { [weak self] (_) in
                guard let self = self else { return }
                self.shadowScroll.setContentOffset(CGPoint(x: self.shadowScroll.contentOffset.x, y: self.sec0Height), animated: false)
            }
        }
    }
    
    func animateRemoveSpot() {
        Mixpanel.mainInstance().track(event: "SpotPageSwipeToExit")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2) { [weak self] in
                guard let self = self else { return }
                self.view.frame = CGRect(x: UIScreen.main.bounds.width, y: self.view.frame.minY, width: self.view.frame.width, height: self.view.frame.height)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.removeSpotPage(delete: false)
            }
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
        
        if editView != nil { exitEditOverview() }
        
        /// reset selectedSpotID and spotViewController for map filtering and drawer animations
        mapVC.selectedSpotID = ""
        mapVC.spotViewController = nil
        mapVC.hideSpotButtons()
        
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        
        if let postVC = parent as? PostViewController {
            postVC.resetView()
            postVC.tableView.reloadData() 
            if delete && postVC.postsList.count == 0 { postVC.exitPosts() }
        } else if let nearbyVC = parent as? NearbyViewController {
            nearbyVC.resetView()
        } else if let profileVC = parent as? ProfileViewController {
            mapVC.postsList.removeAll()
            profileVC.resetProfile()
        } else if let notificationsVC = parent as? NotificationsViewController {
            mapVC.postsList.removeAll()
            notificationsVC.resetView()
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
        
        mapVC.selectedSpotID = spotID ?? ""
        mapVC.spotViewController = self
        mapVC.profileViewController = nil
        mapVC.nearbyViewController = nil
        
        mapVC.postsList = postsList
        setUpNavBar()
        resetAnnos()
                
        DispatchQueue.main.async {
            /// enable / disable scroll + animate
           self.resetTableView()
            /// reload table in case all images havent loaded
           self.selectedIndex == 0 ? self.spotPostsController.resetView() : self.spotVisitorsController.resetView()
        }
    }
    
    func expandSpot() { /// custom function on view reset to avoid content offset getting reset
        
        /// set content offset back to 0 to avoid weird scrolling
        if shadowScroll.contentOffset.y == 1 { shadowScroll.contentOffset.y = 0 }
        
        navigationController?.navigationBar.addBackgroundImage(alpha: 1.0)
        navigationController?.navigationBar.removeShadow()
        navigationController?.navigationBar.isTranslucent = false
        
        mapVC.prePanY = 0
        
        shadowScroll.isScrollEnabled = true
        
        UIView.animate(withDuration: 0.15) {
            print("offset", self.shadowScroll.contentOffset.y)
            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height )
        }
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
        
        if addToSpotButton != nil && selectedIndex == 0 { addToSpotButton.isHidden = false }
    }
    
    func resetAnnos() {
        
        /// add main target annotation and individual posts back to map
        
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
    
    func resetTableView() {
        shadowScroll.isScrollEnabled = true
        DispatchQueue.main.async {  self.shadowScroll.contentOffset.y > 0 ? self.expandSpot() : self.mapVC.animateToHalfScreen() }
    }
    

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // override tableView content offset when view isn't completely pulled to the top
        
        if mapVC.prePanY != mapVC.customTabBar.view.frame.minY { return }
        if scrollView.tag != 60 { return }
        if selectedIndex == 0 && spotPostsController.children.count > 0 { return }
        if selectedIndex == 1 && spotVisitorsController.children.count > 0 { return }

        setContentOffsets()
    }
    
    func setContentOffsets() {
        print("set content offsets ")
        if !(self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) is SpotSegCell) { return }
        
        DispatchQueue.main.async {
            self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.sec0Height), animated: false)
            
            switch self.selectedIndex {
            
            case 0:
                self.spotPostsController.postsCollection.setContentOffset(CGPoint(x: self.spotPostsController.postsCollection.contentOffset.x, y: self.shadowScroll.contentOffset.y - self.sec0Height), animated: false)

            case 1:
                self.spotVisitorsController.visitorsCollection.setContentOffset(CGPoint(x: self.spotVisitorsController.visitorsCollection.contentOffset.x, y: self.shadowScroll.contentOffset.y - self.sec0Height), animated: false)
                
            default: return

            }
        }
        
    }
    
    func resetIndex(index: Int) {
        
        let minY = mapVC.prePanY == 0 ? sec0Height : 0

        if index == 0 {
            DispatchQueue.main.async {
                self.remove(asChildViewController: self.spotPostsController)
                self.add(asChildViewController: self.spotVisitorsController)
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: minY), animated: false)
                if self.addToSpotButton != nil { self.addToSpotButton.isHidden = false }
                
                ///reset content offsets so scroll stays smooth
                if self.spotPostsController.postsCollection.contentOffset.y > 0 || self.spotVisitorsController.visitorsCollection.contentOffset.y > 0  {
                    self.shadowScroll.contentOffset.y = self.sec0Height + self.spotPostsController.postsCollection.contentOffset.y
                }
            }
            
        } else {
            DispatchQueue.main.async {
            
                self.remove(asChildViewController: self.spotPostsController)
                self.add(asChildViewController: self.spotVisitorsController)
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: minY), animated: false)
                if self.addToSpotButton != nil { self.addToSpotButton.isHidden = true }

                ///reset content offsets so scroll stays smooth
                if self.spotPostsController.postsCollection.contentOffset.y > 0 || self.spotVisitorsController.visitorsCollection.contentOffset.y > 0  {
                    self.shadowScroll.contentOffset.y = self.sec0Height + self.spotVisitorsController.visitorsCollection.contentOffset.y
                }
            }
        }
        
        selectedIndex = index
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    
    
    func setUpTable() {
                
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        sec0Height = 93 - navBarHeight
        
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
        tableView.register(SpotSegHeader.self, forHeaderFooterViewReuseIdentifier: "SpotSegHeader")
        tableView.register(SpotSegCell.self, forCellReuseIdentifier: "SpotSegCell")
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 90, width: UIScreen.main.bounds.width, height: 30))
        tableView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
                
        view.addGestureRecognizer(shadowScroll.panGestureRecognizer)
        tableView.removeGestureRecognizer(tableView.panGestureRecognizer)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(rightSwipe(_:)))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(leftSwipe(_:)))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)
    }
    
    func postEscape() {
        postIndex += 1
        if postIndex == spotObject.postIDs.count {
            escapeIndex += 1
            if escapeIndex == 2 { finishLoad() }
        }
    }
    
    func finishLoad() {

        /// add user info to spotsList
        for i in 0...postsList.count - 1 { postsList[i].userInfo = memberList.first(where: {$0.id == postsList[i].posterID})}
        
        mapVC.checkPostLocations(spotLocation: CLLocation(latitude: spotObject.spotLat, longitude: spotObject.spotLong))

        /// reload table
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            if self.children.count == 0 { self.add(asChildViewController: self.spotPostsController) } /// initial add func
            self.activityIndicator.stopAnimating()
            self.mapVC.checkForTutorial(index: 1)
            self.tableView.reloadData()
        }
    }
    
    func getSpotPosts() {
        //sort on timestamp
        guard let _ = spotObject.id else { return }
        postIndex = 0
        
        for doc in self.spotObject.postIDs {
            
            self.db.collection("posts").document(doc).getDocument { [weak self] (post, err) in

                guard let self = self else { return }

                /// post escape called every time a post is loaded to the collection
                do {
                    
                    let postInfo = try post?.data(as: MapPost.self)
                    guard var info = postInfo else { self.postEscape(); return }
                    
                    info.seconds = info.actualTimestamp?.seconds ?? info.timestamp.seconds
                    info.id = post!.documentID
                    
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
                    self.getComments(post: info)
                    
                } catch { self.postEscape(); return }
            }
        }
        
    }
    
    func getComments(post: MapPost) {
        
        var info = post
        var commentList: [MapComment] = []
        var commentCount = 0

        let commentRef = self.db.collection("posts").document(post.id!).collection("comments").order(by: "timestamp", descending: true)

        commentRef.getDocuments{ [weak self] (commentSnap, err) in
            
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
        }
    }
    
    func loadPostToCollection(post: MapPost) {
        
        /// update existing post from active listener
        if let index = postsList.firstIndex(where: {$0.id == post.id}) {
            
            postsList[index] = post
            mapVC.postsList = postsList
            DispatchQueue.main.async { self.tableView.reloadData() }
            
        /// add new post
        } else {
            /// check that post wasn't recently deleted and still in cache
            if mapVC.deletedPostIDs.contains(post.id ?? "") { postEscape(); return }
            postsList.append(post)
            
            let postDate = getDateTimestamp(seconds: post.actualTimestamp?.seconds ?? post.seconds)
            updatePostDates(date: postDate, seconds: post.seconds)
            
            var frameIndexes = post.frameIndexes ?? []
            if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }

            for i in 0...frameIndexes.count - 1 { guestbookPreviews.append(GuestbookPreview(postID: post.id!, frameIndex: frameIndexes[i], imageIndex: i, imageURL: post.imageURLs[frameIndexes[i]], seconds: post.seconds, date: postDate)) }
            guestbookPreviews.sort(by: {$0.seconds > $1.seconds})
            
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
    
    func updatePostDates(date: String, seconds: Int64) {
        
        if let temp = postDates.last(where: {$0.date == date}) {
            /// new most recent post with this date
            if seconds > temp.seconds {
                postDates.removeAll(where: {$0.date == date})
                postDates.append((date: date, seconds: seconds))
            }
        } else { postDates.append((date: date, seconds: seconds)) }
        
        postDates.sort(by: {$0.seconds > $1.seconds})
    }
    
    func openProfile(user: UserProfile) {
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
         
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

        
    func launchFriendsPicker() {
        
        if let inviteVC = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "InviteFriends") as? InviteFriendsController {
            
            inviteVC.spotVC = self
            var noBotList = mapVC.friendsList
            noBotList.removeAll(where: {$0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"})
            
            inviteVC.friendsList = noBotList
            inviteVC.queryFriends = noBotList

            if spotObject.privacyLevel == "invite" {
                for invite in spotObject.inviteList ?? [] {
                    if let friend = mapVC.friendsList.first(where: {$0.id == invite}) {
                        inviteVC.selectedFriends.append(friend)
                    }
                }
                
            } else {
                for visitor in spotObject.visitorList {
                    if let friend = mapVC.friendsList.first(where: {$0.id == visitor}) {
                         inviteVC.selectedFriends.append(friend)
                    }
                }
            }
            
            self.present(inviteVC, animated: true, completion: nil)
        }
    }
    
    func updateUserList(initialList: [String]) {
        
        /// 1. grab users not included in initial list
        let newList = spotObject.privacyLevel == "invite" ? spotObject.inviteList! : spotObject.visitorList
        let newUsers = newList.filter({!initialList.contains($0)})
        let oldUsers = initialList.filter({!newList.contains($0)})

        /// 2. update visitorList for friends spot, inviteList for invite spot
        var values: [String: Any] = [:]
        if spotObject.privacyLevel == "invite" { values["inviteList"] = newList } else { values["visitorList"] = newList }
        db.collection("spots").document(spotID).updateData(values)
        
        /// 4. add to new users spots list, send notification
        for user in newUsers { sendInviteNotification(user: user) }
        
        /// 5. remove from removed users spots list
        for user in oldUsers { removeSpotNotifications(user: user) }
        
        let increment = newUsers.count - oldUsers.count
        if increment > 0 { DispatchQueue.global(qos: .utility).async { self.incrementSpotScore(user: self.uid, increment: increment) } }
        
        NotificationCenter.default.post(Notification(name: Notification.Name("EditSpot"), object: nil, userInfo: ["spot" : spotObject as Any])) /// send edit notifications to update spot objects throughout the app
    }
    
    func sendInviteNotification(user: String) {
        
        if user == uid { return }
        let interval = NSDate().timeIntervalSince1970
        let timestamp = NSDate(timeIntervalSince1970: TimeInterval(interval))
        
        /// update users spotsList
        db.collection("users").document(user).collection("spotsList").document(spotID!).setData(["spotID" : spotID!, "checkInTime" : timestamp, "postsList" : [], "city": spotObject.city ?? ""], merge: true)

        let notiID = UUID().uuidString
        let notificationRef = db.collection("users").document(user).collection("notifications")
        let acceptRef = notificationRef.document(notiID)
        
        let notiValues = ["seen" : false, "timestamp" : timestamp, "senderID": uid, "type": "invite", "spotID": spotID!, "postID" : postsList.last!.id!, "imageURL": spotObject.imageURL, "spotName": spotObject.spotName] as [String : Any]
        
        acceptRef.setData(notiValues)
        
        let sender = PushNotificationSender()
        var token: String!
        
        db.collection("users").document(user).getDocument { [weak self] (tokenSnap, err) in
            guard let self = self else { return }
            if (tokenSnap == nil) { return }
            token = tokenSnap?.get("notificationToken") as? String
            if (token != nil && token != "") {
                sender.sendPushNotification(token: token, title: "", body: "\(self.mapVC.userInfo.username) added you to a spot")
            }
        }
    }
    
    func removeSpotNotifications(user: String) {
        
        let notiRef = db.collection("users").document(user).collection("notifications")
        let query = notiRef.whereField("spotID", isEqualTo: spotID!)
        
        query.getDocuments { (querysnapshot, err) in
            for doc in querysnapshot!.documents { doc.reference.delete() }
        }
        
        /// delete from users spots list
        db.collection("users").document(user).collection("spotsList").document(spotID).delete()
    }
    
     func openPostPage(postID: String, imageIndex: Int) {
         
         if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
             
             /// set offset to 1 so spot stays full screen on open
             if self.mapVC.prePanY < 200 {
                 if shadowScroll.contentOffset.y == 0 { shadowScroll.setContentOffset(CGPoint(x: 0, y: 1), animated: false)}
             }
             
             cancelDownloads()
             
             let index = postsList.firstIndex(where: {$0.id == postID}) ?? 0
             vc.postsList = self.postsList
             vc.postsList[index].selectedImageIndex = imageIndex
             vc.selectedPostIndex = index
             /// set frame index and go to that image
             
             mapVC.spotViewController = nil
             mapVC.hideSpotButtons()
             mapVC.toggleMapTouch(enable: true)
             
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

    
    @objc func showEditPicker(_ sender: UIButton) {
        // show edit / directions / delete menu
        if spotObject == nil { return }
        let adminView = ((spotObject.privacyLevel == "invite" || spotObject.privacyLevel == "friends") && uid == spotObject.founderID) || uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" /// give bot edit access to all spots
        
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
        /// exit exit overview always called to remove mask and enable main view again
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
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SpotAddressChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("EditImageChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("NewPost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UserListRemove"), object: nil)
    }
    
    func makeDeletes() {
        /// local objects to stay alive on spot page remove
        let postsCopy = self.postsList
        let spotCopy = self.spotObject!
        sendNotification() /// send deelte notifications to other VCs

        DispatchQueue.global(qos: .userInitiated).async {
            self.userDelete(spot: spotCopy) /// delete from users spot list
            self.spotNotificationDelete(spot: spotCopy) /// delete all notifications pertaining to this spot
            self.postDelete(postsList: postsCopy, spotID: "") /// delete spot posts
            self.spotDelete(spotID: spotCopy.id!) /// delete spot
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
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return spotObject == nil ? 0 : 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotDescription") as? SpotDescriptionCell else { return UITableViewCell() }
            cell.setUp(spot: spotObject, userLocation: mapVC.currentLocation)
            return cell
                        
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotSegCell") as? SpotSegCell else { return UITableViewCell() }
            cell.setUp(selectedIndex: selectedIndex, spotPosts: spotPostsController, spotVisitors: spotVisitorsController)
            return cell

        default:
            return UITableViewCell()
            
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
                
        switch indexPath.section {
        case 0:
            return 98
        case 1:
            return UIScreen.main.bounds.height - 98
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SpotSegHeader") as! SpotSegHeader
            header.setUp(selectedIndex: selectedIndex)
            return header
        }
        else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 40 : 0
    }
}


class SpotDescriptionCell: UITableViewCell {
    
    var pullLine: UIButton!
    var tagView: UIView!
    var tag1Icon, tag2Icon, tag3Icon: UIImageView!
    var spotName: UILabel!
    
    var cityName: UILabel!
    var separatorView0: UIView!
    var distanceLabel: UILabel!
    var separatorView1: UIView!
    var privacyIcon: UIImageView!
        
    func setUp(spot: MapSpot, userLocation: CLLocation) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        resetCell()
        
        let pullLine = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 21.5, y: 0, width: 43, height: 14.5))
        pullLine.contentEdgeInsets = UIEdgeInsets(top: 7, left: 5, bottom: 0, right: 5)
        pullLine.setImage(UIImage(named: "PullLine"), for: .normal)
        pullLine.addTarget(self, action: #selector(lineTap(_:)), for: .touchUpInside)
        addSubview(pullLine)
        
        if !spot.tags.isEmpty {

            tagView = UIView(frame: CGRect(x: 0, y: 15, width: 100, height: 24))
            tagView.backgroundColor = nil
            addSubview(tagView)
            
            var tagX = 14
            
            let tag1 = Tag(name: spot.tags[0])
            tag1Icon = UIImageView(frame: CGRect(x: tagX, y: 0, width: 24, height: 24))
            tag1Icon.contentMode = .scaleAspectFit
            tag1Icon.image = tag1.image
            tagView.addSubview(tag1Icon)
            if tag1.image == UIImage() { getTagImage(tag: tag1, position: 1)}
            
            if spot.tags.count > 1 {
                
                tagX += 28
                
                let tag2 = Tag(name: spot.tags[1])
                tag2Icon = UIImageView(frame: CGRect(x: tagX, y: 0, width: 24, height: 24))
                tag2Icon.contentMode = .scaleAspectFit
                tag2Icon.image = tag2.image
                tagView.addSubview(tag2Icon)
                if tag2.image == UIImage() { getTagImage(tag: tag2, position: 2)}
                
                if spot.tags.count > 2 {
                    
                    tagX += 28
                    
                    let tag3 = Tag(name: spot.tags[2])
                    tag3Icon = UIImageView(frame: CGRect(x: tagX, y: 0, width: 24, height: 24))
                    tag3Icon.contentMode = .scaleAspectFit
                    tag3Icon.image = tag3.image
                    tagView.addSubview(tag3Icon)
                    if tag3.image == UIImage() { getTagImage(tag: tag3, position: 3)}
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
            separatorView0 = UIView(frame: CGRect(x: cityName.frame.maxX + 9, y: cityName.frame.midY - 0.7, width: 5, height: 2))
            separatorView0.backgroundColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
            separatorView0.layer.cornerRadius = 0.5
            addSubview(separatorView0)
            
            distanceX = separatorView0.frame.maxX + 8
        }
        
        let spotLocation = CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)
        let distance = spotLocation.distance(from: userLocation)
        
        distanceLabel = UILabel(frame: CGRect(x: distanceX, y: spotName.frame.maxY + 3, width: UIScreen.main.bounds.width - distanceX - 14, height: 14))
        distanceLabel.text = distance.getLocationString()
        distanceLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        distanceLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        distanceLabel.sizeToFit()
        addSubview(distanceLabel)
        
        distanceX = distanceLabel.frame.maxX + 8
        
        separatorView1 = UIView(frame: CGRect(x: distanceX, y: distanceLabel.frame.midY - 0.7, width: 5, height: 2))
        separatorView1.backgroundColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        separatorView1.layer.cornerRadius = 0.5
        addSubview(separatorView1)
        
        distanceX = separatorView1.frame.maxX + 8
                
        switch spot.privacyLevel {
        
        case "friends":
            privacyIcon = UIImageView(frame: CGRect(x: distanceX, y: distanceLabel.frame.minY, width: 92, height: 16))
            privacyIcon.image = UIImage(named: "SpotPageFriends")
        case "invite":
            privacyIcon = UIImageView(frame: CGRect(x: distanceX, y: distanceLabel.frame.minY, width: 55.73, height: 16))
            privacyIcon.image = UIImage(named: "SpotPagePrivate")
        default:
            privacyIcon = UIImageView(frame: CGRect(x: distanceX, y: distanceLabel.frame.minY, width: 57, height: 16))
            privacyIcon.image = UIImage(named: "SpotPagePublic")
        }

        addSubview(privacyIcon)
    }
    
    // get tag image from database if not preloaded for this user
    func getTagImage(tag: Tag, position: Int) {
        
        tag.getImageURL { [weak self] url in
            guard let self = self else { return }
            
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            
            switch position {
            case 1: if self.tag1Icon != nil { self.tag1Icon.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer]) }
            case 2: if self.tag2Icon != nil { self.tag2Icon.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer]) }
            case 3: if self.tag3Icon != nil { self.tag3Icon.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer]) }
            default: return
            }
        }
    }
    
    func resetCell() {
        if pullLine != nil { pullLine.setImage(UIImage(), for: .normal) }
        if tagView != nil { for sub in tagView.subviews { sub.removeFromSuperview() } }
        if spotName != nil { spotName.text = "" }
        if cityName != nil { cityName.text = "" }
        if distanceLabel != nil { distanceLabel.text = "" }
        if separatorView0 != nil { separatorView0.backgroundColor = nil }
        if separatorView1 != nil { separatorView1.backgroundColor = nil }
        if privacyIcon != nil { privacyIcon.image = UIImage() }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if tag1Icon != nil { tag1Icon.sd_cancelCurrentImageLoad() }
        if tag2Icon != nil { tag2Icon.sd_cancelCurrentImageLoad() }
        if tag3Icon != nil { tag3Icon.sd_cancelCurrentImageLoad() }
    }
    
    @objc func lineTap(_ sender: UIButton) {
        guard let spotVC = viewContainingController() as? SpotViewController else { return }
        spotVC.mapVC.animateToFullScreen()
    }
}

class SpotSegHeader: UITableViewHeaderFooterView {
    
    var segmentedControl: UISegmentedControl!
    var buttonBar: UIView!
    var shadowImage: UIImageView!
    var separatorCover: UIView!
    var selectedIndex = 0

    func setUp(selectedIndex: Int) {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView

        self.selectedIndex = selectedIndex
        
        if segmentedControl != nil { segmentedControl.removeFromSuperview() }
        segmentedControl = SpotSegmentedControl(frame: CGRect(x: 10, y: 10, width: 204, height: 20))
        segmentedControl.backgroundColor = nil
        segmentedControl.selectedSegmentIndex = selectedIndex
        
        let postSegIm = selectedIndex == 0 ? UIImage(named: "PostsActive")?.withRenderingMode(.alwaysOriginal) : UIImage(named: "PostsInactive")?.withRenderingMode(.alwaysOriginal)
        let visitorSegIm = selectedIndex == 1 ? UIImage(named: "SpotVisitorsActive")?.withRenderingMode(.alwaysOriginal) : UIImage(named: "SpotVisitorsInactive")?.withRenderingMode(.alwaysOriginal)
        
        segmentedControl.insertSegment(with: postSegIm, at: 0, animated: false)
        segmentedControl.insertSegment(with: visitorSegIm, at: 1, animated: false)

        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        let segWidth: CGFloat = 100
        segmentedControl.setWidth(segWidth, forSegmentAt: 0)
        segmentedControl.setWidth(segWidth, forSegmentAt: 1)
        segmentedControl.selectedSegmentTintColor = .clear
        addSubview(segmentedControl)

        let minX: CGFloat = selectedIndex == 0 ? 10 : 114
        let minY = segmentedControl.frame.maxY + 3
        
        if buttonBar != nil { buttonBar.backgroundColor = nil }
        buttonBar = UIView(frame: CGRect(x: minX, y: minY, width: 97, height: 1.5))
        buttonBar.backgroundColor = .white
        self.addSubview(buttonBar)
        
        let backgroundImage = UIImage(named: "BlackBackground")
        segmentedControl.setBackgroundImage(backgroundImage, for: .normal, barMetrics: .default)
        segmentedControl.setBackgroundImage(backgroundImage, for: .selected, barMetrics: .default)
        
        if separatorCover != nil { separatorCover.backgroundColor = nil }
        separatorCover = UIView(frame: CGRect(x: 109, y: 0, width: 2, height: 40))
        separatorCover.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(separatorCover)
    
        /// hacky shadow for mask under seg view on profile
        if shadowImage != nil { shadowImage.image = UIImage() }
        shadowImage = UIImageView(frame: CGRect(x: -10, y: 37, width: UIScreen.main.bounds.width + 20, height: 6))
        shadowImage.image = UIImage(named: "NavShadowLine")
        shadowImage.clipsToBounds = false
        shadowImage.contentMode = .scaleAspectFill
        addSubview(shadowImage)
    }
    
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        
        Mixpanel.mainInstance().track(event: "SpotSwitchSegments")
        
        // scroll to top of collection on same index tap
        if sender.selectedSegmentIndex == selectedIndex {
            guard let spotVC = viewContainingController() as? SpotViewController else { return }
            spotVC.scrollSegmentToTop()
            return
        }
        
        // change selected segment on new index tap
        animateBar(index: sender.selectedSegmentIndex)
    }
    
    func animateBar(index: Int) {
        
        guard let spotVC = viewContainingController() as? SpotViewController else { return }
        let minX: CGFloat = index == 0 ? 10 : 114
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.15) {  self.buttonBar.frame = CGRect(x: minX, y: self.buttonBar.frame.minY, width: self.buttonBar.frame.width, height: self.buttonBar.frame.height)
                
                let postSegIm = index == 0 ? UIImage(named: "PostsActive")?.withRenderingMode(.alwaysOriginal) : UIImage(named: "PostsInactive")?.withRenderingMode(.alwaysOriginal)
                let visitorSegIm = index == 1 ? UIImage(named: "SpotVisitorsActive")?.withRenderingMode(.alwaysOriginal) : UIImage(named: "SpotVisitorsInactive")?.withRenderingMode(.alwaysOriginal)
                
                self.segmentedControl.setImage(postSegIm, forSegmentAt: 0)
                self.segmentedControl.setImage(visitorSegIm, forSegmentAt: 1)
                
            } completion: { [weak self] (_) in
                if self == nil { return }
                spotVC.resetIndex(index: index)
            }
        }
    }
}

class SpotSegCell: UITableViewCell {
    
    func setUp(selectedIndex: Int, spotPosts: SpotPostsViewController, spotVisitors: SpotVisitorsViewController) {
            
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        switch selectedIndex {
        
        case 0:
            self.addSubview(spotPosts.view)
            spotPosts.postsCollection.reloadData()
            spotPosts.postsCollection.performBatchUpdates(nil, completion: { [weak self] _ in
                guard let self = self else { return }
                guard let spotVC = self.viewContainingController() as? SpotViewController else { return }
                spotVC.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: spotPosts.postsCollection.contentSize.height + spotVC.sec0Height + 250)
            })
            
        case 1:
            self.addSubview(spotVisitors.view)
            spotVisitors.visitorsCollection.reloadData()
            spotVisitors.visitorsCollection.performBatchUpdates(nil, completion: { [weak self] _ in
                guard let self = self else { return }
                guard let spotVC = self.viewContainingController() as? SpotViewController else { return }
                spotVC.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: spotVisitors.visitorsCollection.contentSize.height + spotVC.sec0Height + 200)
            })

        default:
            return
        }
    }
}

class SpotSegmentedControl: UISegmentedControl {
    // scroll to top of gallery on tap
    // this is only called on the second segmented control change tap for some reason
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

        let previousIndex = self.selectedSegmentIndex
        super.touchesEnded(touches, with: event)
        
        if previousIndex == self.selectedSegmentIndex {
            if let spotVC = self.superview?.viewContainingController() as? SpotViewController {
                spotVC.scrollSegmentToTop()
            }
        }
    }
}

