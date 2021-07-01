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
    var addFirstSpotButton: UIButton!
    
    var userFriended = false
    var friendedDetail: UILabel!
    var acceptButton: UIButton!
    var removeButton: UIButton!
    
    var friendRequestRow: Int!
    
    var shadowScroll: UIScrollView!
    var tableView: UITableView!
    var activityIndicator, loadingIndicator: CustomActivityIndicator!
    lazy var scrollDistance: CGFloat = 0
    lazy var friendsListScrollDistance: CGFloat = 0
    
    var editView: UIView! /// "more" menu showed with remove friend + report user
    var editMask: UIView!
    var exitButton: UIButton!
    
    var passedUsername: String! /// passed username from tapped tag
    var userInfo: UserProfile!
    lazy var navBarHeight: CGFloat = 0
    lazy var sec0Height: CGFloat = 0
    unowned var mapVC: MapViewController!
    
    var commentsSelectedPost: MapPost!
    var postCaptionHeight: CGFloat!
    
    var status: friendStatus!
    var selectedIndex = 0 /// selected segment index
    
    lazy var openSpotID = "" /// instruct to open spot on hideFromFeed post
    lazy var openPostID = ""
    lazy var openSpotTags: [String] = []
    
    var passedCamera: MKMapCamera!
    
    enum friendStatus {
        case friends
        case add
        case pending
        case received
        case denied
    }
        
    private lazy var profileSpotsController: ProfileSpotsViewController = {
        let storyboard = UIStoryboard(name: "Profile", bundle: Bundle.main)
        var vc = storyboard.instantiateViewController(withIdentifier: "ProfileSpots") as! ProfileSpotsViewController
        vc.profileVC = self
        vc.mapVC = mapVC
        self.addChild(vc)
        return vc
    }()
    
    private lazy var profilePostsController: ProfilePostsViewController = {
        let storyboard = UIStoryboard(name: "Profile", bundle: Bundle.main)
        var vc = storyboard.instantiateViewController(withIdentifier: "ProfilePosts") as! ProfilePostsViewController
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
        
        resetMap()
        addTableView()
        runFunctions()
        
        /// set drawer to half-screen
        mapVC.customTabBar.view.frame = CGRect(x: 0, y: mapVC.halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - mapVC.halfScreenY)
        mapVC.prePanY = mapVC.halfScreenY
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateUser(_:)), name: NSNotification.Name("InitialUserLoad"), object: nil)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Mixpanel.mainInstance().track(event: "ProfileOpen")
        setUserInfo()
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
        }
        
        if parent is CustomTabBar { scrollDistance = self.shadowScroll.contentOffset.y }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if userInfo == nil { activityIndicator.startAnimating() }
        if !children.contains(where: {$0.isKind(of: PostViewController.self)}) && !children.contains(where: {$0.isKind(of: SpotViewController.self)}) {
            setUpNavBar()
        }
    }
    
    deinit {
        print("deinit")
    }
    
    func setUserInfo() {
        
        /// get  userInfo on first load
        if userInfo == nil && id == uid {
            if mapVC.userInfo == nil { return }
            userInfo = mapVC.userInfo
            
        } else if passedUsername != nil {
            getUserFromUsername()
        }
        
        /// set profile info as soon as possible to avoid leaks
        if !children.contains(where: {$0.isKind(of: PostViewController.self)}) && !children.contains(where: {$0.isKind(of: SpotViewController.self)}) {
            mapVC.profileViewController = self; mapVC.selectedProfileID = id }

    }
    
    func resetMap() {
        
        let annotations = mapVC.mapView.annotations
        
        /// set profile view controller for map filtering and drawer animations
        mapVC.profileViewController = self
        mapVC.spotViewController = nil
        mapVC.nearbyViewController = nil
        mapVC.selectedProfileID = id
        
        /// selectedProfileID == "" used interchangeably with profileViewController == nil on map for filtering - should remove for redundancy
        mapVC.mapView.removeAnnotations(annotations)
        mapVC.hideNearbyButtons()
        mapVC.postsList.removeAll()
        
        if openSpotID != "" { return } /// dont animate profile if opening spot right away
        
        if passedCamera != nil {
            mapVC.mapView.setCamera(passedCamera, animated: false)
            passedCamera = nil
        } else {
            mapVC.animateToProfileLocation(active: uid == id, coordinate: CLLocationCoordinate2D())
        }
    }
    
    func runFunctions() {
        
        // user info only nil when its active user or passed from a profile tap of a non-friend user
        if userInfo == nil {
            /// will call runFunctions() again on updateUser from notification for current user, get user from username for non-active user
            if mapVC.userInfo == nil || id != uid { return }
            userInfo = mapVC.userInfo
            userInfo.friendsList = mapVC.friendsList
        } else if id == "" { return } /// patch fix for a crash when id = "". will just show a blank screen for now
                        
        add(asChildViewController: profileSpotsController)
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        sec0Height = 127 - navBarHeight

        /// check if active user is friends with this profile
        if uid != id && !mapVC.friendIDs.contains(id) {
            getFriendRequestInfo()
        } else {
            status = .friends
        }
            
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.activityIndicator.stopAnimating()
        }
    }
    
    @objc func updateUser(_ notification: NSNotification) {

        if userInfo == nil {
            runFunctions()
            setUpNavBar()
            
        } else {
            /// update userInfo even if its not nil if current user
            if id == uid { userInfo = mapVC.userInfo }
            tableView.reloadData()
        }
    }
        
    func addEmptyState() {
        
        let tabBarHeight = mapVC.customTabBar.tabBar.frame.height

        addFirstSpotButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 95, y: UIScreen.main.bounds.height - mapVC.halfScreenY - tabBarHeight - 64, width: 190, height: 47))
        addFirstSpotButton.setImage(UIImage(named: "ProfileEmptyState"), for: .normal)
        addFirstSpotButton.addTarget(self, action: #selector(addFirstSpotTap(_:)), for: .touchUpInside)
        
        DispatchQueue.main.async {
            self.view.addSubview(self.addFirstSpotButton)
            self.tableView.reloadData()
        }
    }
        
    @objc func addFirstSpotTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
            vc.mapVC = mapVC
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromTop
            mapVC.navigationController?.view.layer.add(transition, forKey: kCATransition)
            mapVC.navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func removeEmptyState() {
        if addFirstSpotButton != nil { addFirstSpotButton.removeFromSuperview(); addFirstSpotButton = nil }
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
        tableView.register(ProfileSegHeader.self, forHeaderFooterViewReuseIdentifier: "ProfileSegHeader")
        tableView.register(ProfileSegCell.self, forCellReuseIdentifier: "ProfileSegCell")
        tableView.register(NotFriendsCell.self, forCellReuseIdentifier: "NotFriendsCell")
        
        view.addSubview(tableView)
        view.addSubview(shadowScroll)
                
        view.addGestureRecognizer(shadowScroll.panGestureRecognizer)
        tableView.removeGestureRecognizer(tableView.panGestureRecognizer)
        profileSpotsController.spotsCollection.removeGestureRecognizer(profileSpotsController.spotsCollection.panGestureRecognizer)
        profilePostsController.postsCollection.removeGestureRecognizer(profilePostsController.postsCollection.panGestureRecognizer)
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.isHidden = true
        tableView.addSubview(activityIndicator)
    }
    
    func setUpNavBar() {
        // this is the only nav bar that uses a titleView
        /// set title to username and spotscore
                
        mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
        mapVC.navigationController?.navigationBar.isTranslucent = mapVC.prePanY != 0
        mapVC.navigationController?.navigationBar.removeShadow()
        mapVC.prePanY == 0 ? mapVC.navigationController?.navigationBar.addBackgroundImage(alpha: 1.0) : mapVC.navigationController?.navigationBar.removeBackgroundImage()
        
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
        mapVC.toggleMapTouch(enable: false) /// patch fix, maybe. map wasn't receiving touch events on profile occasionally for some reason.
        
        if !(parent is CustomTabBar) {
            
            let backButton = UIBarButtonItem(image: UIImage(named: "CircleBackButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(removeProfile(_:)))
            backButton.imageInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 0)
            mapVC.navigationItem.leftBarButtonItem = backButton

            /// right bar button item = more menu
            if id != uid {
                let moreButton = UIBarButtonItem(image: UIImage(named: "MoreBarButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(openMoreMenu(_:)))
                moreButton.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -2)
                mapVC.navigationItem.rightBarButtonItem = moreButton
            }

        } else {
            let settingsButton = UIBarButtonItem(image: UIImage(named: "SettingsIcon")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(openSettings(_:)))
            settingsButton.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: -2)
            mapVC.navigationItem.rightBarButtonItem = settingsButton
            
            let addFriendsButton = UIBarButtonItem(image: UIImage(named: "ProfileAddFriends")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(openAddFriends(_:)))
            addFriendsButton.imageInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 0)
            mapVC.navigationItem.leftBarButtonItem = addFriendsButton
        }
        
        mapVC.selectedProfileID = id
        mapVC.profileViewController = self
        mapVC.spotViewController = nil
        mapVC.nearbyViewController = nil
    }
 
    func reloadProfile() {
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
    
    func animateRemoveProfile() {
        Mixpanel.mainInstance().track(event: "ProfileSwipeToExit")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2) { [weak self] in
                guard let self = self else { return }
                self.view.frame = CGRect(x: UIScreen.main.bounds.width, y: self.view.frame.minY, width: self.view.frame.width, height: self.view.frame.height)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.removeProfile()
            }
        }
    }
    
    @objc func removeProfile(_ sender: UIBarButtonItem) {
        removeProfile()
    }
    
    func removeProfile() {
        
        Mixpanel.mainInstance().track(event: "ProfileRemove")
        
        mapVC.mapView.showsUserLocation = true
        mapVC.postsList.removeAll()
        mapVC.selectedProfileID = ""
        mapVC.profileViewController = nil
        mapVC.navigationItem.rightBarButtonItem = UIBarButtonItem()
        
        profilePostsController.active = false
        profileSpotsController.active = false
        
        /// this is like the equivalent of running a viewWillAppear method from the underneath view controller
        if let nearbyVC = parent as? NearbyViewController{
            nearbyVC.resetView()
            
        } else if let postVC = parent as? PostViewController {
            postVC.resetView()
            if commentsSelectedPost != nil { openComments() }
            
        } else if let profileVC = parent as? ProfileViewController {
            
            profileVC.resetProfile()
            profileVC.tableView.reloadData()
            openFriendsList()
            
        } else if let spotVC = parent as? SpotViewController {
            spotVC.resetView()

        } else if let notificationsVC = parent as? NotificationsViewController {
            notificationsVC.resetView()
            notificationsVC.checkForRequests()
        }
        
        ///remove listeners early to avoid reference being called after dealloc
        
        profilePostsController.removeListeners()
        profileSpotsController.removeListeners()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("InitialUserLoad"), object: nil)
            
        self.remove(asChildViewController: profileSpotsController)
        self.remove(asChildViewController: profilePostsController)
        
        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()
    }
    
    @objc func rightSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex == 1 {
            guard let header = tableView.headerView(forSection: 1) as? ProfileSegHeader else { return }
            header.animateBar(index: 0)
        }
    }
    
    @objc func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex == 0 {
            guard let header = tableView.headerView(forSection: 1) as? ProfileSegHeader else { return }
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
            friendsListVC.friendIDs = profileVC.userInfo.friendIDs.reversed()
            if id == uid { friendsListVC.friendsList = profileVC.userInfo.friendsList.reversed() } /// already reversed for non-active user
            
            /// set table offset on return to friendslist to keep users scroll distance
            friendsListVC.tableOffset = profileVC.friendsListScrollDistance
            profileVC.friendsListScrollDistance = 0
            
            DispatchQueue.main.async {
                profileVC.present(friendsListVC, animated: true, completion: nil)
            }
        }
    }
    
    func editProfile() {
        if let editProfileVC = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "EditProfile") as? EditProfileViewController {
            editProfileVC.profileVC = self
            DispatchQueue.main.async {
                self.present(editProfileVC, animated: true, completion: nil)
            }
        }
    }
    
    @objc func openSettings(_ sender: UIBarButtonItem) {
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "Settings") as? SettingsViewController {
            vc.profileVC = self
            vc.mapVC = mapVC
            DispatchQueue.main.async {
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    @objc func openAddFriends(_ sender: UIButton) {
        if let vc = storyboard?.instantiateViewController(identifier: "FindFriends") as? FindFriendsController {
            vc.mapVC = mapVC
            present(vc, animated: true, completion: nil)
        }
    }
    
    func resetIndex(index: Int) {
        
        let minY = mapVC.prePanY == 0 ? sec0Height : 0

        if index == 0 {
            DispatchQueue.main.async {
                self.remove(asChildViewController: self.profilePostsController)
                self.add(asChildViewController: self.profileSpotsController)
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: minY), animated: false)
                
                ///reset content offsets so scroll stays smooth
                if self.profilePostsController.postsCollection.contentOffset.y > 0 || self.profileSpotsController.spotsCollection.contentOffset.y > 0  {
                    self.shadowScroll.contentOffset.y = self.sec0Height + self.profileSpotsController.spotsCollection.contentOffset.y
                }
                
                self.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - self.sec0Height, self.profileSpotsController.spotsCollection.contentSize.height + 300))
            }
            
        } else {
            DispatchQueue.main.async {
            
                self.remove(asChildViewController: self.profileSpotsController)
                self.add(asChildViewController: self.profilePostsController)
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: minY), animated: false)

                ///reset content offsets so scroll stays smooth
                if self.profilePostsController.postsCollection.contentOffset.y > 0 || self.profileSpotsController.spotsCollection.contentOffset.y > 0  {
                    self.shadowScroll.contentOffset.y = self.sec0Height + self.profilePostsController.postsCollection.contentOffset.y
                }
                
                /// reset content size for current collection
                self.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - self.sec0Height, self.profilePostsController.postsCollection.contentSize.height + self.sec0Height + 250))
            }
        }
        
        selectedIndex = index
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
        
    func resetProfile() {

        setUpNavBar()
        /// expandProfile to full screen if it was full screen and scrolled at all before adding childVC
        if shadowScroll != nil { shadowScroll.contentOffset.y > 0 ? expandProfile(reset: true) : profileToHalf() }
                
        mapVC.profileViewController = self
        mapVC.spotViewController = nil
        mapVC.nearbyViewController = nil
        mapVC.selectedProfileID = self.id
        
        mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
        if self.parent is CustomTabBar { mapVC.customTabBar.tabBar.isHidden = false }
        
        selectedIndex == 0 ? profileSpotsController.resetView() : profilePostsController.resetView()
    }
    
    func expandProfile(reset: Bool) {
        
        // only can scroll if active seg is loaded
        shadowScroll.isScrollEnabled = (selectedIndex == 0 && profileSpotsController.loaded) || (selectedIndex == 1 && profilePostsController.loaded)
        
        navigationController?.navigationBar.addBackgroundImage(alpha: 1.0)
        navigationController?.navigationBar.isTranslucent = false
        /// no shadow on profile even with translucent nav bar 
        mapVC.navigationController?.navigationBar.removeShadow()
        mapVC.removeBottomBar()
        
        let preAnimationY = mapVC.customTabBar.tabBar.isHidden ? mapVC.tabBarClosedY : mapVC.tabBarOpenY /// offset from return to profile seems to be about the same even when coming from half/closed screen 
        let preAnimationOffset = shadowScroll.contentOffset.y
        mapVC.prePanY = 0
        
        UIView.animate(withDuration: 0.15) {
            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height )
            self.shadowScroll.contentOffset.y = preAnimationOffset + preAnimationY! - 20
            /// this is hacky but the content view was sliding down with the animation to top after post showing and this seems to work for most screen sizes
            // need to adjust for half screen and closed screen transitions from spot pages 
        }
    }
    
    func profileToHalf() {
        
        if tableView == nil { return }
        
        /// reset scrolls
        tableView.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: 0), animated: false)
        shadowScroll.setContentOffset(CGPoint(x: tableView.contentOffset.x, y: 0), animated: false)
        shadowScroll.isScrollEnabled = false
        resetSegs()
        
        self.navigationController?.navigationBar.removeBackgroundImage()
        self.navigationController?.navigationBar.isTranslucent = true
        mapVC.navigationController?.navigationBar.removeShadow()
        mapVC.removeBottomBar()
        
        mapVC.prePanY = mapVC.halfScreenY
        UIView.animate(withDuration: 0.15) {
            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: self.mapVC.halfScreenY, width: self.view.frame.width, height: UIScreen.main.bounds.height - self.mapVC.halfScreenY)
        }
    }
    
    func resetSegs() {
        profileSpotsController.spotsCollection.setContentOffset(CGPoint(x: profileSpotsController.spotsCollection.contentOffset.x, y: 0), animated: false)
        profilePostsController.postsCollection.setContentOffset(CGPoint(x: profilePostsController.postsCollection.contentOffset.x, y: 0), animated: false)
    }
    
    func getUserFromUsername() {
        
        let query = self.db.collection("users").whereField("username", isEqualTo: passedUsername!)
        
        query.getDocuments { [weak self] (snap, err) in
            
            do {
                guard let self = self else { return }
                
                let userInfo = try snap?.documents.first?.data(as: UserProfile.self)
                guard var info = userInfo else { return }
                info.id = snap!.documents.first?.documentID ?? ""
                
                self.id = info.id!
                self.userInfo = info
                self.runFunctions()
                self.setUpNavBar()

            } catch { return }
        }
    }
}



extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return userInfo == nil ? 0 : status == nil ? 1 : 2
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
                let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileSegCell", for: indexPath) as! ProfileSegCell
                cell.setUp(selectedIndex: selectedIndex, profilePosts: profilePostsController, profileSpots: profileSpotsController)
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
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ProfileSegHeader") as! ProfileSegHeader
            header.setUp(index: selectedIndex, emptyState: addFirstSpotButton != nil, status: status ?? .add)
            return header
        }
        else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 40 : 0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 127 : UIScreen.main.bounds.height - 137
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        /// dont offset scroll if drawer is moved
        if mapVC.prePanY != mapVC.customTabBar.view.frame.minY { return }
        
        /// reset scrolling before selected view controller has loaded content
        if (selectedIndex == 0 && !profileSpotsController.loaded) || (selectedIndex == 1 && !profilePostsController.loaded) {

            DispatchQueue.main.async {
                let offsetY = self.mapVC.prePanY == 0 ? self.sec0Height : 0
                self.shadowScroll.setContentOffset(CGPoint(x: self.shadowScroll.contentOffset.x, y: offsetY), animated: false)
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: offsetY), animated: false)
                return
            }
        }
        
        /// only recognize on the main  scroll
        if scrollView.tag != 80 { return }
        if selectedIndex == 0 && profileSpotsController.children.count > 0 { return }
        if selectedIndex == 1 && profilePostsController.children.count > 0 { return }
        
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
                    
                    self.selectedIndex == 0 ? self.profileSpotsController.spotsCollection.setContentOffset(CGPoint(x: self.profileSpotsController.spotsCollection.contentOffset.x, y: 0), animated: false) : self.profilePostsController.postsCollection.setContentOffset(CGPoint(x: self.profilePostsController.postsCollection.contentOffset.x, y: 0), animated: false)
                    return
                }
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.shadowScroll.contentOffset.y), animated: false)
                self.selectedIndex == 0 ? self.profileSpotsController.spotsCollection.setContentOffset(CGPoint(x: self.profileSpotsController.spotsCollection.contentOffset.x, y: 0), animated: false) : self.profilePostsController.postsCollection.setContentOffset(CGPoint(x: self.profilePostsController.postsCollection.contentOffset.x, y: 0), animated: false)
                /// offset current content collection
                
            } else if self.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) is ProfileSegCell {
                
                self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x, y: self.sec0Height), animated: false)
                
                switch self.selectedIndex {
                
                case 0:
                    self.profileSpotsController.spotsCollection.setContentOffset(CGPoint(x: self.profileSpotsController.spotsCollection.contentOffset.x, y: self.shadowScroll.contentOffset.y - self.sec0Height), animated: false)

                case 1:
                    self.profilePostsController.postsCollection.setContentOffset(CGPoint(x: self.profilePostsController.postsCollection.contentOffset.x, y: self.shadowScroll.contentOffset.y - self.sec0Height), animated: false)
                    
                default: return
                }
            }
        }

    }
    
    func scrollSegmentToTop() {
        
        if mapVC.prePanY != 0 { return }
        
        if shadowScroll.contentOffset.y > sec0Height {
                        
            UIView.animate(withDuration: 0.2) {
                self.selectedIndex == 0 ? self.profileSpotsController.spotsCollection.setContentOffset(CGPoint(x: self.profileSpotsController.spotsCollection.contentOffset.x, y: 0), animated: false) : self.profilePostsController.postsCollection.setContentOffset(CGPoint(x: self.profilePostsController.postsCollection.contentOffset.x, y: 0), animated: false)
            } completion: { (_) in
                self.shadowScroll.setContentOffset(CGPoint(x: self.shadowScroll.contentOffset.x, y: self.sec0Height), animated: false)
            }
        }
    }
}
///https://stackoverflow.com/questions/13221488/uiscrollview-within-a-uiscrollview-how-to-keep-a-smooth-transition-when-scrolli

