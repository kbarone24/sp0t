//
//  ProfileViewController.swift
//  Spot
//
//  Created by kbarone on 2/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import FirebaseUI
import CoreLocation
import Mixpanel
import MapKit

class ProfileViewController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    let db: Firestore! = Firestore.firestore()
    
    var id: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var addFriendButton: UIButton!
    var lock: UIImageView!
    
    var nearbyCity: String!
    var userFriended = false
    var friendedDetail: UILabel!
    var acceptButton: UIButton!
    var removeButton: UIButton!
    
    var friendRequestRow: Int!
    
    var shadowScroll: UIScrollView!
    var tableView: UITableView!
    lazy var scrollDistance: CGFloat = 0
    lazy var friendsListScrollDistance: CGFloat = 0 
    
    var userInfo: UserProfile!
    lazy var bioHeight: CGFloat = 0
    lazy var navBarHeight: CGFloat = 0
    lazy var sec0Height: CGFloat = 0
    unowned var mapVC: MapViewController!
    
    var addedPost = false
    var addedSpot = false
    
    var commentsSelectedPost: MapPost!
    var postCaptionHeight: CGFloat!
    
    var status: friendStatus!
    var selectedIndex = 0 /// selected segment index
    
    var passedCamera: MKMapCamera!
    
    enum friendStatus {
        case friends
        case add
        case pending
        case received
        case denied
    }
    
    private lazy var firstViewController: ProfilePostsViewController = {
        let storyboard = UIStoryboard(name: "Profile", bundle: Bundle.main)
        var vc = storyboard.instantiateViewController(withIdentifier: "ProfilePosts") as! ProfilePostsViewController
        vc.profileVC = self
        vc.mapVC = mapVC
        self.addChild(vc)
        return vc
    }()
    
    private lazy var secondViewController: ProfileSpotsViewController = {
        let storyboard = UIStoryboard(name: "Profile", bundle: Bundle.main)
        var vc = storyboard.instantiateViewController(withIdentifier: "ProfileSpots") as! ProfileSpotsViewController
        vc.profileVC = self
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
        
        let annotations = mapVC.mapView.annotations
        mapVC.mapView.removeAnnotations(annotations)
        
        self.addChild(viewController)
        viewController.didMove(toParent: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        
       // addSegments()
        resetMap()
        runFunctions()
        
        /// set drawer to half-screen
        mapVC.customTabBar.view.frame = CGRect(x: 0, y: mapVC.halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - mapVC.halfScreenY)
        mapVC.prePanY = mapVC.halfScreenY
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateUser(_:)), name: NSNotification.Name("InitialUserLoad"), object: nil)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if userInfo == nil {
            if mapVC.userInfo == nil { return }
            userInfo = mapVC.userInfo
        }
        
        Mixpanel.mainInstance().track(event: "ProfileOpen")
    }
    
    override func viewWillDisappear(_ animated: Bool) {

        super.viewWillDisappear(animated)
        ///if sent from another profile we don't want to hide the title vie
        
        self.userInfo = nil
        
        /// dont hide nav bar for edit spot (only stacks that will happen from profile are edit cover image and edit address)
        if mapVC.spotViewController != nil { return }
        
        if !(self.parent is ProfileViewController) {
            mapVC.profileViewController = nil
            mapVC.selectedProfileID = ""
            mapVC.navigationItem.titleView = nil
            if !(self.parent is SpotViewController) && !(self.parent is NotificationsViewController) { self.navigationController?.setNavigationBarHidden(true, animated: false) }
        }
        
        if parent is CustomTabBar { scrollDistance = self.shadowScroll.contentOffset.y }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setUpNavBar()
    }
    
    deinit {
        print("deinit")
    }
    
    func resetMap() {
        
        let annotations = mapVC.mapView.annotations
        
        /// set profile view controller for map filtering and drawer animations
        mapVC.profileViewController = self
        mapVC.spotViewController = nil
        mapVC.nearbyViewController = nil
        mapVC.selectedProfileID = self.id
        
        /// selectedProfileID == "" used interchangeably with profileViewController == nil on map for filtering - should remove for redundancy
        mapVC.selectedProfileID = id
        mapVC.mapView.removeAnnotations(annotations)
        mapVC.hideNearbyButtons()
        mapVC.postsList.removeAll()
        
        if passedCamera != nil {
            mapVC.mapView.setCamera(passedCamera, animated: false)
            passedCamera = nil
        } else {
            mapVC.animateToProfileLocation(active: uid == id, coordinate: CLLocationCoordinate2D())
        }
    }
    
    func runFunctions() {
        //user info only nil when its active user
        
        if userInfo == nil {
            /// will call runFunctions() again on updateUser from notification
            if mapVC.userInfo == nil { return }
            userInfo = mapVC.userInfo
            userInfo.friendsList = mapVC.friendsList
        } 
                
        if nearbyCity != nil {
            selectedIndex = 1
            add(asChildViewController: secondViewController)
        } else {
            add(asChildViewController: firstViewController)
        }
        
        bioHeight = getBioHeight()
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        sec0Height = bioHeight + 110 - navBarHeight

        /// check if active user is friends with this profile
        if uid != userInfo.id && !mapVC.friendIDs.contains(userInfo.id ?? "") {
            getFriendRequestInfo()
        } else {
            status = .friends
        }
        
        addTableView()
        tableView.reloadData()
    }
    
    @objc func updateUser(_ notification: NSNotification) {
        if userInfo == nil {
            runFunctions()
        } else {
            /// update userInfo even if its not nil to update profileImage
            if id == uid { userInfo = mapVC.userInfo }
            tableView.reloadData()
        }
        if mapVC.customTabBar.selectedIndex == 4 { setUpNavBar() }
    }
    
    func getBioHeight() -> CGFloat {
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 32, height: 18))
        tempLabel.text = userInfo.userBio
        tempLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        return tempLabel.frame.height
    }
    
    func addTableView() {
        // if reload, reset subviews, else instantiate userview
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        shadowScroll = UIScrollView(frame: CGRect(x: 0, y: -UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: 1300)
        shadowScroll.backgroundColor = nil
        shadowScroll.isScrollEnabled = false
        shadowScroll.isUserInteractionEnabled = true
        shadowScroll.showsVerticalScrollIndicator = false
        shadowScroll.delegate = self
        shadowScroll.tag = 80
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(rightSwipe(_:)))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(leftSwipe(_:)))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.separatorStyle = .none
        tableView.tag = 81
        tableView.showsVerticalScrollIndicator = false
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = false
        tableView.sectionFooterHeight = 0
        tableView.sectionHeaderHeight = 0
        tableView.isScrollEnabled = false
        tableView.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
        tableView.register(UserViewCell.self, forCellReuseIdentifier: "UserViewCell")
        tableView.register(SegViewHeader.self, forHeaderFooterViewReuseIdentifier: "SegViewHeader")
        tableView.register(SegViewCell.self, forCellReuseIdentifier: "SegViewCell")
        tableView.register(NotFriendsCell.self, forCellReuseIdentifier: "NotFriendsCell")
        view.addSubview(tableView)
        
        view.addSubview(shadowScroll)
        
        view.addGestureRecognizer(shadowScroll.panGestureRecognizer)
        tableView.removeGestureRecognizer(tableView.panGestureRecognizer)
        firstViewController.postsCollection.removeGestureRecognizer(firstViewController.postsCollection.panGestureRecognizer)
        secondViewController.spotsCollection.removeGestureRecognizer(secondViewController.spotsCollection.panGestureRecognizer)
    }
    
    func setUpNavBar() {
        // this is the only nav bar that uses a titleView
        /// set title to username and spotscore
        
        mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
        mapVC.navigationController?.navigationBar.isTranslucent = mapVC.prePanY != 0
        mapVC.navigationController?.navigationBar.barTintColor = UIColor(named: "SpotBlack")
        mapVC.navigationController?.navigationBar.isUserInteractionEnabled = true
        
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        
        let titleLabel = UILabel(frame: CGRect(x: titleView.frame.minX, y: titleView.frame.minY, width: titleView.frame.width, height: 20))
        titleLabel.textAlignment = .center
        titleLabel.text = self.userInfo == nil ? "" : self.userInfo.username
        titleLabel.textColor = .white
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 20)
        
        let scoreLabel = UILabel(frame: CGRect(x: 0, y: 21, width: 200, height: 15))
        scoreLabel.font = UIFont(name: "Gameplay", size: 11)
        let attString = userInfo == nil ? "" : String(self.userInfo.spotScore ?? 0)
        let attText = NSAttributedString(string: attString, attributes: [NSAttributedString.Key.kern : 1.0])
        scoreLabel.attributedText = attText
        scoreLabel.textAlignment = .center
        scoreLabel.textColor = UIColor(patternImage: UIImage(named: "SpotScoreBackground") ?? UIImage())
        
        titleView.addSubview(titleLabel)
        titleView.addSubview(scoreLabel)
        
        mapVC.navigationItem.titleView = titleView
        
        if !(parent is CustomTabBar) {
            mapVC.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(removeProfile(_:)))
            mapVC.navigationItem.rightBarButtonItem = UIBarButtonItem()
        }
        
        if uid == id {
            let settingsIcon = UIImage(named: "SettingsIcon")?.withRenderingMode(.alwaysOriginal)
            mapVC.navigationItem.rightBarButtonItem = UIBarButtonItem(image: settingsIcon, style: .plain, target: self, action: #selector(openSettings(_:)))
        }
        
        mapVC.selectedProfileID = id
        mapVC.profileViewController = self
        mapVC.spotViewController = nil
        mapVC.nearbyViewController = nil
    }
        
    func reloadProfile() {
        bioHeight = getBioHeight()
        navBarHeight = navigationController?.navigationBar.frame.height ?? 40
        sec0Height = bioHeight + navBarHeight - 20
        self.tableView.reloadData()
    }
    
    func getFriendRequestInfo() {
        ///1. get user status
        let userRef = self.db.collection("users").document(self.uid).collection("notifications")
        let userQuery = userRef.whereField("type", isEqualTo: "friendRequest").whereField("senderID", isEqualTo: self.id)
        
        userQuery.getDocuments { [weak self] (snap, err) in
            
            guard let self = self else { return }
            if err != nil { return }
            
            if snap!.documents.count > 0 {
                /// active user received friend request
                self.status = .received
                self.tableView.reloadData()
            } else {
                let notiRef = self.db.collection("users").document(self.id).collection("notifications")
                let query = notiRef.whereField("type", isEqualTo: "friendRequest").whereField("senderID", isEqualTo: self.uid)
                
                query.getDocuments { [weak self] (snap2, err) in
                    
                    guard let self = self else { return }
                    if err != nil { return }
                    
                    if snap2!.documents.count > 0 {
                        /// active user sent friend request
                        self.status = .pending
                        self.tableView.reloadData()
                    } else {
                        ///no requests sent
                        self.status = .add
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    func removeFriendsView() {
        ///user accepted friend request
        status = .friends
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func updateFriendsLists(friendID: String) {
        ///add this user to the active user's friends list
        mapVC.friendsList.append(self.userInfo)
        mapVC.friendIDs.append(self.userInfo.id!)
        /// add active user to this user's frined list
        userInfo.friendIDs.append(self.uid)
        if !userInfo.friendsList.isEmpty {
            userInfo.friendsList.append(mapVC.userInfo)
        }
    }
    
    @objc func removeProfile(_ sender: UIBarButtonItem) {
        Mixpanel.mainInstance().track(event: "ProfileRemove")
        
        mapVC.mapView.showsUserLocation = true
        mapVC.postsList.removeAll()
        mapVC.selectedProfileID = ""
        mapVC.profileViewController = nil
        mapVC.navigationItem.leftBarButtonItem = UIBarButtonItem()
        
        firstViewController.active = false
        secondViewController.active = false
        
        /// this is like the equivalent of running a viewWillAppear method from the underneath view controller
        if let nearbyVC = parent as? NearbyViewController{
            nearbyVC.resetView()
            
        } else if let postVC = parent as? PostViewController {
            postVC.resetView()
            if commentsSelectedPost != nil { openComments() }
            
        } else if let profileVC = parent as? ProfileViewController {
            
            profileVC.resetProfile()
            if profileVC.selectedIndex == 0 { profileVC.firstViewController.resetPosts() }
            profileVC.tableView.reloadData()
            openFriendsList()
            
        } else if let spotVC = parent as? SpotViewController {
            spotVC.resetView()

        } else if let notificationsVC = parent as? NotificationsViewController {
            notificationsVC.resetView()
            notificationsVC.checkForRequests()
        }
        
        ///remove listeners early to avoid reference being called after dealloc
        firstViewController.removeListeners()
        secondViewController.removeListeners()
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("InitialUserLoad"), object: nil)
            
        self.remove(asChildViewController: firstViewController)
        self.remove(asChildViewController: secondViewController)
        
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
    }
    
    @objc func rightSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex == 1 {
            guard let header = tableView.headerView(forSection: 1) as? SegViewHeader else { return }
            header.animateBar(index: 0)
        }
    }
    
    @objc func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex == 0 {
            guard let header = tableView.headerView(forSection: 1) as? SegViewHeader else { return }
            header.animateBar(index: 1)
        }
    }
    
    func openComments() {
        if let commentsVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(withIdentifier: "Comments") as? CommentsViewController {
            guard let postVC = parent as? PostViewController else { return }
            
            commentsVC.commentList = commentsSelectedPost.commentList
            commentsVC.post = commentsSelectedPost
            commentsVC.captionHeight = postCaptionHeight ?? 0
            commentsVC.postVC = postVC
            
            DispatchQueue.main.async {
                postVC.present(commentsVC, animated: true, completion: nil)
            }
        }
    }
    
    func openFriendsList() {
        
        if let friendsListVC = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "FriendsList") as? FriendsListController {
            guard let profileVC = parent as? ProfileViewController else { print("profile broke"); return }
            
            friendsListVC.profileVC = profileVC
            friendsListVC.friendIDs = profileVC.userInfo.friendIDs
            friendsListVC.friendsList = profileVC.userInfo.friendsList
            
            /// set table offset on return to friendslist to keep users scroll distance
            friendsListVC.tableOffset = profileVC.friendsListScrollDistance
            profileVC.friendsListScrollDistance = 0
            
            DispatchQueue.main.async {
                profileVC.present(friendsListVC, animated: true, completion: nil)
            }
        }
    }
    
    @objc func openSettings(_ sender: UIBarButtonItem) {
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "Settings") as? SettingsViewController {
            vc.profileVC = self
            DispatchQueue.main.async {
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    func resetIndex(index: Int) {
        
        let minY = mapVC.prePanY == 0 ? sec0Height : 0

        if index == 0 {
            DispatchQueue.main.async {
                
                self.remove(asChildViewController: self.secondViewController)
                self.add(asChildViewController: self.firstViewController)
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: minY), animated: false)

                ///reset content offsets so scroll stays smooth
                if self.firstViewController.postsCollection.contentOffset.y > 0 || self.secondViewController.spotsCollection.contentOffset.y > 0  {
                    self.shadowScroll.contentOffset.y = self.sec0Height + self.firstViewController.postsCollection.contentOffset.y
                }
                
                /// reset content size for current collection 
                self.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - self.sec0Height, self.firstViewController.postsCollection.contentSize.height + 65))
            }
            
        } else {
            DispatchQueue.main.async {
            
                self.remove(asChildViewController: self.firstViewController)
                self.add(asChildViewController: self.secondViewController)
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: minY), animated: false)
                
                ///reset content offsets so scroll stays smooth
                if self.firstViewController.postsCollection.contentOffset.y > 0 || self.secondViewController.spotsCollection.contentOffset.y > 0  {
                    self.shadowScroll.contentOffset.y = self.sec0Height + self.secondViewController.spotsCollection.contentOffset.y
                }
                
                self.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - self.sec0Height, self.secondViewController.spotsCollection.contentSize.height + 300))
            }
        }
        selectedIndex = index
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func postRemove() {
        // unhide navigation bar if added post page from here
        setUpNavBar()
        expandProfile()
        
        // not sure when addedPost would be false
        if addedPost {
            addedPost = false
            
            let annotations = mapVC.mapView.annotations
            mapVC.mapView.removeAnnotations(annotations)
            
            if selectedIndex == 0 { firstViewController.addAnnotations() }
            if parent is CustomTabBar { mapVC.customTabBar.tabBar.isHidden = false }
            
            if passedCamera != nil {
                /// passed camera represents where the profile was before entering posts
                mapVC.mapView.setCamera(passedCamera, animated: false)
                passedCamera = nil
            } else {
                mapVC.animateToProfileLocation(active: uid == id, coordinate: CLLocationCoordinate2D())
            }
        }
    }
    
    // reset profile is only called right now after spot page remove
    func resetProfile() {
        
        if shadowScroll != nil {
            /// expandProfile to full screen if it was full screen and scrolled at all before adding childVC
            if shadowScroll.contentOffset.y > 0 {
                expandProfile()
            } else {
                profileToHalf()
            }
        }
        
        secondViewController.resetView()
        
        mapVC.profileViewController = self
        mapVC.spotViewController = nil
        mapVC.nearbyViewController = nil
        mapVC.selectedProfileID = self.id
        
        mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
        if self.parent is CustomTabBar { mapVC.customTabBar.tabBar.isHidden = false }
        setUpNavBar()
    }
    
    func expandProfile() {

        mapVC.prePanY = 0
        mapVC.customTabBar.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height )
        
        // only can scroll if active seg is loaded
        shadowScroll.isScrollEnabled = (selectedIndex == 0 && firstViewController.loaded) || (selectedIndex == 1 && secondViewController.loaded)
        
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.isTranslucent = false
    }
    
    func profileToHalf() {
        
        if tableView == nil { return }
        mapVC.prePanY = mapVC.halfScreenY
        
        /// reset scrolls
        mapVC.customTabBar.view.frame = CGRect(x: 0, y: mapVC.halfScreenY, width: self.view.frame.width, height: UIScreen.main.bounds.height - mapVC.halfScreenY)
        tableView.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: 0), animated: false)
        shadowScroll.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: 0), animated: false)
        shadowScroll.isScrollEnabled = false
        resetSegs()
        
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.isTranslucent = true
    }
    
    func resetSegs() {
        firstViewController.postsCollection.setContentOffset(CGPoint(x: firstViewController.postsCollection.contentOffset.x, y: 0), animated: false)
        secondViewController.spotsCollection.setContentOffset(CGPoint(x: secondViewController.spotsCollection.contentOffset.x, y: 0), animated: false)
    }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return status == nil ? 1 : 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserViewCell", for: indexPath) as! UserViewCell
            cell.setUp(user: userInfo, mapVC: mapVC, status: status ?? .add)
            return cell
            
        } else {
            switch status {
            case .friends :
                let cell = tableView.dequeueReusableCell(withIdentifier: "SegViewCell", for: indexPath) as! SegViewCell
                cell.setUp(selectedIndex: selectedIndex, profilePosts: firstViewController, profileSpots: secondViewController)
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "NotFriendsCell", for: indexPath) as! NotFriendsCell
                let activeUser = self.uid == id ? userInfo : self.mapVC.userInfo
                cell.setUp(status: status ?? .add, user: userInfo, activeUser: activeUser!)
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SegViewHeader") as! SegViewHeader
            header.setUp(index: selectedIndex, profileVC: self, status: status ?? .add)
            return header
        }
        else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 40 : 0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 110 + bioHeight : UIScreen.main.bounds.height - 120 - bioHeight
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        /// dont offset scroll if drawer is moved
        if mapVC.prePanY != mapVC.customTabBar.view.frame.minY { return }
        
        /// reset scrolling before selected view controller has loaded content
        if (selectedIndex == 0 && !firstViewController.loaded) || (selectedIndex == 1 && !secondViewController.loaded) {

            DispatchQueue.main.async {
                let offsetY = self.mapVC.prePanY == 0 ? self.sec0Height : 0
                self.shadowScroll.setContentOffset(CGPoint(x: self.shadowScroll.contentOffset.x, y: offsetY), animated: false)
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: offsetY), animated: false)
                return
            }
        }
        
        /// only recognize on the main  scroll
        if scrollView.tag != 80 { return }
        if selectedIndex == 0 && firstViewController.children.count > 0 { return }
        if selectedIndex == 1 && secondViewController.children.count > 0 { return }
        
        /// scrollView offset hasn't hit the seg view yet so offset the profile header info
        setContentOffsets()
    }
    
    func scrollToTop() {
        DispatchQueue.main.async {
            self.shadowScroll.setContentOffset(CGPoint(x: self.shadowScroll.contentOffset.x, y: 0), animated: false)
            self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: 0), animated: true)
            self.resetSegs()
        }
    }
    
    func setContentOffsets() {
                
        DispatchQueue.main.async {
            
            if self.shadowScroll.contentOffset.y <= self.sec0Height {
                /// stop scrolling table if full screen and past sec0, defer to drawer offset methods if pulling drawer down
                if self.mapVC.prePanY == 0 && self.mapVC.customTabBar.view.frame.minY == 0 {
                    
                    self.shadowScroll.setContentOffset(CGPoint(x: 0, y: self.sec0Height), animated: false)
                    self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.sec0Height), animated: false)
                    self.selectedIndex == 0 ? self.firstViewController.postsCollection.setContentOffset(CGPoint(x: self.firstViewController.postsCollection.contentOffset.x, y: 0), animated: false) : self.secondViewController.spotsCollection.setContentOffset(CGPoint(x: self.secondViewController.spotsCollection.contentOffset.x, y: 0), animated: false)
                    return
                }
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.shadowScroll.contentOffset.y), animated: false)
                self.selectedIndex == 0 ? self.firstViewController.postsCollection.setContentOffset(CGPoint(x: self.firstViewController.postsCollection.contentOffset.x, y: 0), animated: false) : self.secondViewController.spotsCollection.setContentOffset(CGPoint(x: self.secondViewController.spotsCollection.contentOffset.x, y: 0), animated: false)
                /// offset current content collection
                
            } else if self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) is SegViewCell {
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.sec0Height), animated: false)
                
                switch self.selectedIndex {
                
                case 0:
                    self.firstViewController.postsCollection.setContentOffset(CGPoint(x: self.firstViewController.postsCollection.contentOffset.x, y: self.shadowScroll.contentOffset.y - self.sec0Height), animated: false)
                    
                default:
                    self.secondViewController.spotsCollection.setContentOffset(CGPoint(x: self.secondViewController.spotsCollection.contentOffset.x, y: self.shadowScroll.contentOffset.y - self.sec0Height), animated: false)
                }
            }
        }

    }
    
    func scrollSegmentToTop() {
        
        if mapVC.prePanY != 0 { return }
        
        if shadowScroll.contentOffset.y > sec0Height {
                        
            UIView.animate(withDuration: 0.2) {
                self.selectedIndex == 0 ? self.firstViewController.postsCollection.setContentOffset(CGPoint(x: self.firstViewController.postsCollection.contentOffset.x, y: 0), animated: false) : self.secondViewController.spotsCollection.setContentOffset(CGPoint(x: self.secondViewController.spotsCollection.contentOffset.x, y: 0), animated: false)
            } completion: { (_) in
                self.shadowScroll.setContentOffset(CGPoint(x: self.shadowScroll.contentOffset.x, y: self.sec0Height), animated: false)
            }
        }
    }
}
///https://stackoverflow.com/questions/13221488/uiscrollview-within-a-uiscrollview-how-to-keep-a-smooth-transition-when-scrolli