class UserViewCell: UITableViewCell {
    
    var pullLine: UIButton!
    var profileImage: UIImageView!
    var editProfileButton: UIButton!
    var nameLabel, usernameLabel, cityLabel: UILabel!
    var friendCountButton: UIButton!
    var cityIcon: UIImageView!
    var separatorView: UIView!
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var userInfo: UserProfile!
    unowned var mapVC: MapViewController!
    
    func setUp(user: UserProfile, mapVC: MapViewController, status: ProfileViewController.friendStatus) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        userInfo = user
        self.mapVC = mapVC
        
        resetCell()
        
        let pullLine = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 21.5, y: 0, width: 43, height: 14.5))
        pullLine.contentEdgeInsets = UIEdgeInsets(top: 7, left: 5, bottom: 0, right: 5)
        pullLine.setImage(UIImage(named: "PullLine"), for: .normal)
        pullLine.addTarget(self, action: #selector(lineTap(_:)), for: .touchUpInside)
        addSubview(pullLine)

        profileImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 74, y: 14, width: 60, height: 60))
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
        
        nameLabel = UILabel(frame: CGRect(x: 14, y: 28, width: UIScreen.main.bounds.width - 120, height: 18))
        nameLabel.text = user.name
        nameLabel.textColor = UIColor.white
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 17.5)!
        nameLabel.sizeToFit()
        addSubview(nameLabel)
        
        if uid == user.id {
            editProfileButton = UIButton(frame: CGRect(x: nameLabel.frame.maxX, y: nameLabel.frame.minY - 5, width: 32, height: 32))
            editProfileButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            editProfileButton.setImage(UIImage(named: "EditPost")!, for: .normal)
            editProfileButton.contentMode = .scaleAspectFit
            editProfileButton.addTarget(self, action: #selector(editProfileTap(_:)), for: .touchUpInside)
            self.addSubview(editProfileButton)
        }
        
        usernameLabel = UILabel(frame: CGRect(x: 14, y: nameLabel.frame.maxY + 3, width: UIScreen.main.bounds.width - 120, height: 15))
        usernameLabel.text = "@" + user.username
        usernameLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        usernameLabel.sizeToFit()
        addSubview(usernameLabel)
        
        // set user's city
        if user.currentLocation != "" {
            
            cityIcon = UIImageView(frame: CGRect(x: 12.5, y: usernameLabel.frame.maxY + 23, width: 10.8, height: 14.54))
            cityIcon.image = UIImage(named: "ProfileCityIcon")
            addSubview(cityIcon)
            
            cityLabel = UILabel(frame: CGRect(x: cityIcon.frame.maxX + 5, y: usernameLabel.frame.maxY + 24, width: UIScreen.main.bounds.width - 120, height: 20))
            cityLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
            cityLabel.text = user.currentLocation
            cityLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
            cityLabel.sizeToFit()
            addSubview(cityLabel)
            
            separatorView = UIView(frame: CGRect(x: cityLabel.frame.maxX + 9, y: cityLabel.frame.midY - 0.5,  width: 5, height: 2))
            separatorView.backgroundColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
            separatorView.layer.cornerRadius = 0.5
            addSubview(separatorView)
        }
        
        let friendsX = cityLabel == nil ? 14 : separatorView.frame.maxX + 9
        
        friendCountButton = UIButton(frame: CGRect(x: friendsX, y: usernameLabel.frame.maxY + 24, width: 100, height: 18))
        var friendString = "\(user.friendIDs.count) friend"; if user.friendIDs.count > 1 { friendString += "s" }
        friendCountButton.setTitle(friendString, for: .normal)
        friendCountButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        friendCountButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 13)
        friendCountButton.contentHorizontalAlignment = .left
        friendCountButton.contentVerticalAlignment = .top
        
        if status == .friends {
            friendCountButton.addTarget(self, action: #selector(openFriendsList(_:)), for: .touchUpInside)
        }
        
        addSubview(friendCountButton)
    }
    
    @objc func editProfileTap(_ sender: UIButton) {
        if let profileVC = viewContainingController() as? ProfileViewController { profileVC.editProfile() }
    }
        
    
    @objc func openFriendsList(_ sender: UIButton) {
        if let friendsListVC = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "FriendsList") as? FriendsListController {
            if let profileVC = self.viewContainingController() as? ProfileViewController {
                friendsListVC.profileVC = profileVC
                friendsListVC.friendIDs = userInfo.friendIDs.reversed()
                if uid == userInfo.id {
                    userInfo.friendsList = mapVC.friendsList.reversed()
                }
                if !userInfo.friendsList.isEmpty { friendsListVC.friendsList = userInfo.friendsList }
                DispatchQueue.main.async {
                    profileVC.present(friendsListVC, animated: true, completion: nil)
                }
            }
        }
    }
    
    func resetCell() {
        if pullLine != nil { pullLine.setImage(UIImage(), for: .normal) }
        if profileImage != nil { profileImage.image = UIImage() }
        if nameLabel != nil { nameLabel.text = "" }
        if editProfileButton != nil { editProfileButton.setImage(UIImage(), for: .normal) }
        if usernameLabel != nil { usernameLabel.text = "" }
        if cityLabel != nil { cityLabel.text = "" }
        if cityIcon != nil { cityIcon.image = UIImage() }
        if separatorView != nil { separatorView.backgroundColor = nil }
        if friendCountButton != nil { friendCountButton.setTitle("", for: .normal) }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profileImage != nil { profileImage.sd_cancelCurrentImageLoad() }
    }
    
    @objc func lineTap(_ sender: UIButton) {
        guard let profileVC = viewContainingController() as? ProfileViewController else { return }
        profileVC.mapVC.animateToFullScreen()
    }
}