class UserViewCell: UITableViewCell {
    
    var pullLine: UIImageView!
    var profileImage: UIImageView!
    var nameLabel, usernameLabel, cityLabel, bioLabel: UILabel!
    var currentLocationIcon, friendsIcon: UIImageView!
    var friendCountButton: UIButton!
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var userInfo: UserProfile!
    unowned var mapVC: MapViewController!
    
    func setUp(user: UserProfile, mapVC: MapViewController, status: ProfileViewController.friendStatus) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        userInfo = user
        self.mapVC = mapVC
        
        resetCell()
        
        pullLine = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 18, y: 10, width: 36, height: 4.5))
        pullLine.image = UIImage(named: "PullLine")
        self.addSubview(pullLine)
        
        profileImage = UIImageView(frame: CGRect(x: 13, y: 20, width: 42, height: 42))
        profileImage.layer.masksToBounds = false
        profileImage.layer.cornerRadius = profileImage.frame.height/2
        profileImage.clipsToBounds = true
        profileImage.contentMode = UIView.ContentMode.scaleAspectFill
        self.addSubview(profileImage)
        
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profileImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        nameLabel = UILabel(frame: CGRect(x: 64, y: 23, width: UIScreen.main.bounds.width - 190, height: 18))
        nameLabel.text = user.name
        nameLabel.textColor = UIColor.white
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 16)!
        nameLabel.sizeToFit()
        self.addSubview(nameLabel)
        
        usernameLabel = UILabel(frame: CGRect(x: 65, y: 42.5, width: UIScreen.main.bounds.width - 190, height: 15))
        usernameLabel.text = user.username
        usernameLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        usernameLabel.sizeToFit()
        self.addSubview(usernameLabel)
        
        // set user's city
        if user.currentLocation != "" {
            currentLocationIcon = UIImageView(frame: CGRect(x: 14, y: 74.5, width: 9, height: 13))
            currentLocationIcon.image = UIImage(named: "DistanceIcon")
            self.addSubview(currentLocationIcon)
            
            cityLabel = UILabel(frame: CGRect(x: 29, y: 74, width: 250, height: 20))
            cityLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            cityLabel.text = user.currentLocation
            cityLabel.font = UIFont(name: "SFCamera-Semibold", size: 12.5)!
            cityLabel.sizeToFit()
            self.addSubview(cityLabel)
        }
        
        let friendsX = cityLabel == nil ? 14 : cityLabel.frame.maxX + 15
        friendsIcon = UIImageView(frame: CGRect(x: friendsX, y: 75, width: 18, height: 12))
        friendsIcon.image = UIImage(named: "FriendRequest")
        friendsIcon.contentMode = .scaleAspectFit
        self.addSubview(friendsIcon)
        
        friendCountButton = UIButton(frame: CGRect(x: friendsIcon.frame.maxX + 6, y: friendsIcon.frame.minY - 2, width: 100, height: 18))
        friendCountButton.setTitle("\(user.friendIDs.count) friends", for: .normal)
        friendCountButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        friendCountButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 13)
        friendCountButton.contentHorizontalAlignment = .left
        friendCountButton.contentVerticalAlignment = .top
        
        if status == .friends {
            friendCountButton.addTarget(self, action: #selector(openFriendsList(_:)), for: .touchUpInside)
        }
        self.addSubview(friendCountButton)
        
        if uid == user.id {
            let editProfileButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 110, y: 23, width: 93, height: 28))
            editProfileButton.setImage(UIImage(named: "EditProfileButton"), for: .normal)
            editProfileButton.contentMode = .scaleAspectFit
            editProfileButton.addTarget(self, action: #selector(editProfileTap(_:)), for: .touchUpInside)
            self.addSubview(editProfileButton)
        }
        
        bioLabel = UILabel(frame: CGRect(x: 16, y: friendsIcon.frame.maxY + 13, width: UIScreen.main.bounds.width - 32, height: 18))
        bioLabel.text = user.userBio
        bioLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        bioLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        bioLabel.numberOfLines = 0
        bioLabel.lineBreakMode = .byWordWrapping
        bioLabel.sizeToFit()
        self.addSubview(bioLabel)
        
        self.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 150 + bioLabel.frame.height)
    }
    
    @objc func editProfileTap(_ sender: UIButton) {
        if let editProfileVC = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "EditProfile") as? EditProfileViewController {
            if let profileVC = self.viewContainingController() as? ProfileViewController {
                editProfileVC.profileVC = profileVC
                DispatchQueue.main.async {
                    profileVC.present(editProfileVC, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc func openFriendsList(_ sender: UIButton) {
        if let friendsListVC = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "FriendsList") as? FriendsListController {
            if let profileVC = self.viewContainingController() as? ProfileViewController {
                friendsListVC.profileVC = profileVC
                friendsListVC.friendIDs = userInfo.friendIDs
                if uid == userInfo.id {
                    userInfo.friendsList = mapVC.friendsList
                }
                if !userInfo.friendsList.isEmpty { friendsListVC.friendsList = userInfo.friendsList }
                DispatchQueue.main.async {
                    profileVC.present(friendsListVC, animated: true, completion: nil)
                }
            }
        }
    }
    
    func resetCell() {
        if pullLine != nil { pullLine.image = UIImage() }
        if profileImage != nil { profileImage.image = UIImage() }
        if nameLabel != nil { nameLabel.text = "" }
        if usernameLabel != nil { usernameLabel.text = "" }
        if cityLabel != nil { cityLabel.text = "" }
        if bioLabel != nil { bioLabel.text = "" }
        if currentLocationIcon != nil { currentLocationIcon.image = UIImage() }
        if friendsIcon != nil { friendsIcon.image = UIImage() }
        if friendCountButton != nil { friendCountButton.setTitle("", for: .normal) }
    }
    
    @objc override func prepareForReuse() {
        super.prepareForReuse()
        if profileImage != nil { profileImage.sd_cancelCurrentImageLoad() }
    }
}

class SegViewHeader: UITableViewHeaderFooterView {
    
    var segmentedControl: UISegmentedControl!
    var buttonBar: UIView!
    var selectedIndex = 0
    
    unowned var profileVC: ProfileViewController!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    func setUp(index: Int, profileVC: ProfileViewController, status: ProfileViewController.friendStatus) {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        // probably strong reference
        self.profileVC = profileVC
        self.selectedIndex = index
        
        if segmentedControl != nil { segmentedControl.removeFromSuperview() }
        segmentedControl = ProfileSegmentedControl(frame: CGRect(x: UIScreen.main.bounds.width * 1/6, y: 10, width: UIScreen.main.bounds.width * 2/3, height: 20))
        segmentedControl.backgroundColor = nil
        segmentedControl.selectedSegmentIndex = index
        
        let postSegIm = index == 0 ? UIImage(named: "PostSeg") : UIImage(named: "PostSeg")?.alpha(0.6)
        let spotSegIm = index == 0 ? UIImage(named: "SpotSeg")?.alpha(0.6) : UIImage(named: "SpotSeg")
        
        segmentedControl.insertSegment(with: postSegIm, at: 0, animated: false)
        segmentedControl.insertSegment(with: spotSegIm, at: 1, animated: false)
        
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: UIControl.Event.valueChanged)
        let segWidth = UIScreen.main.bounds.width * 1/3
        segmentedControl.setWidth(segWidth, forSegmentAt: 0)
        segmentedControl.setWidth(segWidth, forSegmentAt: 1)
        segmentedControl.selectedSegmentTintColor = .clear
        if status != .friends { segmentedControl.isUserInteractionEnabled = false }
        self.addSubview(segmentedControl)
        
        let indexMult: CGFloat = 1 + CGFloat(index)
        let minX = UIScreen.main.bounds.width * (indexMult)/3 - 20
        let minY = segmentedControl.frame.maxY + 3
        
        if buttonBar != nil { buttonBar.backgroundColor = nil }
        
        buttonBar = UIView(frame: CGRect(x: minX, y: minY, width: 40, height: 1.5))
        buttonBar.backgroundColor = .white
        self.addSubview(buttonBar)
        
        let backgroundImage = UIImage(named: "BlackBackground")
        segmentedControl.setBackgroundImage(backgroundImage, for: .normal, barMetrics: .default)
        segmentedControl.setBackgroundImage(backgroundImage, for: .selected, barMetrics: .default)
        
        let separatorCover = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 1, y: 0, width: 2, height: 40))
        separatorCover.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(separatorCover)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        
        // scroll to top of collection on same index tap
        if sender.selectedSegmentIndex == selectedIndex {
            profileVC.scrollSegmentToTop()
            return
        }
        
        // change selected segment on same index tap
        animateBar(index: sender.selectedSegmentIndex)
    }
    
    func animateBar(index: Int) {
        let minX = UIScreen.main.bounds.width * CGFloat(1 + index) / 3 - 20
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.15) {  self.buttonBar.frame = CGRect(x: minX, y: self.segmentedControl.frame.maxY + 3, width: 40, height: 1.5)
                
                let postSegIm = index == 0 ? UIImage(named: "PostSeg") : UIImage(named: "PostSeg")?.alpha(0.6)
                let spotSegIm = index == 0 ? UIImage(named: "SpotSeg")?.alpha(0.6) : UIImage(named: "SpotSeg")
                
                self.segmentedControl.setImage(postSegIm, forSegmentAt: 0)
                self.segmentedControl.setImage(spotSegIm, forSegmentAt: 1)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.profileVC.resetIndex(index: index)
        }
    }
}

class SegViewCell: UITableViewCell {
    
    func setUp(selectedIndex: Int, profilePosts: ProfilePostsViewController, profileSpots: ProfileSpotsViewController) {
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        switch selectedIndex {
        case 0:
            self.addSubview(profilePosts.view)
        default:
            self.addSubview(profileSpots.view)
        }
    }
    
}

class NotFriendsCell: UITableViewCell {
    var userInfo: UserProfile!
    var activeUser: UserProfile!
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var receivedLabel, pendingLabel, removedLabel: UILabel!
    var addFriendButton, acceptButton, removeButton: UIButton!
    
    var friendStatus: ProfileViewController.friendStatus!
    
    func setUp(status: ProfileViewController.friendStatus, user: UserProfile, activeUser: UserProfile) {
        userInfo = user
        self.activeUser = activeUser
        
        self.selectionStyle = .none
        self.backgroundColor = UIColor(named: "SpotBlack")
        
        resetCell()
        
        switch status {
        case .add:
            /// set up standard not friends view with add friend button
            addFriendButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 95.5, y: 40, width: 191, height: 45))
            addFriendButton.setImage(UIImage(named: "AddFriendButton"), for: .normal)
            addFriendButton.addTarget(self, action: #selector(addFriendTap(_:)), for: .touchUpInside)
            self.addSubview(addFriendButton)
            
        case .received:
            /// set up view with option to accept / deny request
            
            receivedLabel = UILabel(frame: CGRect(x: 20, y: 20, width: UIScreen.main.bounds.width - 40, height: 20))
            receivedLabel.text = "Sent you a friend request"
            receivedLabel.textAlignment = .center
            receivedLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            receivedLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            self.addSubview(receivedLabel)
            
            acceptButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 95.5, y: receivedLabel.frame.maxY + 15, width: 191, height: 45))
            acceptButton.setImage(UIImage(named: "AcceptButton"), for: .normal)
            acceptButton.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
            self.addSubview(acceptButton)
            
            removeButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 95.5, y: acceptButton.frame.maxY + 10, width: 191, height: 37))
            removeButton.setTitle("Remove", for: .normal)
            removeButton.setTitleColor(UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1), for: .normal)
            removeButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 13)
            removeButton.titleLabel?.textAlignment = .center
            removeButton.addTarget(self, action: #selector(removeTap(_:)), for: .touchUpInside)
            self.addSubview(removeButton)
            
            
        case .pending:
            /// show friend request sent
            pendingLabel = UILabel(frame: CGRect(x: 20, y: 60, width: UIScreen.main.bounds.width - 40, height: 20))
            pendingLabel.text = "Friend request pending"
            pendingLabel.textAlignment = .center
            pendingLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            pendingLabel.textColor = UIColor(named: "SpotGreen")
            self.addSubview(pendingLabel)
            
        default:
            ///show friend request removed
            removedLabel = UILabel(frame: CGRect(x: 20, y: 60, width: UIScreen.main.bounds.width - 40, height: 20))
            removedLabel.text = "Friend request removed"
            removedLabel.textAlignment = .center
            removedLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            removedLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            self.addSubview(removedLabel)
        }
    }
    
    @objc func addFriendTap(_ sender: UIButton) {
        /// send request in db
        Mixpanel.mainInstance().track(event: "ProfileAddFriend")
        addFriend(senderProfile: self.activeUser, receiverID: userInfo.id!)
        resetView(status: .pending)
    }
    
    @objc func acceptTap(_ sender: UIButton) {
        /// add friend in db
        Mixpanel.mainInstance().track(event: "ProfileFriendRequestAccepted")
        acceptFriendRequest()
        
        if let profileVC = self.viewContainingController() as? ProfileViewController {
            profileVC.updateFriendsLists(friendID: userInfo.id!)
            profileVC.removeFriendsView()
        }
    }
    
    @objc func removeTap(_ sender: UIButton) {
        /// remove request in db
        Mixpanel.mainInstance().track(event: "ProfileFriendRequestRemoved")
        removeFriendRequest()
        resetView(status: .denied)
    }
    
    func resetView(status: ProfileViewController.friendStatus) {
        for sub in self.subviews {
            sub.removeFromSuperview()
        }
        setUp(status: status, user: userInfo, activeUser: activeUser)
    }
    
    func acceptFriendRequest() {
        let friendID = userInfo.id!
        acceptFriendRequest(friendID: friendID, uid: uid, username: activeUser.username)
        
        for view in subviews { view.removeFromSuperview() }
        
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("friendRequestAccept"), object: nil, userInfo: infoPass)
        // add new friend to current user's friends list
    }
    
    func removeFriendRequest() {
        let friendID = self.userInfo.id!
        removeFriendRequest(friendID: friendID, uid: uid)
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("friendRequestReject"), object: nil, userInfo: infoPass)
    }
    
    func resetCell() {
        if receivedLabel != nil { receivedLabel.text = "" }
        if pendingLabel != nil { pendingLabel.text = "" }
        if removedLabel != nil { removedLabel.text = "" }
        if addFriendButton != nil { addFriendButton.setImage(UIImage(), for: .normal) }
        if acceptButton != nil { acceptButton.setImage(UIImage(), for: .normal) }
        if removeButton != nil { removeButton.setImage(UIImage(), for: .normal) }
    }
}

extension UIImage {
    
    func alpha(_ value:CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: CGPoint.zero, blendMode: .normal, alpha: value)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? UIImage()
    }
}

class ProfileSegmentedControl: UISegmentedControl {
    // scroll to top of gallery on tap
    // this is only called on the second segmented control change tap for some reason
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let previousIndex = self.selectedSegmentIndex
        super.touchesEnded(touches, with: event)
        
        if previousIndex == self.selectedSegmentIndex {
            if let profileVC = self.superview?.viewContainingController() as? ProfileViewController {
                profileVC.scrollSegmentToTop()
            }
        }
    }
}