class ProfileSegHeader: UITableViewHeaderFooterView {
    
    var segmentedControl: UISegmentedControl!
    var buttonBar: UIView!
    var shadowImage: UIImageView!
    var separatorCover: UIView!
    var selectedIndex = 0
            
    func setUp(index: Int, emptyState: Bool, status: ProfileViewController.friendStatus) {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        self.selectedIndex = index
        
        if segmentedControl != nil { segmentedControl.removeFromSuperview() }
        segmentedControl = ProfileSegmentedControl(frame: CGRect(x: UIScreen.main.bounds.width * 1/6, y: 10, width: UIScreen.main.bounds.width * 2/3, height: 20))
        segmentedControl.backgroundColor = nil
        segmentedControl.selectedSegmentIndex = index
        
        let postSegIm = index == 0 ? UIImage(named: "SpotSeg") : UIImage(named: "SpotSeg")?.alpha(0.6)
        let spotSegIm = index == 0 ? UIImage(named: "PostSeg")?.alpha(0.6) : UIImage(named: "PostSeg")
        
        segmentedControl.insertSegment(with: postSegIm, at: 0, animated: false)
        segmentedControl.insertSegment(with: spotSegIm, at: 1, animated: false)
        
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
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
        
        if separatorCover != nil { separatorCover.backgroundColor = nil }
        separatorCover = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 1, y: 0, width: 2, height: 40))
        separatorCover.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(separatorCover)
    
        /// hacky shadow for mask under seg view on profile
        if shadowImage != nil { shadowImage.image = UIImage() }
        shadowImage = UIImageView(frame: CGRect(x: -10, y: 37, width: UIScreen.main.bounds.width + 20, height: 6))
        shadowImage.image = UIImage(named: "NavShadowLine")
        shadowImage.clipsToBounds = false
        shadowImage.contentMode = .scaleAspectFill
        addSubview(shadowImage)
        
        
        if emptyState || status != .friends {
            /// disable on empty state
            segmentedControl.isEnabled = false
            buttonBar.isHidden = true
        }
    }
    
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
                
        Mixpanel.mainInstance().track(event: "ProfileSwitchSegments")

        // scroll to top of collection on same index tap
        if sender.selectedSegmentIndex == selectedIndex {
            guard let profileVC = viewContainingController() as? ProfileViewController else { return }
            profileVC.scrollSegmentToTop()
            return
        }
        
        // change selected segment on new index tap
        animateBar(index: sender.selectedSegmentIndex)
    }
    
    func animateBar(index: Int) {
        
        guard let profileVC = viewContainingController() as? ProfileViewController else { return }
        let minX = UIScreen.main.bounds.width * CGFloat(1 + index) / 3 - 20
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.15) {  self.buttonBar.frame = CGRect(x: minX, y: self.segmentedControl.frame.maxY + 3, width: 40, height: 1.5)
                
                let postSegIm = index == 0 ? UIImage(named: "SpotSeg") : UIImage(named: "SpotSeg")?.alpha(0.6)
                let spotSegIm = index == 0 ? UIImage(named: "PostSeg")?.alpha(0.6) : UIImage(named: "PostSeg")
                
                self.segmentedControl.setImage(postSegIm, forSegmentAt: 0)
                self.segmentedControl.setImage(spotSegIm, forSegmentAt: 1)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { profileVC.resetIndex(index: index) }
    }
}

class ProfileSegCell: UITableViewCell {
    
    func setUp(selectedIndex: Int, profilePosts: ProfilePostsViewController, profileSpots: ProfileSpotsViewController) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        switch selectedIndex {
        
        case 0:
            self.addSubview(profileSpots.view)

        case 1:
            self.addSubview(profilePosts.view)

        default:
            return
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
            addFriendButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 117.5, y: 100, width: 235, height: 39))
            addFriendButton.setImage(UIImage(named: "AddFriendButton"), for: .normal)
            addFriendButton.addTarget(self, action: #selector(addFriendTap(_:)), for: .touchUpInside)
            self.addSubview(addFriendButton)
            
        case .received:
            /// set up view with option to accept / deny request
            
            receivedLabel = UILabel(frame: CGRect(x: 20, y: 70, width: UIScreen.main.bounds.width - 40, height: 20))
            receivedLabel.text = "Sent you a friend request"
            receivedLabel.textAlignment = .center
            receivedLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            receivedLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            self.addSubview(receivedLabel)
            
            acceptButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 117.5, y: receivedLabel.frame.maxY + 15, width: 235, height: 39))
            acceptButton.setImage(UIImage(named: "ProfileAcceptButton"), for: .normal)
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
            pendingLabel = UILabel(frame: CGRect(x: 20, y: 120, width: UIScreen.main.bounds.width - 40, height: 20))
            pendingLabel.text = "Friend request pending"
            pendingLabel.textAlignment = .center
            pendingLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
            pendingLabel.textColor = UIColor(named: "SpotGreen")
            self.addSubview(pendingLabel)
            
        default:
            ///show friend request removed
            removedLabel = UILabel(frame: CGRect(x: 20, y: 110, width: UIScreen.main.bounds.width - 40, height: 20))
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
        
        let activeUser = self.activeUser!
        let userInfo = self.userInfo!
        
        DispatchQueue.global(qos: .utility).async { self.addFriend(senderProfile: activeUser, receiverID: userInfo.id!) }
        
        if let profileVC = viewContainingController() as? ProfileViewController {
            profileVC.status = .pending
            profileVC.tableView.reloadData()
        }
    }
    
    @objc func acceptTap(_ sender: UIButton) {
        /// add friend in db
        Mixpanel.mainInstance().track(event: "ProfileFriendRequestAccepted")

        let friendID = userInfo.id!
        let uid = self.uid
        
        DispatchQueue.global(qos: .userInitiated).async { self.acceptFriendRequest(friendID: friendID, uid: uid, username: self.activeUser.username) }
                
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("friendRequestAccept"), object: nil, userInfo: infoPass)
        
        if let profileVC = viewContainingController() as? ProfileViewController {
            profileVC.status = .friends
            profileVC.tableView.reloadData()
        }
    }
    
    @objc func removeTap(_ sender: UIButton) {
        /// remove request in db
        Mixpanel.mainInstance().track(event: "ProfileFriendRequestRemoved")
        
        let friendID = self.userInfo.id!
        let uid = self.uid
        
        DispatchQueue.global(qos: .utility).async { self.removeFriendRequest(friendID: friendID, uid: uid) }
        
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("friendRequestReject"), object: nil, userInfo: infoPass)
        
        if let profileVC = viewContainingController() as? ProfileViewController {
            profileVC.status = .denied
            profileVC.tableView.reloadData()
        }
    }
    
    func resetCell() {
        if receivedLabel != nil { receivedLabel.text = "" }
        if pendingLabel != nil { pendingLabel.text = "" }
        if removedLabel != nil { removedLabel.text = "" }
        if addFriendButton != nil { addFriendButton.setImage(UIImage(), for: .normal) }
        if acceptButton != nil { acceptButton.setImage(UIImage(), for: .normal) }
        if removeButton != nil { removeButton.setTitle("", for: .normal) }
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

/// more menu functions
extension ProfileViewController: UIGestureRecognizerDelegate {
    
    @objc func openMoreMenu(_ sender: UIBarButtonItem) {
        
        let addRemove = status == .friends && id != "T4KMLe3XlQaPBJvtZVArqXQvaNT2"
        let height: CGFloat = addRemove ? 167 : 122
        
        editView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 112, y: UIScreen.main.bounds.height/2 - 180, width: 224, height: height))
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
        
        exitButton = UIButton(frame: CGRect(x: editView.frame.width - 37, y: 7, width: 30, height: 30))
        exitButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        exitButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        exitButton.addTarget(self, action: #selector(exitEditOverview(_:)), for: .touchUpInside)
        editView.addSubview(exitButton)
        
        if addRemove {
            let removeButton = UIButton(frame: CGRect(x: 50, y: 37, width: 124, height: 49))
            removeButton.setTitle("Remove friend", for: .normal)
            removeButton.setTitleColor(UIColor(red: 0.704, green: 0.704, blue: 0.704, alpha: 1.0), for: .normal)
            removeButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 16)
            removeButton.contentHorizontalAlignment = .center
            removeButton.contentVerticalAlignment = .center
            removeButton.titleLabel?.textAlignment = .center
            removeButton.addTarget(self, action: #selector(removeFriendTap(_:)), for: .touchUpInside)
            editView.addSubview(removeButton)
        }
        
        let minY: CGFloat = addRemove ? 90 : 37
        
        let reportButton = UIButton(frame: CGRect(x: 50, y: minY, width: 124, height: 49))
        reportButton.setTitle("Report user", for: .normal)
        reportButton.setTitleColor(UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1), for: .normal)
        reportButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 16)
        reportButton.titleLabel?.textAlignment = .center
        reportButton.contentHorizontalAlignment = .center
        reportButton.contentVerticalAlignment = .center
        reportButton.addTarget(self, action: #selector(reportUserTap(_:)), for: .touchUpInside)
        editView.addSubview(reportButton)
        
        mapVC.navigationController?.navigationBar.isUserInteractionEnabled = false
    }
    
    @objc func tapExitEditOverview(_ sender: UIButton) {
        if loadingIndicator.isAnimating() { return } /// don't return while deletes are happening
        exitEditOverview()
    }
    
    @objc func exitEditOverview(_ sender: UIButton) {
        if loadingIndicator.isAnimating() { return }
        exitEditOverview()
    }
    
    func exitEditOverview() {
        if editView == nil { return }
        for sub in editView.subviews { sub.removeFromSuperview()}
        editView.removeFromSuperview()
        if editMask != nil { editMask.removeFromSuperview() }
        editView = nil
        mapVC.navigationController?.navigationBar.isUserInteractionEnabled = true
    }
    
    @objc func removeFriendTap(_ sender: UIButton) {
        
        sender.isUserInteractionEnabled = false
        
        let alert = UIAlertController(title: "Remove Friend?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { action in
                                        
                                        switch action.style{
                                        
                                        case .destructive:
                                            Mixpanel.mainInstance().track(event: "UserUnfriended")
                                            let friendID = self.id
                                            self.updateLocally(friendID: friendID)
                                            self.makeFirebaseDeletes(friendID: friendID)
                                            
                                        case .default:
                                            return
                                            
                                        case .cancel:
                                            self.exitEditOverview()
                                            
                                        @unknown default:
                                            fatalError()
                                        }}))
        
        self.present(alert, animated: true, completion: nil)
    }
        
    func updateLocally(friendID: String) {
        
        /// remove from unfriended
        userInfo.friendsList.removeAll(where: {$0.id == uid})
        userInfo.friendIDs.removeAll(where: {$0 == uid})
        
        /// remove from active user
        mapVC.userInfo.friendsList.removeAll(where: {$0.id == friendID})
        mapVC.userInfo.friendIDs.removeAll(where: {$0 == friendID})
        
        mapVC.deletedFriendIDs.append(friendID)
        
        if let feedVC = mapVC.customTabBar.viewControllers?.first(where: {$0 is FeedViewController}) as? FeedViewController {
            
            /// add to deleted post ids so that post doesnt re-enter feed
            for post in feedVC.friendPosts { if post.posterID == friendID { mapVC.deletedPostIDs.append(post.id!) } }
            
            feedVC.friendPosts.removeAll(where: {$0.posterID == friendID})
            feedVC.nearbyPosts.removeAll(where: {$0.posterID == friendID})
            
            if feedVC.postVC != nil {
                feedVC.postVC.postsList.removeAll(where: {$0.posterID == friendID})
                if feedVC.postVC.tableView != nil { feedVC.postVC.tableView.reloadData() }
            }
        }
        
        if let nearbyVC = mapVC.customTabBar.viewControllers?.first(where: {$0 is NearbyViewController}) as? NearbyViewController {
            nearbyVC.cityFriends.removeAll(where: {$0.user.id == friendID})
            nearbyVC.usersCollection.reloadData()
        }
        
        status = .add
        tableView.reloadData()
    }
    
    func makeFirebaseDeletes(friendID: String) {
        
        loadingIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 200, width: UIScreen.main.bounds.width, height: 30))
        loadingIndicator.startAnimating()
        editMask.addSubview(loadingIndicator)
        
        editMask.removeGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapExitEditOverview(_:))))
        exitButton.isEnabled = false
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            /// remove from both users friendsLists
            self.db.collection("users").document(uid).updateData(["friendsList" : FieldValue.arrayRemove([friendID])])
            self.db.collection("users").document(friendID).updateData(["friendsList" : FieldValue.arrayRemove([uid])])
            
            // need to use deleteIndex because need to ensure that the deletes work before exiting. Eventually need to move to background thread
            /// remove from both users posts
            var deleteIndex = 0
            
            self.removeFriendFromPosts(posterID: uid, friendID: friendID) { (complete) in
                deleteIndex += 1
                if deleteIndex == 4 {
                    self.exitEditOverview()
                }
            }
            
            self.removeFriendFromPosts(posterID: friendID, friendID: uid) { (complete) in
                deleteIndex += 1
                if deleteIndex == 4 {
                    self.exitEditOverview()
                }
            }
        
            /// remove from both users notifications
            self.removeFriendFromNotis(posterID: uid, friendID: friendID) { (complete) in
                deleteIndex += 1
                if deleteIndex == 4 {
                    self.exitEditOverview()
                }
            }
            
            self.removeFriendFromNotis(posterID: friendID, friendID: uid) { (complete) in
                deleteIndex += 1
                if deleteIndex == 4 {
                    self.exitEditOverview()
                }
            }
        }
    }
    
    @objc func reportUserTap(_ sender: UIButton) {
        let alert = UIAlertController(title: "Report user", message: "Describe why you're reporting this person:", preferredStyle: .alert)
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
                                            let friendID = self.id
                                            self.reportUser(reportedUser: friendID, description: textField.text ?? "")

                                        @unknown default:
                                            fatalError()
                                        }}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func reportUser(reportedUser: String, description: String) {
        
        let db = Firestore.firestore()
        let uuid = UUID().uuidString
        
        db.collection("contact").document(uuid).setData(["type": "report user", "reporterID" : uid, "reportedID": reportedUser, "description": description])
        
        exitEditOverview()
    }
}
