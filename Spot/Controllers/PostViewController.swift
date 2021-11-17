//
//  PostViewController.swift
//  Spot
//
//  Created by kbarone on 1/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Firebase
import CoreLocation
import Mixpanel
import FirebaseUI
import Geofirestore
import FirebaseFunctions

class PostViewController: UIViewController {

    lazy var postsList: [MapPost] = []

    var spotObject: MapSpot!
    var tableView: UITableView!
    var cellHeight, closedY, tabBarHeight, navBarHeight: CGFloat!
    var selectedPostIndex = 0 /// current row in posts table
    var parentVC: parentViewController = .feed
    var vcid = "" /// id of this post controller (in case there is more than 1 active at once)
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    unowned var mapVC: MapViewController!
    var commentNoti = false /// present commentsVC if opened from notification comment
    
    var tutorialImageIndex = 0
    var postsEmpty = false /// no available posts, show findFriendsCell
    
    var editView = false /// edit overview presented
    var editPostView = false /// edit post view presented
    var notFriendsView = false /// not friends view presented
    var editedPost: MapPost! /// selected post with edits
        
    var active = true
    var addedLocationPicker = false
    var openFriendsList = false
    
    private lazy var loadingQueue = OperationQueue()
    private lazy var loadingOperations = [String: PostImageLoader]()
    lazy var currentImageSet: (id: String, images: [UIImage]) = (id: "", images: [])
    
    enum parentViewController {
        case feed
        case spot
        case profile
        case notifications
    }
    
    deinit {
        print("deinit")
    }
  
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PostPageOpen")
        mapVC.hideNearbyButtons()
        
        if tableView == nil {
            
            vcid = UUID().uuidString
            self.setUpTable()
            
            guard let feedVC = parent as? FeedViewController else { return }
            feedVC.unhideFeedSeg()
            /// unhide feed seg in case it was hidden after user clicked off feed during initial load

        } else {
            if self.children.count != 0 { return }
            resetView()
           /// tableView.reloadData() / commented out bc was causing alives to restart animation unnecessarily. need to see if any unforseen consequences
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagSelect(_:)), name: NSNotification.Name("TagSelect"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        active = false
        cancelDownloads()
        if let feedVC = parent as? FeedViewController { feedVC.hideFeedSeg() }
    }
    
    func cancelDownloads() {
        
        // cancel image loading operations and reset map
        for op in loadingOperations {
            guard let imageLoader = loadingOperations[op.key] else { continue }
            imageLoader.cancel()
            loadingOperations.removeValue(forKey: op.key)
        }
        
        loadingQueue.cancelAllOperations()
        if parentVC != .spot { hideFeedButtons() } /// feed buttons needed for spot page too
        mapVC.toggleMapTouch(enable: false)
    }
    
    
    func setUpTable() {
        
        let tabBar = mapVC.customTabBar
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let safeBottom = window?.safeAreaInsets.bottom ?? 0
        
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)

        tabBarHeight = tabBar?.tabBar.frame.height ?? 44 + safeBottom
        closedY = !(tabBar?.tabBar.isHidden ?? false) ? tabBarHeight + 77 : safeBottom + 115
        cellHeight = UIScreen.main.bounds.width * 1.5
        cellHeight += tabBarHeight
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.tag = 16
        tableView.backgroundColor = UIColor(named: "FeedBlack")
        tableView.allowsSelection = false
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.prefetchDataSource = self
        tableView.isScrollEnabled = false
        tableView.contentInset = UIEdgeInsets(top: navBarHeight, left: 0, bottom: cellHeight + tabBarHeight, right: 0)
        tableView.register(PostCell.self, forCellReuseIdentifier: "PostCell")
        tableView.register(LoadingCell.self, forCellReuseIdentifier: "LoadingCell")
        tableView.register(PostFriendsCell.self, forCellReuseIdentifier: "PostFriendsCell")
        view.addSubview(tableView)

        DispatchQueue.main.async {
            
            self.tableView.reloadData()
            
            if !self.postsEmpty && !self.postsList.isEmpty {
                self.tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
            }
        }
                
        addPullLineAndNotifications()
        if UIScreen.main.bounds.height > 800 { addBottomMask() }
        
        if self.commentNoti {
            self.openComments()
            self.commentNoti = false
        }

        
        setUpNavBar()
    }
        
    func addPullLineAndNotifications() {
        /// broken out into its own function so it can be called on transition from tutorial to regular view
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyIndexChange(_:)), name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAddressChange(_:)), name: NSNotification.Name("PostAddressChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostTap(_:)), name: NSNotification.Name("FeedPostTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostLike(_:)), name: NSNotification.Name("PostLike"), object: nil)

        
        if parentVC != .feed { mapVC.toggleMapTouch(enable: true) }
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(topViewTableSwipe(_:)))

        let pullLine = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 6, y: navBarHeight - 1, width: 12, height: 20.5))
        pullLine.setImage(UIImage(named: "PullLine"), for: .normal)
        pullLine.addGestureRecognizer(pan)
        view.addSubview(pullLine)
    }
    
    func updateParentImageIndex(post: MapPost, row: Int) {
        if let feedVC = parent as? FeedViewController {
            if feedVC.selectedSegmentIndex == 0 {
                if feedVC.selectedPostIndex != selectedPostIndex { return } /// these should always be equal but caused a crash once for index out of bounds so checking that edge case
                feedVC.friendPosts[row].selectedImageIndex = post.selectedImageIndex
            } else {
                if feedVC.selectedPostIndex != selectedPostIndex { return }
                feedVC.nearbyPosts[row].selectedImageIndex = post.selectedImageIndex
            }
        } else if let profilePostsVC = parent as? ProfilePostsViewController {
            if profilePostsVC.postsList.count <= selectedPostIndex { return }
            profilePostsVC.postsList[row].selectedImageIndex = post.selectedImageIndex
        }
    }
    
    @objc func notifyPostLike(_ sender: NSNotification) {
        
        if let info = sender.userInfo as? [String: Any] {
            guard let id = info["id"] as? String else { return }
            if id != vcid { return }
            if let post = info["post"] as? MapPost { self.postsList[selectedPostIndex] = post }
        }
    }
    
    @objc func notifyIndexChange(_ sender: NSNotification) {

        if let info = sender.userInfo as? [String: Any] {
            
            guard let id = info["id"] as? String else { return }
            if id != vcid { return }
            
            ///update from likes or comments
            if let post = info["post"] as? MapPost { self.postsList[selectedPostIndex] = post }
            
            /// animate to next post after vertical scroll
            if let index = info["index"] as? Int {
                
            ///    if selectedPostIndex != index { if let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell { cell.animationCounter = 0; cell.postImage.animationImages?.removeAll() } }  /// reset animation counter so that next post, if gif, starts animating at 0
                selectedPostIndex = index

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.tableView.reloadData()
                    UIView.animate(withDuration: 0.25) { [weak self] in
                        guard let self = self else { return }
                       self.tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false) }}
                 //   self.tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: true)}
            } else {
                /// selected from map - here index represents the selected post's postID
                if let id = info["index"] as? String {
                    if let index = self.postsList.firstIndex(where: {$0.id == id}) {
                        self.selectedPostIndex = index
                        DispatchQueue.main.async {
                            UIView.animate(withDuration: 0.2) { [weak self] in
                                guard let self = self else { return }
                                self.tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            guard let self = self else { return }
                            self.tableView.reloadData()  }
                    }
                }
            }
        }
    }
    
    @objc func notifyAddressChange(_ sender: NSNotification) {
        // edit post address change
        if let info = sender.userInfo as? [String: Any] {
            
            if editedPost == nil { return }
            guard let coordinate = info["coordinate"] as? CLLocationCoordinate2D else { return }
            
            editedPost.postLat = coordinate.latitude
            editedPost.postLong = coordinate.longitude
            self.editPostView = true 
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.tableView.reloadData()
            }
        }
    }
    
    @objc func notifyPostTap(_ sender: NSNotification) {
        /// deselect annotation so tap works again
        for annotation in mapVC.mapView.selectedAnnotations { mapVC.mapView.deselectAnnotation(annotation, animated: false) }
        openDrawer(swipe: false)
    }
    
    @objc func tagSelect(_ sender: NSNotification) {
        /// selected a tagged user from the map tag table
        
        guard let infoPass = sender.userInfo as? [String: Any] else { return }
        guard let username = infoPass["username"] as? String else { return }
        guard let tag = infoPass["tag"] as? Int else { return }
        if tag != 1 { return } /// tag 1 for post tag
        
        guard let postCell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell else { return }
        if postCell.editPostView == nil { return }
        
        let cursorPosition = postCell.editPostView.postCaption.getCursorPosition()
        let text = postCell.editPostView.postCaption.text ?? ""
        let tagText = addTaggedUserTo(text: text, username: username, cursorPosition: cursorPosition)
        postCell.editPostView.postCaption.text = tagText
    }
    
    func resetView() {

        mapVC.postsList = postsList
        mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
        
        if parentVC == .notifications {
            if let tabBar = parent?.parent as? CustomTabBar {
                tabBar.view.frame = CGRect(x: 0, y: mapVC.tabBarClosedY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            }
        }
        
        setUpNavBar()
        
        if parentVC == .feed {
            
            mapVC.customTabBar.tabBar.isHidden = false
            if let feedVC = parent as? FeedViewController { feedVC.unhideFeedSeg() }

            if selectedPostIndex == 0 && tableView != nil {
                if postsList.count == 0 { self.mapVC.animateToFullScreen(); return }
                DispatchQueue.main.async { self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true) }
            }
        }
        
        ///notify map to show this post
        let firstOpen = !addedLocationPicker /// fucked up nav bar after edit post location
        let mapPass = ["selectedPost": selectedPostIndex as Any, "firstOpen": firstOpen, "parentVC": parentVC] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
        
        addedLocationPicker = false
        
        if openFriendsList { presentFriendsList() }
    }
    
    func setUpNavBar() {
        
        mapVC.navigationItem.leftBarButtonItem = nil
        mapVC.navigationItem.rightBarButtonItem = nil
        
        mapVC.setOpaqueNav()

        if parentVC == .feed { return }
        
        /// add exit button over top of feed for profile and spot page
        let backButton = UIBarButtonItem(image: UIImage(named: "CircleBackButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(exitPosts(_:)))
        backButton.imageInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 0)
        mapVC.navigationItem.leftBarButtonItem = backButton
        mapVC.navigationItem.title = ""
        mapVC.navigationItem.rightBarButtonItem = nil
    }
    
    func openComments() {
        
        if let commentsVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Comments") as? CommentsViewController {
            
            Mixpanel.mainInstance().track(event: "PostOpenComments")

            let post = self.postsList[selectedPostIndex]
            commentsVC.commentList = post.commentList
            commentsVC.post = post
            commentsVC.captionHeight = getCommentsCaptionHeight(caption: post.caption)
            commentsVC.postVC = self
            commentsVC.userInfo = UserDataModel.shared.userInfo
            present(commentsVC, animated: true, completion: nil)
        }
    }
    
    func getCommentsCaptionHeight(caption: String) -> CGFloat {
        
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 31, height: 20))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()
        return tempLabel.frame.height
    }
    
    func closeDrawer(swipe: Bool) {
                
        Mixpanel.mainInstance().track(event: "PostCloseDrawer", properties: ["swipe": swipe])

        guard let post = postsList[safe: selectedPostIndex] else { return }
        let tabBar = mapVC.customTabBar
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let safeBottom = window?.safeAreaInsets.bottom ?? 0
        let tabBarHeight = tabBar?.tabBar.frame.height ?? 44 + safeBottom

        let closedY = parentVC == .feed ? tabBarHeight + 84 : safeBottom + 115
        
        let maxZoom: CLLocationDistance = parentVC == .spot ? 300 : 600
        let adjust: CLLocationDistance = 0.00000345 * maxZoom
        let adjustedCoordinate = CLLocationCoordinate2D(latitude: post.postLat - Double(adjust), longitude: post.postLong)
        mapVC.mapView.animatedZoom(zoomRegion: MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: maxZoom, longitudinalMeters: maxZoom), duration: 0.4)

        let duration: TimeInterval = swipe ? 0.15 : 0.30
        guard let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell else { return }
      
        UIView.animate(withDuration: duration, animations: { [weak self] in
            guard let self = self else { return }
            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - closedY, width: UIScreen.main.bounds.width, height: closedY)
          ///  cell.postImage.frame = CGRect(x: cell.postImage.frame.minX, y: 0, width: cell.postImage.frame.width, height: cell.postImage.frame.height)
            if cell.topView != nil { cell.bringSubviewToFront(cell.topView) }
            if cell.tapButton != nil { cell.bringSubviewToFront(cell.tapButton) }
        })
        
        /// animate post view at same duration as animated zoom -> crash here? -> try to alleviate with weak self call. Could be reference to mapvc?
        UIView.animate(withDuration: 0.4, animations: { [weak self] in
            guard let self = self else { return }
            
            if let annoView = self.mapVC.mapView.view(for: self.mapVC.postAnnotation) {
                annoView.alpha = 1.0
            }
        })

        mapVC.prePanY = UIScreen.main.bounds.height - closedY
        mapVC.toggleMapTouch(enable: false)
        unhideFeedButtons()
    }
    
    func openDrawer(swipe: Bool) {
        
        Mixpanel.mainInstance().track(event: "PostOpenDrawer", properties: ["swipe": swipe])

        guard let post = postsList[safe: selectedPostIndex] else { return }
        let zoomDistance: CLLocationDistance = parentVC == .spot ? 1000 : 100000
        let adjust = 0.00000845 * zoomDistance
        let adjustedCoordinate = CLLocationCoordinate2D(latitude: post.postLat - adjust, longitude: post.postLong)
        mapVC.mapView.animatedZoom(zoomRegion: MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: zoomDistance, longitudinalMeters: zoomDistance), duration: 0.3)

        mapVC.removeBottomBar()
        if parentVC != .feed { mapVC.toggleMapTouch(enable: true) }
        
        let prePanY: CGFloat = 0
        mapVC.prePanY = prePanY
        hideFeedButtons()

        let duration: TimeInterval = swipe ? 0.15 : 0.30
        guard let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell else { return }
       
        UIView.animate(withDuration: duration) { [weak self] in
            
            guard let self = self else { return }

            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: prePanY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - prePanY)
         ///   cell.postImage.frame = CGRect(x: cell.postImage.frame.minX, y: cell.postImage.frame.minY, width: cell.postImage.frame.width, height: cell.postImage.frame.height)
            if cell.topView != nil { cell.bringSubviewToFront(cell.topView) }
            if cell.tapButton != nil { cell.bringSubviewToFront(cell.tapButton) }
        }
        
        /// animate post view at same duration as animated zoom
        UIView.animate(withDuration: 0.4, animations: { [weak self] in
            guard let self = self else { return }
            
            if let annoView = self.mapVC.mapView.view(for: self.mapVC.postAnnotation) {
                annoView.alpha = 0.0
            }
            
            /// hide feed seg on animation
        })
    }

    @objc func topViewTableSwipe(_ gesture: UIPanGestureRecognizer) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell else { return }
        cell.topViewSwipe(gesture) /// pass through to cell method
    }
    
    @objc func exitPosts(_ sender: UIBarButtonItem) {
        exitPosts()
    }
    
    func presentFriendsList() {
        
        openFriendsList = false
        guard let post = postsList[safe: selectedPostIndex] else { return }
        
        if let friendsListVC = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "FriendsList") as? FriendsListController {
            
            friendsListVC.postVC = self
            friendsListVC.friendIDs = post.addedUsers ?? []
            friendsListVC.friendsList = post.addedUserProfiles
            
            DispatchQueue.main.async { self.present(friendsListVC, animated: true, completion: nil) }
        }
    }
}

extension PostViewController: UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var postCount = postsList.count

        /// increment postCount if added loading cell at the end. 6 is earliest that cell refresh can happen
        if let postParent = parent as? FeedViewController {
            if postParent.selectedSegmentIndex == 0 && postsEmpty { return 1 } /// only show the postsempty cell if 0 posts available on the friends feed
            if postParent.refresh != .noRefresh && postCount > 0 { postCount += 1 }
        }

        return postCount
    }
    
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let updateCellImage: ([UIImage]?) -> () = { [weak self] (images) in
            
            guard let self = self else { return }
            guard let post = self.postsList[safe: indexPath.row] else { return }
            guard let cell = cell as? PostCell else { return } /// declare cell within closure in case cancelled
            if post.imageURLs.count != images?.count { return } /// patch fix for wrong images getting called with a post -> crashing on image out of bounds on get frame indexes 

            if let index = self.postsList.lastIndex(where: {$0.id == post.id}) { if indexPath.row != index { return }  }
        
            if indexPath.row == self.selectedPostIndex { self.currentImageSet = (id: post.id ?? "", images: images ?? []) }
            
            /// on big jumps in scrolling cancellation doesnt seem to always work
            if !(tableView.indexPathsForVisibleRows?.contains(indexPath) ?? true) {
                self.loadingOperations.removeValue(forKey: post.id ?? "")
                return
            }
            
            cell.finishImageSetUp(images: images ?? [])
            
            if self.editView && indexPath.row == self.selectedPostIndex && post.posterID == self.uid { cell.addEditOverview() }
            if self.notFriendsView && indexPath.row == self.selectedPostIndex { cell.addNotFriends() }
            
            let edit = self.editedPost == nil ? post : self.editedPost
            if self.editPostView && indexPath.row == self.selectedPostIndex && post.posterID == self.uid { cell.addEditPostView(editedPost: edit!) }

     //       self.loadingOperations.removeValue(forKey: post.id ?? "")
        }
        
        guard let post = postsList[safe: indexPath.row] else { return }
        
        /// Try to find an existing data loader
        if let dataLoader = loadingOperations[post.id ?? ""] {
            
            /// Has the data already been loaded?
            if dataLoader.images.count == post.imageURLs.count {
                
                guard let cell = cell as? PostCell else { return }
                cell.finishImageSetUp(images: dataLoader.images)
              //  loadingOperations.removeValue(forKey: post.id ?? "")
            } else {
                /// No data loaded yet, so add the completion closure to update the cell once the data arrives
                dataLoader.loadingCompleteHandler = updateCellImage
            }
        } else {
            
            /// Need to create a data loader for this index path
            if indexPath.row == self.selectedPostIndex && self.currentImageSet.id == post.id ?? "" {
                updateCellImage(currentImageSet.images)
                return
            }
                
            let dataLoader = PostImageLoader(post)
                /// Provide the completion closure, and kick off the loading operation
            dataLoader.loadingCompleteHandler = updateCellImage
            loadingQueue.addOperation(dataLoader)
            loadingOperations[post.id ?? ""] = dataLoader
        }
    }
    
    ///https://medium.com/monstar-lab-bangladesh-engineering/tableview-prefetching-datasource-3de593530c4a
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var selectedSegmentIndex = 0 /// selectedSegmentIndex will not be 0 for nearby feed
        if let feedVC = parent as? FeedViewController { selectedSegmentIndex = feedVC.selectedSegmentIndex }

        if indexPath.row < self.postsList.count {

            guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell") as? PostCell else { return UITableViewCell() }
            
            let post = postsList[indexPath.row]
            var postsCount = self.postsList.count
            
            /// increment postCount if added loading cell at the end

            if let postParent = parent as? FeedViewController {
                if postParent.refresh != .noRefresh && postsList.count > 6 { postsCount += 1 }
            }
            
            let cellHeight = post.cellHeight

            cell.setUp(post: post, selectedPostIndex: selectedPostIndex, postsCount: postsCount, parentVC: parentVC, selectedSegmentIndex: selectedSegmentIndex, currentLocation: UserDataModel.shared.currentLocation, vcid: vcid, row: indexPath.row, cellHeight: cellHeight, tabBarHeight: tabBarHeight, navBarHeight: navBarHeight, closedY: closedY)
            
            ///edit view was getting added on random cells after returning from other screens so this is really a patch fix
            
            return cell
            
        } else {
            
            if postsEmpty && indexPath.row == 0 && selectedSegmentIndex == 0 {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostFriendsCell") as? PostFriendsCell else { return UITableViewCell() }
                cell.setUp(cellHeight: cellHeight, tabBarHeight: tabBarHeight)
                return cell
            }
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell") as? LoadingCell else { return UITableViewCell() }
            cell.setUp(selectedPostIndex: indexPath.row, parentVC: parentVC, vcid: vcid)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        guard let post = postsList[safe: indexPath.row] else { return cellHeight }
        return post.cellHeight
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let post = postsList[safe: indexPath.row] else { return cellHeight }
        return post.cellHeight
    }
        
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
        for indexPath in indexPaths {
            
            if abs(indexPath.row - selectedPostIndex) > 3 { return }
            
            guard let post = postsList[safe: indexPath.row] else { return }
            if let _ = loadingOperations[post.id ?? ""] { return }

            let dataLoader = PostImageLoader(post)
            dataLoader.queuePriority = .high
            loadingQueue.addOperation(dataLoader)
            loadingOperations[post.id ?? ""] = dataLoader
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        
        for indexPath in indexPaths {
            /// I think due to the size of the table, prefetching was being cancelled for way too many rows, some like 1 or 2 rows away from the selected post index. This is kind of a hacky fix to ensure that fetching isn't cancelled when we'll need the image soon
            if abs(indexPath.row - selectedPostIndex) < 4 { return }

            guard let post = postsList[safe: indexPath.row] else { return }

            if let imageLoader = loadingOperations[post.id ?? ""] {
                imageLoader.cancel()
                loadingOperations.removeValue(forKey: post.id ?? "")
            }
        }
    }
    
    func openSpotPage(edit: Bool, post: MapPost) {
        
        guard let spotVC = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "SpotPage") as? SpotViewController else { return }
        
        spotVC.spotID = post.spotID
        spotVC.spotName = post.spotName
        spotVC.mapVC = self.mapVC
        
        if edit { spotVC.editSpotMode = true }

        self.mapVC.postsList.removeAll()
        self.cancelDownloads()
        if let feedVC = parent as? FeedViewController { feedVC.hideFeedSeg() }
        
        spotVC.view.frame = self.view.frame
        self.addChild(spotVC)
        self.view.addSubview(spotVC.view)
        spotVC.didMove(toParent: self)
        
        //re-enable spot button
        if let cell = self.tableView.cellForRow(at: IndexPath(row: self.selectedPostIndex, section: 0)) as? PostCell {
            if cell.tapButton != nil { cell.tapButton.isEnabled = true }
        }
        
        self.mapVC.prePanY = self.mapVC.halfScreenY
        DispatchQueue.main.async { self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: self.mapVC.halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - self.mapVC.halfScreenY) }
    }
    
    func exitPosts() {
        
        /// posts will always be a child of feed vc
        if parentVC == .feed { return }
        
        self.willMove(toParent: nil)
        view.removeFromSuperview()
        
        mapVC.toggleMapTouch(enable: false)
        
        if let spotVC = parent as? SpotViewController {
            spotVC.resetView()
        } else if let profileVC = parent as? ProfileViewController {
            profileVC.resetProfile()
        } else if let notificationsVC = parent as? NotificationsViewController {
            notificationsVC.resetView()
        }
        
        removeFromParent()
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.removeObserver(self,  name: NSNotification.Name("PostAddressChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostLike"), object: nil)
        NotificationCenter.default.removeObserver(self,  name: NSNotification.Name("TagSelect"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FeedPostTap"), object: nil)
    }
    
    func unhideFeedButtons() {
        mapVC.toggleMapButton.isHidden = false
        mapVC.directionsButton.isHidden = false
        mapVC.directionsButton.addTarget(self, action: #selector(directionsTap(_:)), for: .touchUpInside)
    }
    
    func hideFeedButtons() {
        mapVC.toggleMapButton.isHidden = true
        mapVC.directionsButton.isHidden = true
        mapVC.directionsButton.removeTarget(self, action: #selector(directionsTap(_:)), for: .touchUpInside)
    }
    
    @objc func directionsTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "PostGetDirections")
        
        guard let post = postsList[safe: selectedPostIndex] else { return }
        UIApplication.shared.open(URL(string: "http://maps.apple.com/?daddr=\(post.postLat),\(post.postLong)")!)
    }
    
    func addBottomMask() {
        
        let tabBarHidden = mapVC.customTabBar.tabBar.isHidden
        var maskHeight = UIScreen.main.bounds.width * 0.245
        let minY = UIScreen.main.bounds.height - maskHeight - tabBarHeight
        if tabBarHidden { maskHeight += tabBarHeight }
        
        let bottomMask = UIView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: maskHeight))
        bottomMask.backgroundColor = nil
        bottomMask.isUserInteractionEnabled = false
        let layer0 = CAGradientLayer()
        layer0.frame = bottomMask.bounds
        layer0.colors = [
            UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0).cgColor,
            UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0.33).cgColor
        ]
        layer0.locations = [0, 1]
        layer0.startPoint = CGPoint(x: 0.5, y: 0)
        layer0.endPoint = CGPoint(x: 0.5, y: 1)
        bottomMask.layer.addSublayer(layer0)
        view.addSubview(bottomMask)
    }
}

class PostCell: UITableViewCell {
    
    var post: MapPost!
    var selectedSpotID: String!
    
    var topView: UIView!
    var imageScroll: UIScrollView!
    var imageScrollOverlay: UIView!
        
    var userView: UIView!
    var profilePic: UIImageView!
    var username: UILabel!
    var usernameDetail: UIView!
    var tagImage: UIImageView!
    var addedUsersView: AddedUsersView!
    
    var spotScrollOverlay: UIView!
    var spotScroll: UIScrollView!
    var spotNameBanner: UIView!
    var tapButton: UIButton!
    var targetIcon: UIImageView!
    var spotNameLabel: UILabel!
    var spotSeparator: UIImageView!
    var detailLabel: UILabel!

    var timestamp: UILabel!
    var postOptions: UIButton!
    
    var postCaption: UILabel!
    
    var likeButton, commentButton: UIButton!
    var numLikes, numComments: UILabel!
    var bottomDivider: UIView!
    
    var vcid: String!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    
    var selectedPostIndex, postsCount: Int!
    var originalOffset: CGFloat!
    
    var cellHeight: CGFloat = 0
    var parentVC: PostViewController.parentViewController!
    lazy var tagRect: [(rect: CGRect, username: String)] = []

    var nextPan, swipe: UIPanGestureRecognizer!
    
    /// for if user isn't friend with spot founder
    var noAccessFriend: UserProfile!
    var notFriendsView: UIView!
    var postMask: UIView!
    var addFriendButton: UIButton!
    
    var deleteIndicator: CustomActivityIndicator!
    var editView: UIView!
    var editPostView: EditPostView!
    
    var imageWidth: CGFloat = 0
    
    var offScreen = false /// off screen to avoid double interactions with first cell being pulled down
    var imageManager: SDWebImageManager!
    var globalRow = 0 /// row in table
    var closedY: CGFloat = 0
    var tabBarHeight: CGFloat = 0
    var navBarHeight: CGFloat = 0
    var beginningSwipe: CGFloat = 0
    var imageOffset0: CGFloat = 0

    var imageMask: MaskImageView!

    func setUp(post: MapPost, selectedPostIndex: Int, postsCount: Int, parentVC: PostViewController.parentViewController, selectedSegmentIndex: Int, currentLocation: CLLocation, vcid: String, row: Int, cellHeight: CGFloat, tabBarHeight: CGFloat, navBarHeight: CGFloat, closedY: CGFloat) {
        
        resetTextInfo()
        self.backgroundColor = UIColor(named: "FeedBlack")

        imageManager = SDWebImageManager()
        
        self.post = post
        self.selectedSpotID = post.spotID
        self.selectedPostIndex = selectedPostIndex
        self.postsCount = postsCount
        self.parentVC = parentVC
        self.tag = 16
        self.vcid = vcid
        self.closedY = closedY
        self.tabBarHeight = tabBarHeight
        self.navBarHeight = navBarHeight
        self.cellHeight = cellHeight
        globalRow = row

        originalOffset = CGFloat(selectedPostIndex) * cellHeight
                        
        nextPan = UIPanGestureRecognizer(target: self, action: #selector(verticalSwipe(_:)))
        self.addGestureRecognizer(nextPan)
                       
        imageWidth = UserDataModel.shared.screenSize > 0 ? UIScreen.main.bounds.width - 82 : 288

        let maxHeight = post.imageHeight
        
        let currentAspect = min((post.aspectRatios?[safe: post.selectedImageIndex] ?? 1.333) - 0.033, 1.5)
        let currentHeight = currentAspect * imageWidth
        var imageY = 102 + post.captionHeight
        if maxHeight - currentHeight > 5 { imageY += (maxHeight - currentHeight)/2 }
                                        
        userView = UIView(frame: CGRect(x: 0, y: 17, width: UIScreen.main.bounds.width, height: 51))
        addSubview(userView)
        
        profilePic = UIImageView(frame: CGRect(x: 14, y: 1, width: 49, height: 49))
        profilePic.layer.cornerRadius = profilePic.frame.width/2
        profilePic.clipsToBounds = true
        userView.addSubview(profilePic)

        let profileButton = UIButton(frame: CGRect(x: profilePic.frame.minX - 2.5, y: profilePic.frame.minY - 2.5, width: profilePic.frame.width + 4, height: profilePic.frame.width + 4))
        profileButton.addTarget(self, action: #selector(usernameTap(_:)), for: .touchUpInside)
        userView.addSubview(profileButton)

        if post.userInfo != nil {
            let url = post.userInfo.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
                profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
        }
        
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: 6, width: 200, height: 16))
        username.text = post.userInfo == nil ? "" : post.userInfo!.username
        username.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        username.font = UIFont(name: "SFCamera-Semibold", size: 14)
        username.sizeToFit()
        userView.addSubview(username)
        
        let usernameButton = UIButton(frame: CGRect(x: username.frame.minX - 3, y: username.frame.minY - 3, width: username.frame.width + 6, height: username.frame.height + 6))
        usernameButton.backgroundColor = nil
        usernameButton.addTarget(self, action: #selector(usernameTap(_:)), for: .touchUpInside)
        userView.addSubview(usernameButton)
        
        usernameDetail = UIView(frame: CGRect(x: username.frame.maxX, y: 0, width: UIScreen.main.bounds.width - username.frame.minX - 50, height: 25))
        userView.addSubview(usernameDetail)
        
        var minX: CGFloat = 5
        if post.tag ?? "" != "" {
            
            let detail1 = UILabel(frame: CGRect(x: minX, y: 8, width: 11, height: 13))
            detail1.text = "is"
            detail1.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            detail1.font = UIFont(name: "SFCamera-Regular", size: 13.5)
            usernameDetail.addSubview(detail1)
            
            minX += 15
            
            let tag = Tag(name: post.tag!)
            tagImage = UIImageView(frame: CGRect(x: minX, y: 1, width: 23, height: 23))
            tagImage.contentMode = .scaleAspectFit
            tagImage.image = tag.image
            usernameDetail.addSubview(tagImage)
            if tagImage.image == UIImage() { getTagImage(tag: tag) }
            minX += 27
        }
        
        if !(post.addedUsers?.isEmpty ?? true) {
            
            let detail2 = UILabel(frame: CGRect(x: minX, y: 8, width: 28, height: 13))
            detail2.text = "with"
            detail2.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            detail2.font = UIFont(name: "SFCamera-Regular", size: 13.5)
            usernameDetail.addSubview(detail2)
            
            minX += 36
            
            let usersWidth: CGFloat = post.addedUsers!.count > 3 ? 77 : CGFloat(post.addedUsers!.count) * 17
                
            addedUsersView = AddedUsersView(frame: CGRect(x: minX, y: 1, width: usersWidth, height: 25))
            addedUsersView.setUp(users: post.addedUserProfiles)
            usernameDetail.addSubview(addedUsersView)
            
            let userButton = UIButton(frame: CGRect(x: minX - 5, y: -5, width: usersWidth + 10, height: 35))
            userButton.addTarget(self, action: #selector(addedUsersTap(_:)), for: .touchUpInside)
            usernameDetail.addSubview(userButton)
        }
        
        /// add activity label
        spotScroll = UIScrollView(frame: CGRect(x: profilePic.frame.maxX + 7, y: username.frame.maxY + 5, width: UIScreen.main.bounds.width - (profilePic.frame.maxX + 9), height: 24))
        spotScroll.showsHorizontalScrollIndicator = false
        spotScroll.isScrollEnabled = false
        userView.addSubview(spotScroll)
        
        targetIcon = UIImageView(frame: CGRect(x: 2, y: 2, width: 16.5, height: 16.5))
        targetIcon.image = UIImage(named: "FeedSpotIcon")
        targetIcon.isUserInteractionEnabled = false
        spotScroll.addSubview(targetIcon)

        spotNameLabel = UILabel(frame: CGRect(x: targetIcon.frame.maxX + 5, y: 2.5, width: UIScreen.main.bounds.width, height: 15))
        spotNameLabel.text = post.spotName ?? ""
        spotNameLabel.textColor = UIColor(red: 0.525, green: 0.525, blue: 0.525, alpha: 1)
        spotNameLabel.isUserInteractionEnabled = false
        spotNameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13.75)
        spotNameLabel.sizeToFit()
        spotScroll.addSubview(spotNameLabel)
        
        let spotNameButton = UIButton(frame: CGRect(x: 0, y: 0, width: spotNameLabel.frame.maxX + 5, height: spotNameLabel.frame.height + 5))
        spotNameButton.addTarget(self, action: #selector(spotNameTap(_:)), for: .touchUpInside)
        spotScroll.addSubview(spotNameButton)

        spotSeparator = UIImageView(frame: CGRect(x: spotNameLabel.frame.maxX + 4, y: spotNameLabel.frame.midY - 0.5, width: 2.5, height: 2.5))
        spotSeparator.image = UIImage(named: "FeedSpotSeparator")
        spotSeparator.contentMode = .scaleAspectFill
        spotScroll.addSubview(spotSeparator)
        
        let detailText = (parentVC == .feed && selectedSegmentIndex == 0) || parentVC == .profile || parentVC == .notifications ? post.city ?? "" : CLLocation(latitude: post.postLat, longitude: post.postLong).distance(from: currentLocation).getLocationString()
        detailLabel = UILabel(frame: CGRect(x: spotSeparator.frame.maxX + 4, y: 2.5, width: 300, height: 14))
        detailLabel.isUserInteractionEnabled = false
        detailLabel.text = detailText
        detailLabel.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
        detailLabel.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        detailLabel.sizeToFit()
        spotScroll.addSubview(detailLabel)
        
        spotScroll.contentSize = CGSize(width: detailLabel.frame.maxX + 20, height: spotScroll.contentSize.height)
        
        spotScrollOverlay = UIView(frame: spotScroll.frame)
        spotScrollOverlay.backgroundColor = nil
        spotScrollOverlay.isUserInteractionEnabled = false
        userView.addSubview(spotScrollOverlay)
        
        if spotScroll.frame.minX + spotScroll.contentSize.width > UIScreen.main.bounds.width { addSpotScrollMask(); animateSpotScroll() }
        
        postOptions = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 43.45, y: 10.45, width: 24.45, height: 13.75))
        postOptions.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        postOptions.setImage(UIImage(named: "PostOptions"), for: .normal)
        postOptions.addTarget(self, action: #selector(optionsTapped(_:)), for: .touchUpInside)
        userView.addSubview(postOptions)
        
        let noImage = post.imageURLs.isEmpty
        let fontSize: CGFloat = noImage ? 24 : 14.5
        var captionHeight = getCaptionHeight(caption: post.caption, fontSize: fontSize)
        let maxCaption: CGFloat = 200
        let overflow = captionHeight > maxCaption
        captionHeight = min(captionHeight, maxCaption)

        let minY = noImage ? userView.frame.maxY + 22 : userView.frame.maxY + 10
        postCaption = UILabel(frame: CGRect(x: 22, y: minY, width: UIScreen.main.bounds.width - 44, height: post.captionHeight + 0.5))
        postCaption.text = post.caption
        postCaption.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        postCaption.font = UIFont(name: "SFCamera-Regular", size: fontSize)
        
        let numberOfLines = overflow ? 3 : 0
        postCaption.numberOfLines = numberOfLines
        postCaption.lineBreakMode = overflow ? .byClipping : .byWordWrapping
        postCaption.isUserInteractionEnabled = true
        
        postCaption.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap(_:))))
        
        /// adding links for tagged users
        if !(post.taggedUsers?.isEmpty ?? true) {
            
            let attString = self.getAttString(caption: post.caption, taggedFriends: post.taggedUsers!, fontSize: 14.5)
            postCaption.attributedText = attString.0
            tagRect = attString.1
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.tappedLabel(_:)))
            postCaption.isUserInteractionEnabled = true
            postCaption.addGestureRecognizer(tap)
        }
        
        if overflow {
            postCaption.addTrailing(with: "... ", moreText: "more", moreTextFont: UIFont(name: "SFCamera-Semibold", size: 13)!, moreTextColor: .white)
            addSubview(self.postCaption)
        } else { addSubview(postCaption) }
        
        let liked = post.likers.contains(uid)
        let likeImage = liked ? UIImage(named: "UpArrowFilled") : UIImage(named: "UpArrow")
        
        likeButton = UIButton(frame: CGRect(x: 22, y: cellHeight - 45, width: 28.7, height: 28.7))
        liked ? likeButton.addTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside) : likeButton.addTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        likeButton.setImage(likeImage, for: .normal)
        likeButton.contentMode = .scaleAspectFill
        likeButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        addSubview(likeButton)
        
        numLikes = UILabel(frame: CGRect(x: likeButton.frame.maxX + 3, y: likeButton.frame.minY + 10.5, width: 30, height: 15))
        numLikes.text = String(post.likers.count)
        numLikes.font = UIFont(name: "SFCamera-Semibold", size: 12)
        numLikes.textColor = liked ? UIColor(red: 0.18, green: 0.817, blue: 0.817, alpha: 1) : UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        numLikes.textAlignment = .center
        numLikes.sizeToFit()
        addSubview(numLikes)

        commentButton = UIButton(frame: CGRect(x: 79, y: cellHeight - 44, width: 29.15, height: 27.4))
        commentButton.setImage(UIImage(named: "CommentIcon"), for: .normal)
        commentButton.contentMode = .scaleAspectFill
        commentButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        commentButton.addTarget(self, action: #selector(commentsTap(_:)), for: .touchUpInside)
        addSubview(commentButton)
        
        numComments = UILabel(frame: CGRect(x: commentButton.frame.maxX + 3, y: commentButton.frame.minY + 9.5, width: 30, height: 15))
        let commentCount = max(post.commentList.count - 1, 0)
        numComments.text = String(commentCount)
        numComments.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        numComments.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        numComments.textAlignment = .center
        numComments.sizeToFit()
        addSubview(numComments)

        bottomDivider = UIView(frame: CGRect(x: 0, y: cellHeight - 11, width: UIScreen.main.bounds.width, height: 11))
        bottomDivider.backgroundColor = .black
        addSubview(bottomDivider)
        
        let line1 = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        line1.backgroundColor = UIColor(red: 0.094, green: 0.094, blue: 0.094, alpha: 1)
        bottomDivider.addSubview(line1)
        
        let line2 = UIView(frame: CGRect(x: 0, y: 10, width: UIScreen.main.bounds.width, height: 1))
        line2.backgroundColor = UIColor(red: 0.094, green: 0.094, blue: 0.094, alpha: 1)
        bottomDivider.addSubview(line2)
        
        imageMask = MaskImageView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        imageMask.isHidden = true

        DispatchQueue.main.async {
            let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
            keyWindow?.addSubview(self.imageMask)
        }
    }
    
    func finishImageSetUp(images: [UIImage]) {
                
        resetImageInfo()
        
        let adjustedCaption = post.captionHeight == 0 ? -10 : post.captionHeight /// adjust to bring image closer to userView for no caption
        let imageY = 91 + adjustedCaption

        imageScroll = UIScrollView(frame: CGRect(x: 0, y: imageY, width: UIScreen.main.bounds.width, height: post.imageHeight))
        imageScroll.backgroundColor = nil
        imageScroll.tag = 16
        imageScroll.isUserInteractionEnabled = true
        imageScroll.isScrollEnabled = false
        
        swipe = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        imageScroll.addGestureRecognizer(swipe)
        
        addSubview(imageScroll)
        
        imageScrollOverlay = UIView(frame: imageScroll.frame)
        imageScrollOverlay.backgroundColor = nil
        imageScrollOverlay.isUserInteractionEnabled = false
        addSubview(imageScrollOverlay)
        
        addImageScrollMask()

        var frameIndexes = post.frameIndexes ?? []
        if post.imageURLs.count == 0 { return }
        if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }
        post.frameIndexes = frameIndexes

        if images.isEmpty { return }
        post.postImage = images
        
        var minX: CGFloat = 20
        
        for i in 0...frameIndexes.count - 1 {
            
            guard let currentImage = images[safe: frameIndexes[i]] else { return }
            
            let superMax: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.3 : 1.5
            let aspect = currentImage.size.height > 0 ? min((currentImage.size.height / currentImage.size.width) - 0.033, superMax) : 1.3
            let height = aspect * imageWidth
            var minY: CGFloat = 0 /// 0 within the imageScroll frame
            if post.imageHeight - height > 5 { minY += (post.imageHeight - height)/2 }
            
            let imageView = PostImageView(frame: CGRect(x: minX, y: minY, width: imageWidth, height: height))
            imageView.tag = i
            imageView.navBarHeight = navBarHeight
            
            imageView.image = currentImage
            imageView.stillImage = currentImage
            
            imageScroll.addSubview(imageView)
            
                ///there may be a rare case where there is a single post of a 5 frame alive. but i wasnt sure which posts
            
            let animationImages = getGifImages(selectedImages: images, frameIndexes: frameIndexes, imageIndex: i)
            imageView.animationImages = animationImages
            
            if !animationImages.isEmpty {
                animationImages.count == 5 && frameIndexes.count == 1 ? imageView.animate5FrameAlive(directionUp: true, counter: imageView.animationCounter) : imageView.animateGIF(directionUp: true, counter: imageView.animationCounter, frames: animationImages.count, alive: post.gif ?? false)  /// use old animation for 5 frame alives
            }
            
            minX += imageWidth + 9
        }
        
        scrollToImageAt(position: post.selectedImageIndex, animated: false)
        

        /// bring subviews and tap areas above masks
        if topView != nil { bringSubviewToFront(topView) }
        if tapButton != nil { bringSubviewToFront(tapButton) }
        if userView != nil { bringSubviewToFront(userView) }
        if postCaption != nil { bringSubviewToFront(postCaption) }
    }
    
    func resetTextInfo() {
        /// reset for fields that are set before image fetch
        if targetIcon != nil { targetIcon.image = UIImage() }
        if spotScrollOverlay != nil { for sub in spotScrollOverlay.subviews { sub.removeFromSuperview() }}
        if spotScroll != nil { spotScroll.removeFromSuperview() }
        if spotNameLabel != nil { spotNameLabel.text = "" }
        if detailLabel != nil { detailLabel.text = "" }
        if spotSeparator != nil { spotSeparator.image = UIImage() }
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
        if usernameDetail != nil { for sub in usernameDetail.subviews { sub.removeFromSuperview() }}
        if tagImage != nil { tagImage.image = UIImage(); tagImage.sd_cancelCurrentImageLoad() }
        if addedUsersView != nil { for sub in addedUsersView.subviews { sub.removeFromSuperview(); if let image = sub as? UIImageView { image.sd_cancelCurrentImageLoad()}}}
        if timestamp != nil { timestamp.text = "" }
        if postOptions != nil { postOptions.setImage(UIImage(), for: .normal) }
        if postCaption != nil { postCaption.text = "" }
        if commentButton != nil { commentButton.setImage(UIImage(), for: .normal) }
        if numComments != nil { numComments.text = "" }
        if likeButton != nil { likeButton.setImage(UIImage(), for: .normal) }
        if numLikes != nil { numLikes.text = "" }
        if bottomDivider != nil { bottomDivider.backgroundColor = nil; for sub in bottomDivider.subviews { sub.removeFromSuperview() }}
        
        if imageScroll != nil { for sub in imageScroll.subviews { sub.removeFromSuperview() }; imageScroll.removeFromSuperview() }
    }
    
    func resetImageInfo() {
        /// reset for fields that are set after image fetch (right now just called on cell init)

        if imageScroll != nil { for sub in imageScroll.subviews { sub.removeFromSuperview() }; imageScroll.removeFromSuperview() }
        if imageScrollOverlay != nil { for sub in imageScrollOverlay.subviews { sub.removeFromSuperview() }}
        if notFriendsView != nil { notFriendsView.removeFromSuperview() }
        if addFriendButton != nil { addFriendButton.removeFromSuperview() }
        if editView != nil { editView.removeFromSuperview(); editView = nil }
        if editPostView != nil { editPostView.removeFromSuperview(); editPostView = nil }
       
        /// remove top mask
        if postMask != nil {
            for sub in postMask.subviews { sub.removeFromSuperview() }
            postMask.removeFromSuperview()
        }
    }
    
    override func prepareForReuse() {
        
        super.prepareForReuse()

        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
        if profilePic != nil { profilePic.removeFromSuperview(); profilePic.sd_cancelCurrentImageLoad() }
    }
    
    func animateSpotScroll() {
        
        guard let postVC = viewContainingController() as? PostViewController else { return }
        if globalRow != postVC.selectedPostIndex { spotScroll.contentOffset = .zero; return }
        let maxOffset = spotScroll.contentSize.width - spotScroll.bounds.width
        let animationDuration = TimeInterval(maxOffset/30 + 1)
        
        /// animate to end of side scroll
        UIView.animate(withDuration: animationDuration, delay: 0.5, options: .allowUserInteraction, animations: {
            let maxOffset = self.spotScroll.contentSize.width - self.spotScroll.bounds.width
            self.spotScroll.contentOffset = CGPoint(x: maxOffset, y: self.spotScroll.contentOffset.y)
            
        }) { [weak self] complete in
            
            if !complete { return }
            guard let self = self else { return }
            ///animate to beginning of side scroll after slight delay
            if self.spotScroll == nil || self.spotScroll.superview == nil { return }
            
            UIView.animate(withDuration: animationDuration, delay: 0.5, options: .allowUserInteraction, animations: {
                self.spotScroll.contentOffset = CGPoint(x: 0, y: self.spotScroll.contentOffset.y)
                
            }) { complete in
                /// continue animation after delay
                if !complete { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if self.spotScroll == nil || self.spotScroll.superview == nil { return }
                    self.animateSpotScroll()
                }
            }
        }
    }
    
    func addSpotScrollMask() {

        let leftMask = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: spotScroll.frame.height))
        leftMask.backgroundColor = nil
        let layer0 = CAGradientLayer()
        layer0.frame = leftMask.bounds
        layer0.colors = [
          UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0).cgColor,
          UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0.85).cgColor
        ]
        layer0.locations = [0, 1]
        layer0.startPoint = CGPoint(x: 1, y: 0.5)
        layer0.endPoint = CGPoint(x: 0, y: 0.5)
        leftMask.layer.addSublayer(layer0)
        spotScrollOverlay.addSubview(leftMask)
        
        let rightMask = UIView(frame: CGRect(x: spotScroll.bounds.width - 24, y: 0, width: 24, height: spotScroll.frame.height))
        rightMask.backgroundColor = nil
        let layer1 = CAGradientLayer()
        layer1.frame = rightMask.bounds
        layer1.colors = [
          UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0).cgColor,
          UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 1).cgColor
        ]
        layer1.locations = [0, 1]
        layer1.startPoint = CGPoint(x: 0, y: 0.5)
        layer1.endPoint = CGPoint(x: 1, y: 0.5)
        rightMask.layer.addSublayer(layer1)
        spotScrollOverlay.addSubview(rightMask)
    }
    
    func addImageScrollMask() {
        
        let leftWidth: CGFloat = UserDataModel.shared.screenSize == 2 ? 20 : 18
        let leftMask = UIView(frame: CGRect(x: 0, y: 0, width: leftWidth, height: imageScroll.frame.height))
        leftMask.backgroundColor = nil
        let layer0 = CAGradientLayer()
        layer0.frame = leftMask.bounds
        layer0.colors = [
          UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0).cgColor,
          UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0.44).cgColor
        ]
        layer0.locations = [0, 1]
        layer0.startPoint = CGPoint(x: 1, y: 0.5)
        layer0.endPoint = CGPoint(x: 0, y: 0.5)
        leftMask.layer.addSublayer(layer0)
        imageScrollOverlay.addSubview(leftMask)
        
        let rightWidth: CGFloat = UserDataModel.shared.screenSize == 2 ? 48 : 53
        let rightMask = UIView(frame: CGRect(x: imageScrollOverlay.bounds.width - rightWidth, y: 0, width: rightWidth, height: imageScroll.frame.height))
        rightMask.backgroundColor = nil
        let layer1 = CAGradientLayer()
        layer1.frame = rightMask.bounds
        layer1.colors = [
            UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0).cgColor,
            UIColor(red: 0.063, green: 0.063, blue: 0.063, alpha: 0.33).cgColor
        ]
        layer1.locations = [0, 1]
        layer1.startPoint = CGPoint(x: 0, y: 0.5)
        layer1.endPoint = CGPoint(x: 1, y: 0.5)
        rightMask.layer.addSublayer(layer1)
        imageScrollOverlay.addSubview(rightMask)
    }
        
    @objc func spotNameTap(_ sender: UIButton) {
        /// get spot level info then open spot page
        
        Mixpanel.mainInstance().track(event: "PostSpotNameTap")
        
        if parentVC == .spot { exitPosts(); return }
        
        sender.isEnabled = false
        if let postVC = self.viewContainingController() as? PostViewController {
                        
            if post.createdBy != self.uid && post.spotPrivacy == "friends" &&  !UserDataModel.shared.friendIDs.contains(post.createdBy ?? "") {
                self.addNotFriends()
                sender.isEnabled = true
                return
            }
            postVC.openSpotPage(edit: false, post: post)
        }
    }
    
    @objc func addedUsersTap(_ sender: UIButton)  {
        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.presentFriendsList()
        }
    }
    
    @objc func optionsTapped(_ sender: UIButton) {
        addEditOverview()
    }
    
    
    @objc func usernameTap(_ sender: UIButton) {
        if post.userInfo == nil { return }
        openProfile(user: post.userInfo)
    }
    
    @objc func reportPostTap(_ sender: UIButton) {
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
                                            let postID = self.post.id ?? ""
                                            self.reportPost(postID: postID, description: textField.text ?? "")

                                        @unknown default:
                                            fatalError()
                                        }}))
        
        guard let postVC = viewContainingController() as? PostViewController else { return }
        postVC.present(alert, animated: true, completion: nil)
    }
    
    func reportPost(postID: String, description: String) {
        
        let db = Firestore.firestore()
        let uuid = UUID().uuidString
        
        db.collection("contact").document(uuid).setData(["type": "report post", "reporterID" : uid, "reportedSpot": postID, "description": description])
        
        exitEditOverview()
    }
    
    func openProfile(user: UserProfile) {
                
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
            
            Mixpanel.mainInstance().track(event: "PostOpenProfile")

            if user.id != "" {
                vc.userInfo = user /// already have user info 
            } else {
                vc.passedUsername = user.username /// run username query from tapped tag on profile open
            }
            
            if let postVC = self.viewContainingController() as? PostViewController {
                
                vc.mapVC = postVC.mapVC
                vc.id = user.id ?? ""
                
                postVC.mapVC.customTabBar.tabBar.isHidden = true
                postVC.cancelDownloads()
                if let feedVC = postVC.parent as? FeedViewController { feedVC.hideFeedSeg() } /// hide feed seg on feed
                
                vc.view.frame = postVC.view.frame
                postVC.addChild(vc)
                postVC.view.addSubview(vc.view)
                vc.didMove(toParent: postVC)
            }
        }
    }
    
    @objc func captionTap(_ sender: UITapGestureRecognizer) {
        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.openComments()
        }
    }
    
    @objc func commentsTap(_ sender: UIButton) {
        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.openComments()
        }
    }
    
    func removeGestures() {
        if nextPan != nil { self.removeGestureRecognizer(nextPan) }
        if swipe != nil { self.imageScroll.removeGestureRecognizer(swipe) }
    }
    
    func getCaptionHeight(caption: String, fontSize: CGFloat) -> CGFloat {
                
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 44, height: 20))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCamera-Regular", size: fontSize)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()
        
        return tempLabel.frame.height
    }

    
    func exitPosts() {
        
        Mixpanel.mainInstance().track(event: "PostPageRemove")
        
        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.exitPosts()
        }
    }
    
    
    @objc func tappedLabel(_ sender: UITapGestureRecognizer) {
        
        if let postVC = self.viewContainingController() as? PostViewController {
            for r in tagRect {
                
                if r.rect.contains(sender.location(in: sender.view)) {
                    // open tag from friends list
                    if let friend = UserDataModel.shared.friendsList.first(where: {$0.username == r.username}) {
                        openProfile(user: friend)
                    } else {
                        /// pass blank user object to open func, run get user func on profile load
                        var user = UserProfile(username: r.username, name: "", imageURL: "", currentLocation: "", userBio: "")
                        user.id = ""
                        self.openProfile(user: user)
                    }
                    return
                    
                } else if r.username == tagRect.last?.username {
                    postVC.openComments()
                }
            }
        }
    }
    @objc func likePost(_ sender: UIButton) {
        likePost()
    }
    
    func likePost() {
        
        post.likers.append(self.uid)
        likeButton.removeTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside)
        
        layoutLikesAndComments()
        
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": self.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("NotifyPostLike"), object: nil, userInfo: infoPass)
        DispatchQueue.global().async {
            if self.post.id == "" { return }
            self.db.collection("posts").document(self.post.id!).updateData(["likers" : FieldValue.arrayUnion([self.uid])])
            
            let functions = Functions.functions()
            functions.httpsCallable("likePost").call(["likerID": self.uid, "username": UserDataModel.shared.userInfo.username, "postID": self.post.id!, "imageURL": self.post.imageURLs.first ?? "", "spotID": self.post.spotID ?? "", "addedUsers": self.post.addedUsers ?? [], "posterID": self.post.posterID, "posterUsername": self.post.userInfo.username]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }
    
    @objc func unlikePost(_ sender: UIButton) {
        
        post.likers.removeAll(where: {$0 == self.uid})
        likeButton.removeTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        
        layoutLikesAndComments()
        
        //update main data source -- send notification to map, update comments
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": self.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("NotifyPostLike"), object: nil, userInfo: infoPass)
        
        if post.id == "" { return }
        let updatePost = post! /// local object
        
        DispatchQueue.global().async {
            self.db.collection("posts").document(updatePost.id!).updateData(["likers" : FieldValue.arrayRemove([self.uid])])
            let functions = Functions.functions()
            functions.httpsCallable("unlikePost").call(["postID": updatePost.id!, "posterID": updatePost.posterID, "likerID": self.uid]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }
    
    func layoutLikesAndComments() {
        
        let liked = post.likers.contains(uid)
        let likeImage = liked ? UIImage(named: "UpArrowFilled") : UIImage(named: "UpArrow")

        numLikes.frame = CGRect(x: likeButton.frame.maxX + 3, y: likeButton.frame.minY + 10.5, width: 30, height: 15)
        numLikes.text = String(post.likers.count)
        numLikes.textColor = liked ? UIColor(red: 0.18, green: 0.817, blue: 0.817, alpha: 1) : UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        numLikes.sizeToFit()
        
        likeButton.setImage(likeImage, for: .normal)
        
        numComments.frame = CGRect(x: commentButton.frame.maxX + 3, y: commentButton.frame.minY + 9.5, width: 30, height: 15)
        let commentCount = max(post.commentList.count - 1, 0)
        numComments.text = String(commentCount)
        numComments.sizeToFit()
    }
    
    func getTagImage(tag: Tag) {
        tag.getImageURL { [weak self] url in
            guard let self = self else { return }
            let transformer = SDImageResizingTransformer(size: CGSize(width: 70, height: 70), scaleMode: .aspectFill)
            if self.tagImage != nil { self.tagImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer]) }
        }
    }
        
    @objc func topViewSwipe(_ gesture: UIPanGestureRecognizer) {
        
        guard let postVC = viewContainingController() as? PostViewController else { return }
        let closed = postVC.mapVC.prePanY > 200
        
        let translation = gesture.translation(in: self)
        
        if translation.y < 0 && !closed {
            /// pass through to swipe gesture
            verticalSwipe(gesture)
            
        } else {
            /// open/close drawer
            offsetDrawer(gesture: gesture)
        }
    }
    
    func offsetDrawer(gesture: UIPanGestureRecognizer) {

        guard let postVC = viewContainingController() as? PostViewController else { return }
        let closed = postVC.mapVC.prePanY > 200
        let prePanY = postVC.mapVC.prePanY ?? 0
        let translation = gesture.translation(in: self).y
        let velocity = gesture.velocity(in: self).y

        switch gesture.state {
        
        case .changed:
            ///offset frame
            let newHeight = UIScreen.main.bounds.height - prePanY - translation
            postVC.mapVC.customTabBar.view.frame = CGRect(x: 0, y: prePanY + translation, width: UIScreen.main.bounds.width, height: newHeight)
            
            ///zoom on post
            let closedToStart = prePanY > 200
            let lowestZoom: CGFloat = parentVC == .spot ? 300 : 600
            let highestZoom: CGFloat = parentVC == .spot ? 1000 : 100000
            let initialZoom = closedToStart ? lowestZoom : highestZoom
            let endingZoom = closedToStart ? highestZoom : lowestZoom
            
            /// finalY is either openY or closedY depending on drawer initial state. prePanY already adjusted from map
            let finalY = closedToStart ? 0 : UIScreen.main.bounds.height - closedY
            let currentY = translation + prePanY
            let multiplier = (finalY - currentY) / (finalY - prePanY)
            let zoom: CGFloat = multiplier * (initialZoom - endingZoom) + endingZoom
            let finalZoom: CLLocationDistance = CLLocationDistance(min(highestZoom, max(zoom, lowestZoom)))
            
            let activeMultiplier = closedToStart ? multiplier : 1 - multiplier
            let adjustedOffset = 0.00000845 - activeMultiplier * 0.000005 /// progressively change offset based on zoom distance (.0000345 = half screen post, .00000845 puts post frame at top of screen
            
            let latAdjust = CLLocationDistance(adjustedOffset) * finalZoom
            let adjustedCoordinate = CLLocationCoordinate2D(latitude: post.postLat - latAdjust, longitude: post.postLong)
            
            postVC.mapVC.mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: finalZoom, longitudinalMeters: finalZoom), animated: false)
            
            /// gradually adjust alpha on drawer offset
            if let annoView = postVC.mapVC.mapView.view(for: postVC.mapVC.postAnnotation) {
                annoView.alpha = activeMultiplier
            }
                    
        case .ended, .cancelled:
            
            beginningSwipe = 0
            
            if velocity <= 0 && closed && abs(velocity + translation) > cellHeight * 1/3 {
                postVC.openDrawer(swipe: true)
            } else if velocity >= 0 && !closed && abs(velocity + translation) > cellHeight * 1/3 {
                postVC.closeDrawer(swipe: true)
            } else {
                closed ? postVC.closeDrawer(swipe: true) : postVC.openDrawer(swipe: true)
            }
            
        default:
            return
        }
    }
    
        
    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        
        let translation = gesture.translation(in: self)
        guard let postVC = viewContainingController() as? PostViewController else { return }
        if imageMask.zooming { return }
        
        let offsetY = 0
        if Int(postVC.mapVC.customTabBar.view.frame.minY) != offsetY {
            /// offset drawer if its already been offset some
            offsetDrawer(gesture: gesture)
            
        } else if abs(translation.y) > abs(translation.x) {
            if imageScroll.contentOffset.x == 0 || imageScroll.contentOffset.x.truncatingRemainder(dividingBy: imageWidth + 9) == 0 {
                verticalSwipe(gesture: gesture)

            } else {
                ///stay with image swipe if image swipe already began
                imageSwipe(gesture: gesture)
            }
            
        } else {
            
            if let tableView = self.superview as? UITableView {
                if tableView.contentOffset.y - originalOffset != 0 {
                    ///stay with vertical swipe if vertical swipe already began
                    verticalSwipe(gesture)
                } else {
                    imageSwipe(gesture: gesture)
                }
            }
        }
    }
    
    func imageSwipe(gesture: UIPanGestureRecognizer) {
        
        /// cancel gesture if zooming
        guard let postVC = self.viewContainingController() as? PostViewController else { return }

        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
                        
        if (post.selectedImageIndex == 0 && direction.x > 0) || postVC.view.frame.minX > 0 {
            if parentVC != .feed && imageScroll.contentOffset.x == 0 { swipeToExit(gesture: gesture); return }
        }
        
        if offScreen { resetPostFrame(); return }

        switch gesture.state {
                    
        case .changed:
            
            //translate to follow finger tracking
            imageScroll.setContentOffset(CGPoint(x: imageOffset0 - translation.x, y: imageScroll.contentOffset.y), animated: false)
            
        case .ended, .cancelled:
            
            /// this is getting called too much or something
            
            let finalOffset = imageScroll.contentOffset.x - direction.x
            let positionWidth = 9 + imageWidth
            let rawPosition = max(min(Int(round(finalOffset / positionWidth)), post.frameIndexes!.count - 1), 0)
            let finalPosition = rawPosition > post.selectedImageIndex ? post.selectedImageIndex + 1 : rawPosition < post.selectedImageIndex ? post.selectedImageIndex - 1 : post.selectedImageIndex
                                  
            scrollToImageAt(position: finalPosition, animated: true)
            
            gesture.setTranslation(CGPoint(x: 0, y: 0), in: self)
            
        default:
            return
        }
    }
    
    @objc func verticalSwipe(_ gesture: UIPanGestureRecognizer) {
        verticalSwipe(gesture: gesture)
    }
    
    func scrollToImageAt(position: Int, animated: Bool) {
        
        let rowOffset = CGFloat(position) * (imageWidth + 9)
        post.selectedImageIndex = position
        guard let postVC = viewContainingController() as? PostViewController else { return }
        postVC.postsList[globalRow].selectedImageIndex = post.selectedImageIndex
        postVC.updateParentImageIndex(post: post, row: globalRow)
        
        /// set new image info
        if !animated {
            imageScroll.setContentOffset(CGPoint(x: rowOffset, y: self.imageScroll.contentOffset.y), animated: false)
            imageOffset0 = imageScroll.contentOffset.x
            resetMaskFrame(position: position)
            return
        }
        
        UIView.animate(withDuration: 0.2) {
            self.imageScroll.setContentOffset(CGPoint(x: rowOffset, y: self.imageScroll.contentOffset.y), animated: false)
     
        } completion: { [weak self] _ in
            
            guard let self = self else { return }
            self.imageOffset0 = self.imageScroll.contentOffset.x
            self.resetMaskFrame(position: position)
        }
    }
    
    func resetMaskFrame(position: Int) {
        /// set image mask bounds to reflect current image
        if imageMask != nil {
            
            guard let imageView = imageScroll.subviews.first(where: ({$0.tag == position && $0 is PostImageView})) as? PostImageView else { return }
            let minX = imageView.frame.minX - imageScroll.contentOffset.x
            let minY = imageView.frame.minY + navBarHeight + imageScroll.frame.minY
                    
            imageMask.originalFrame = CGRect(x: minX, y: minY, width: imageView.frame.width, height: imageView.frame.height)
        }
    }
    
    func resetCellFrame() {

        if let tableView = self.superview as? UITableView {
            DispatchQueue.main.async { UIView.animate(withDuration: 0.15) {
                tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
                }
            }
        }
    }
    
    func verticalSwipe(gesture: UIPanGestureRecognizer) {
        
        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
            
        guard let postVC = viewContainingController() as? PostViewController else { return }

        /// offset drawer if touch occurs in topview
        let closed = postVC.mapVC.prePanY > 200
        if beginningSwipe != 0 && beginningSwipe < 80 && closed { offsetDrawer(gesture: gesture); return }
        if imageMask.zooming { return }
        
        let offsetY = 0
        if Int(postVC.mapVC.customTabBar.view.frame.minY) != offsetY {
            /// offset drawer if its closed and image stole gesture
            offsetDrawer(gesture: gesture)
            return
        }
        
        /* offset drawer if its closed and gesture passed to here
        if postVC.mapVC.prePanY > 200 {
            offsetDrawer(gesture: gesture)
            return
        } */
                
        if let tableView = self.superview as? UITableView {
            
            /// swipe to exit if horizontal swipe
            if (abs(translation.x) > abs(translation.y) && translation.x > 0 && tableView.contentOffset.y == originalOffset) || postVC.view.frame.minX > 0 {
                if parentVC != .feed && imageScroll.contentOffset.x == 0 { swipeToExit(gesture: gesture) }
                return
            }
            
            /// cancel on image zoom or swipe if not swiping to exit
            
            func removeGestures() {
                if let gestures = self.gestureRecognizers {
                    for gesture in gestures {
                        self.removeGestureRecognizer(gesture)
                    }
                }
            }

            switch gesture.state {
            
            case .began:
                let location = gesture.location(in: self)
                beginningSwipe = location.y
                originalOffset = tableView.contentOffset.y
                
            case .changed:
                tableView.setContentOffset(CGPoint(x: 0, y: originalOffset - translation.y), animated: false)
                
            case .ended, .cancelled:

                beginningSwipe = 0
                
                if direction.y < 0 || direction.y == 0 && originalOffset + translation.y < 0 {
                    // if we're halfway down the next cell, animate to next cell
                    /// return if at end of posts and theres no loading cell next
                    if self.selectedPostIndex == self.postsCount - 1 { self.resetCellFrame(); return }
                                        
                    if (tableView.contentOffset.y - direction.y > originalOffset + cellHeight/4) && (self.selectedPostIndex < self.postsCount) {
                        
                        self.selectedPostIndex += 1
                        self.notifyIndexChange()
                        
                    } else {
                        // return to original state
                        self.resetCellFrame()
                    }
                    
                } else {
                    
                    let offsetTable = tableView.contentOffset.y - direction.y
                    let borderHeight = originalOffset - cellHeight * 3/4

                    if (offsetTable < borderHeight) && self.selectedPostIndex > 0 {
                        /// animate to previous post
                        self.selectedPostIndex -= 1
                        self.notifyIndexChange()

                    } else {
                        // return to original state
                        self.resetCellFrame()
                    }
                }
                
            default:
                return
            }
        }
    }
    
    func notifyIndexChange() {
        let infoPass = ["index": self.selectedPostIndex as Any, "id": vcid as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostIndexChange"), object: nil, userInfo: infoPass)
        /// send notification to map to change post annotation location
        let mapPass = ["selectedPost": self.selectedPostIndex as Any, "firstOpen": false, "parentVC": parentVC as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
        removeGestures()
    }
    
    func resetPostFrame() {
        
        if let postVC = self.viewContainingController() as? PostViewController {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.2) {
                    postVC.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: { [weak self] in
                guard let self = self else { return }
                self.offScreen = false
            })
        }
        /// reset horizontal image scroll if necessary
    }
    
    func swipeToExit(gesture: UIPanGestureRecognizer) {
                
        guard let postVC = self.viewContainingController() as? PostViewController else { return }
        let velocity = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)

        func animateRemovePost() {
            Mixpanel.mainInstance().track(event: "PostPageSwipeToExit")
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.2) {
                    postVC.view.frame = CGRect(x: UIScreen.main.bounds.width, y: postVC.view.frame.minY, width: postVC.view.frame.width, height: postVC.view.frame.height)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self = self else { return }
                    self.exitPosts()
                }
            }
        }
        
        switch gesture.state {
        
        case .began:
            offScreen = true
            
        case .changed:
            DispatchQueue.main.async { postVC.view.frame = CGRect(x: translation.x, y: postVC.view.frame.minY, width: postVC.view.frame.width, height: postVC.view.frame.height) }
            
        case .ended:
            if velocity.x + translation.x > UIScreen.main.bounds.width * 3/4 {
                animateRemovePost()
            } else {
                resetPostFrame()
            }
            
        default: return
        }
    }
    
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {

        //only close view on maskView touch
        if editView != nil && touch.view?.isDescendant(of: editView) == true {
            return false
        } else if notFriendsView != nil && touch.view?.isDescendant(of: notFriendsView) == true {
            return false
        } else if editPostView != nil {
            return false
        }
        return true
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.view is PostImageView && otherGestureRecognizer.view is PostImageView /// only user for postImage zoom / swipe
    }
    
    func getGifImages(selectedImages: [UIImage], frameIndexes: [Int], imageIndex: Int) -> [UIImage] {

        guard let selectedFrame = frameIndexes[safe: imageIndex] else { return [] }
        
        if frameIndexes.count == 1 {
            return selectedImages.count > 1 ? selectedImages : []
        } else if frameIndexes.count - 1 == imageIndex {
            return selectedImages[selectedFrame] != selectedImages.last ? selectedImages.suffix(selectedImages.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[imageIndex + 1]
            return frame1 - selectedFrame > 1 ? Array(selectedImages[selectedFrame...frame1 - 1]) : []
        }
    }
}

///supplementary view methods
extension PostCell {
    
    //1. not friends methods
    func addNotFriends() {
        
        if let postVC = self.viewContainingController() as? PostViewController {
            
            postVC.notFriendsView = true
            
            addPostMask(edit: false)
            
            notFriendsView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 128.5, y: self.frame.height/2 - 119, width: 257, height: 191))
            notFriendsView.backgroundColor = UIColor(red: 0.086, green: 0.086, blue: 0.086, alpha: 1)
            notFriendsView.layer.cornerRadius = 7.5
            postMask.addSubview(notFriendsView)
            
            let friendsExit = UIButton(frame: CGRect(x: notFriendsView.frame.width - 33, y: 4, width: 30, height: 30))
            friendsExit.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            friendsExit.setImage(UIImage(named: "CancelButton"), for: .normal)
            friendsExit.addTarget(self, action: #selector(exitNotFriends(_:)), for: .touchUpInside)
            notFriendsView.addSubview(friendsExit)
            
            let privacyLabel = UILabel(frame: CGRect(x: 45.5, y: 9, width: 166, height: 18))
            privacyLabel.text = "Privacy"
            privacyLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            privacyLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
            privacyLabel.textAlignment = .center
            notFriendsView.addSubview(privacyLabel)
            
            let privacyDescription = UILabel(frame: CGRect(x: 36.5, y: 31, width: 184, height: 36))
            privacyDescription.text = "Must be friends with this spot’s creator for access"
            privacyDescription.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            privacyDescription.font = UIFont(name: "SFCamera-Regular", size: 13.5)
            privacyDescription.textAlignment = .center
            privacyDescription.numberOfLines = 2
            privacyDescription.lineBreakMode = .byWordWrapping
            notFriendsView.addSubview(privacyDescription)
            
            /// load username and profile picture to show on NotFriendsCell -> little lag here, not an ideal func
            getUserInfo(userID: post.createdBy!) { [weak self] (userInfo) in
                
                if userInfo.id == "" { return }
                guard let self = self else { return }
                self.noAccessFriend = userInfo
                
                let profilePic = UIImageView(frame: CGRect(x: 93, y: 87, width: 32, height: 32))
                profilePic.image = UIImage()
                profilePic.clipsToBounds = true
                profilePic.contentMode = .scaleAspectFill
                profilePic.layer.cornerRadius = 16
                self.notFriendsView.addSubview(profilePic)
                
                let url = userInfo.imageURL
                if url != "" {
                    let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
                    profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
                }
                
                let username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 7, y: 96, width: 200, height: 16))
                username.text = userInfo.username
                username.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
                username.font = UIFont(name: "SFCamera-Semibold", size: 13)
                username.sizeToFit()
                self.notFriendsView.addSubview(username)
                
                profilePic.frame = CGRect(x: (257 - username.frame.width - 40)/2, y: 87, width: 32, height: 32)
                username.frame = CGRect(x: profilePic.frame.maxX + 7, y: 96, width: username.frame.width, height: 16)
                
                let usernameButton = UIButton(frame: CGRect(x: username.frame.minY, y: 80, width: 40 + username.frame.width, height: 40))
                usernameButton.backgroundColor = nil
                usernameButton.addTarget(self, action: #selector(self.notFriendsUserTap(_:)), for: .touchUpInside)
                self.notFriendsView.addSubview(usernameButton)
                
                self.getFriendRequestInfo { (pending) in
                    /// check if user already sent a friend request to this person
                    if pending {
                        let pendingLabel = UILabel(frame: CGRect(x: 20, y: 145, width: self.notFriendsView.bounds.width - 40, height: 20))
                        pendingLabel.text = "Friend request pending"
                        pendingLabel.textAlignment = .center
                        pendingLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
                        pendingLabel.textColor = UIColor(named: "SpotGreen")
                        self.notFriendsView.addSubview(pendingLabel)
                        
                    } else {
                        self.addFriendButton = UIButton(frame: CGRect(x: 33, y: 136, width: 191, height: 31.7))
                        self.addFriendButton.setImage(UIImage(named: "AddFriendButton"), for: .normal)
                        self.addFriendButton.addTarget(self, action: #selector(self.addFriendTap(_:)), for: .touchUpInside)
                        self.notFriendsView.addSubview(self.addFriendButton)
                    }
                }
            }
        }
    }
    
    func getUserInfo(userID: String, completion: @escaping (_ userInfo: UserProfile) -> Void) {
        
        self.db.collection("users").document(userID).getDocument { (snap, err) in
            
            do {
                let userInfo = try snap?.data(as: UserProfile.self)
                guard var info = userInfo else {completion(UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")); return }
                info.id = snap!.documentID
                completion(info)
                
            } catch { completion(UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")); return }
        }
    }
    
    
    func getFriendRequestInfo(completion: @escaping(_ pending: Bool) -> Void) {
        
        // check each users notificaitons for a pending friend request and fill completion handler
        let userRef = db.collection("users").document(uid).collection("notifications")
        let userQuery = userRef.whereField("type", isEqualTo: "friendRequest").whereField("senderID", isEqualTo: noAccessFriend.id!)
        
        var zeroCount = 0
        userQuery.getDocuments { (snap, err) in
            
            if err != nil { completion(false); return }
            
            if snap!.documents.count > 0 {
                completion(true); return
                
            } else {
                zeroCount += 1
                if zeroCount == 2 { completion(false); return }
            }
        }
        
        let notiRef = db.collection("users").document(noAccessFriend.id!).collection("notifications")
        let query = notiRef.whereField("type", isEqualTo: "friendRequest").whereField("senderID", isEqualTo: uid)
        query.getDocuments { (snap2, err) in
            
            if err != nil { completion(false); return }

            if snap2!.documents.count > 0 {
                completion(true); return
                
            } else {
                zeroCount += 1
                if zeroCount == 2 { completion(false); return }
            }
        }
    }
    
    @objc func tapExitNotFriends(_ sender: UIButton) {
        exitNotFriends()
    }
    
    @objc func exitNotFriends(_ sender: UIButton) {
        exitNotFriends()
    }
    
    func exitNotFriends() {
        
        for sub in notFriendsView.subviews {
            sub.removeFromSuperview()
        }
        
        notFriendsView.removeFromSuperview()
        postMask.removeFromSuperview()
        
        if notFriendsView != nil { notFriendsView = nil }
        
        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.notFriendsView = false
        }
    }
    
    @objc func notFriendsUserTap(_ sender: UIButton) {
        if noAccessFriend != nil {
            openProfile(user: noAccessFriend)
            exitNotFriends()
        }
    }
    
    @objc func addFriendTap(_ sender: UIButton) {
        
        self.addFriendButton.isHidden = true
        
        let pendingLabel = UILabel(frame: CGRect(x: 20, y: 145, width: notFriendsView.bounds.width - 40, height: 20))
        pendingLabel.text = "Friend request pending"
        pendingLabel.textAlignment = .center
        pendingLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        pendingLabel.textColor = UIColor(named: "SpotGreen")
        notFriendsView.addSubview(pendingLabel)
        
        addFriend(senderProfile: UserDataModel.shared.userInfo, receiverID: self.noAccessFriend.id!)
    }
    
    func addPostMask(edit: Bool) {
        
        postMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        postMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        let tap = edit ? UITapGestureRecognizer(target: self, action: #selector(tapExitEditOverview(_:))) : UITapGestureRecognizer(target: self, action: #selector(tapExitNotFriends(_:)))
        tap.delegate = self
        postMask.addGestureRecognizer(tap)

        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.mapVC.view.addSubview(postMask)
        }
    }
    
    //2. editOverview
    
    func addEditOverview() {
        
        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.editView = true
        }
        
        editView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 102, y: UIScreen.main.bounds.height/2 - 119, width: 204, height: 110))
        editView.backgroundColor = UIColor(red: 0.086, green: 0.086, blue: 0.086, alpha: 1)
        editView.layer.cornerRadius = 7.5
        
        addPostMask(edit: true)
        
        postMask.addSubview(editView)
        
        let postExit = UIButton(frame: CGRect(x: editView.frame.width - 33, y: 4, width: 30, height: 30))
        postExit.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        postExit.setImage(UIImage(named: "CancelButton"), for: .normal)
        postExit.addTarget(self, action: #selector(exitEditOverview(_:)), for: .touchUpInside)
        editView.addSubview(postExit)
        
        if post.posterID != uid {
            let reportButton = UIButton(frame: CGRect(x: 45, y: 36.5, width: 118, height: 44))
            reportButton.setImage(UIImage(named: "ReportSpotButton"), for: .normal)
            reportButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            reportButton.contentHorizontalAlignment = .center
            reportButton.contentVerticalAlignment = .center
            reportButton.addTarget(self, action: #selector(reportPostTap(_:)), for: .touchUpInside)
            editView.addSubview(reportButton)
            
        } else {
            let editPost = UIButton(frame: CGRect(x: 41, y: 47, width: 116, height: 35))
            editPost.setImage(UIImage(named: "EditPostButton"), for: .normal)
            editPost.backgroundColor = nil
            editPost.addTarget(self, action: #selector(editPostTapped(_:)), for: .touchUpInside)
            editPost.imageView?.contentMode = .scaleAspectFit
            editView.addSubview(editPost)
            
            ///expand the edit view frame for 2 buttons
            editView.frame = CGRect(x: editView.frame.minX, y: editView.frame.minY, width: editView.frame.width, height: 171)
            
            let deleteButton = UIButton(frame: CGRect(x: 46, y: 100, width: 112, height: 29))
            deleteButton.setImage(UIImage(named: "DeletePostButton"), for: UIControl.State.normal)
            deleteButton.backgroundColor = nil
            deleteButton.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
            editView.addSubview(deleteButton)
        }
    }
    
    @objc func exitEditOverview(_ sender: UIButton) {
        exitEditOverview()
    }
        
    func exitEditOverview() {
        
        /// exit edit overview called every time removing the mask 
        if editView != nil {
            for sub in editView.subviews {
                sub.removeFromSuperview()
            }
            editView.removeFromSuperview()
            editView = nil
        }
                
        postMask.removeFromSuperview()
        
        if let postVC = self.viewContainingController() as? PostViewController {
            postVC.editView = false
            postVC.editPostView = false
            postVC.mapVC.removeTable()
        }
    }
    
    @objc func tapExitEditOverview(_ sender: UITapGestureRecognizer) {
        exitEditOverview()
    }

    @objc func editPostTapped(_ sender: UIButton) {
        addEditPostView(editedPost: post)
    }
    
    //3. edit post view (handled by custom class)
    func addEditPostView(editedPost: MapPost) {

        if editPostView != nil && editPostView.superview != nil { return }
        Mixpanel.mainInstance().track(event: "EditPostOpen")
        
        let viewHeight: CGFloat = post.spotID == "" ? 348 : 410
        editPostView = EditPostView(frame: CGRect(x: (UIScreen.main.bounds.width - 331)/2, y: UIScreen.main.bounds.height/2 - 220, width: 331, height: viewHeight))
        editPostView.row = globalRow
        
        if postMask == nil { self.addPostMask(edit: true) }
        
        if let postVC = self.viewContainingController() as? PostViewController {
            
            if postMask.superview == nil {
                ///post mask removed from view on transition to address picker
                postVC.mapVC.view.addSubview(postMask)
            }
            postMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            
            postMask.addSubview(editPostView)
            
            if editView != nil { editView.removeFromSuperview() }
            
            postVC.editedPost = editedPost
            postVC.editView = false
            postVC.editPostView = true
            editPostView.setUp(post: editedPost, postVC: postVC)
        }
    }
    
    //4. post delete
    
    @objc func deleteTapped(_ sender: UIButton) {
        checkForZero() /// check to see if this is the only post at a spot
    }
        
    func checkForZero() {
        
        let singlePostMessage = "Deleting the only post at a spot will delete the entire spot"
        let postSpot = MapSpot(spotDescription: "", spotName: "", spotLat: 0, spotLong: 0, founderID: "", privacyLevel: "", imageURL: "")
        
        if post.spotID == nil {
            /// present with blank spot object because wont need it
            presentDeleteMenu(message: "", deleteSpot: false, spot: postSpot)
            
        } else if parentVC == .spot {
            guard let postVC = self.viewContainingController() as? PostViewController else { return }
            guard let spotVC = postVC.parent as? SpotViewController else { return }
            let deleteSpot = spotVC.postsList.count == 1
            let singlePostMessage = "Deleting the only post at a spot will delete the entire spot"
            let message = deleteSpot && spotVC.spotObject.privacyLevel != "public" ? singlePostMessage : ""
            presentDeleteMenu(message: message, deleteSpot: deleteSpot, spot: spotVC.spotObject)
            
        } else {
            
            addDeleteIndicator()
            
            self.db.collection("spots").document(post.spotID!).getDocument { (snap, err) in
                
                do {

                    let info = try snap?.data(as: MapSpot.self)
                    guard let postSpot = info else { self.presentDeleteMenu(message: "", deleteSpot: false, spot: postSpot); return }
                    
                    let deleteSpot = postSpot.postIDs.count == 1
                    /// don't show message for POI, delete on backend but user doesn't need to think they're deleting a public place
                    let message = deleteSpot ? postSpot.privacyLevel == "public" ? "" : singlePostMessage : ""
                    self.presentDeleteMenu(message: message, deleteSpot: deleteSpot, spot: postSpot)
                    self.removeDeleteIndicator()

                } catch {
                    self.presentDeleteMenu(message: "", deleteSpot: false, spot: postSpot)
                    return
                }
            }
        }
    }
    
    func addDeleteIndicator() {
        /// add delete indicator while checking if this is the only post at the spot
        deleteIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 30))
        deleteIndicator.startAnimating()
        postMask.addSubview(deleteIndicator)
    }

    func removeDeleteIndicator() {
        deleteIndicator.removeFromSuperview()
        deleteIndicator = nil
    }
    
    
    func presentDeleteMenu(message: String, deleteSpot: Bool, spot: MapSpot) {
        
        if let postVC = self.viewContainingController() as? PostViewController {
            
            let alert = UIAlertController(title: "Delete Post?", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                switch action.style{
                case .default:
                    ///remove edit view
                    postVC.tableView.reloadData()
                case .cancel:
                    print("cancel")
                case .destructive:
                    print("destruct")
                @unknown default:
                    fatalError()
                }}))
            
            alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
                                            
                switch action.style{
                
                case .default:
                    
                    postVC.mapVC.deletedPostIDs.append(self.post.id!)
                    
                    ///update database
                    self.postDelete(deletePost: self.post!, spotDelete: deleteSpot, spot: spot)
                   
                    Mixpanel.mainInstance().track(event: "PostPagePostDelete")
                    
                    ///update postVC + send noti
                    DispatchQueue.main.async {
                        let infoPass: [String: Any] = ["postID": [self.post.id] as Any]
                        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
                    }
                    
                    
                case .cancel:
                    print("cancel")
                case .destructive:
                    print("destruct")
                @unknown default:
                    fatalError()
                }}))
            
            if editView == nil { return } /// user tapped off during load
            
            editView.removeFromSuperview()
            postMask.removeFromSuperview()
            postVC.editView = false
            postVC.present(alert, animated: true, completion: nil)
        }

    }
    
    
    func postDelete(deletePost: MapPost, spotDelete: Bool, spot: MapSpot) {
        
        let functions = Functions.functions()

        let postCopy = deletePost
        
        if let postVC = self.viewContainingController() as? PostViewController {

            /// delete funcs
            DispatchQueue.global(qos: .userInitiated).async {
                
                let spotID = postCopy.spotID!

                if spotDelete {
                                        
                    /// posters is visitorList here just to adjust users' spotsList
                    let posters = spot.visitorList
                    
                    functions.httpsCallable("postDelete").call(["postIDs": [postCopy.id], "spotID": spotID, "uid": self.uid, "posters": posters, "postTag": postCopy.tag ?? "", "spotDelete": true]) { result, error in
                        print("result", result?.data as Any, error as Any)
                    }

                    postVC.mapVC.deletedSpotIDs.append(spotID)
                    
                    /// pass spotDelete noti and pop off of spot page if applicable
                    DispatchQueue.main.async {
                        let infoPass: [String: Any] = ["spotID": spotID as Any]
                        NotificationCenter.default.post(name: Notification.Name("DeleteSpot"), object: nil, userInfo: infoPass)
                        
                        if let spotVC = postVC.parent as? SpotViewController {
                            postVC.willMove(toParent: nil)
                            postVC.view.removeFromSuperview()
                            postVC.removeFromParent()
                            spotVC.removeSpotPage(delete: true)
                        }
                    }
                    
                } else {
                    
                    var posters = deletePost.addedUsers ?? []
                    posters.append(self.uid)

                    functions.httpsCallable("postDelete").call(["postIDs": [postCopy.id], "spotID": spotID, "uid": self.uid, "spotDelete": false, "posters": posters, "postTag": postCopy.tag ?? ""]) { result, error in
                        guard let data = result?.data as? [String: Any], let userDelete = data["userDelete"] as? Bool else { return }
                        print("user delete", userDelete)
                        /// send local notification to remove from usersSpotsList if deleted here
                        if userDelete {
                            DispatchQueue.main.async {
                                let infoPass: [String: Any] = ["spotID": spotID as Any]
                                NotificationCenter.default.post(name: Notification.Name("DeleteSpot"), object: nil, userInfo: infoPass)
                            }
                        }
                    }
                }
            }
        }
    }
}


class LoadingCell: UITableViewCell {
    
    var activityIndicator: CustomActivityIndicator!
    var selectedPostIndex: Int!
    var originalOffset: CGFloat!
    var parentVC: PostViewController.parentViewController!
    var vcid: String!
    
    func setUp(selectedPostIndex: Int, parentVC: PostViewController.parentViewController, vcid: String) {
        
        self.selectedPostIndex = selectedPostIndex
        self.parentVC = parentVC
        self.vcid = vcid
        self.originalOffset = 0.0

        self.tag = 16
        
        if activityIndicator != nil { activityIndicator.removeFromSuperview() }
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 40))
        activityIndicator.startAnimating()
        self.addSubview(activityIndicator)
        
        let nextPan = UIPanGestureRecognizer(target: self, action: #selector(verticalSwipe(_:)))
        self.addGestureRecognizer(nextPan)
    }
    
    @objc func verticalSwipe(_ gesture: UIPanGestureRecognizer) {
        
        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
        
        if let tableView = self.superview as? UITableView {
            
            func resetCell() {
                DispatchQueue.main.async { UIView.animate(withDuration: 0.2) {
                    tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false) }
                }
            }
            
            func removeGestures() {
                if let gestures = self.gestureRecognizers {
                    for gesture in gestures {
                        self.removeGestureRecognizer(gesture)
                    }
                }
            }
            switch gesture.state {
            
            case .began:
                originalOffset = tableView.contentOffset.y
                
            case .changed:
                tableView.setContentOffset(CGPoint(x: 0, y: originalOffset - translation.y), animated: false)
                
            case .ended, .cancelled:
                if direction.y < 0 {
                    resetCell()
                } else {
                    let offsetTable = tableView.contentOffset.y - direction.y
                    let borderHeight = originalOffset - self.bounds.height * 3/4
                    if (offsetTable < borderHeight) && self.selectedPostIndex > 0 {
                        //animate to previous post
                        self.selectedPostIndex -= 1
                        let infoPass = ["index": self.selectedPostIndex as Any, "id": vcid as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostIndexChange"), object: nil, userInfo: infoPass)
                        // send notification to map to change post annotation location
                        let mapPass = ["selectedPost": self.selectedPostIndex as Any, "firstOpen": false, "parentVC": parentVC as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                        removeGestures()
                        return
                    } else {
                        // return to original state
                        resetCell()
                    }
                }
            default:
                return
            }
        }
    }
}


///https://stackoverflow.com/questions/12591192/center-text-vertically-in-a-uitextview

extension UILabel {
    
    func addTrailing(with trailingText: String, moreText: String, moreTextFont: UIFont, moreTextColor: UIColor) {
        
        let readMoreText: String = trailingText + moreText
        
        if self.visibleTextLength == 0 { return }
        
        let lengthForVisibleString: Int = self.visibleTextLength
        
        if let myText = self.text {
                                    
            let mutableString = NSString(string: myText) /// use mutable string for length for correct length calculations
            
            let trimmedString: String? = mutableString.replacingCharacters(in: NSRange(location: lengthForVisibleString, length: mutableString.length - lengthForVisibleString), with: "")
            let readMoreLength: Int = (readMoreText.count)
            
            let safeTrimmedString = NSString(string: trimmedString ?? "")
            
            if safeTrimmedString.length <= readMoreLength { return }
            
            // "safeTrimmedString.count - readMoreLength" should never be less then the readMoreLength because it'll be a negative value and will crash
            let trimmedForReadMore: String = (safeTrimmedString as NSString).replacingCharacters(in: NSRange(location: safeTrimmedString.length - readMoreLength, length: readMoreLength), with: "") + trailingText
                        
            let answerAttributed = NSMutableAttributedString(string: trimmedForReadMore, attributes: [NSAttributedString.Key.font: self.font as Any])
            let readMoreAttributed = NSMutableAttributedString(string: moreText, attributes: [NSAttributedString.Key.font: moreTextFont, NSAttributedString.Key.foregroundColor: moreTextColor])
            answerAttributed.append(readMoreAttributed)
            self.attributedText = answerAttributed
        }
    }
    
    var visibleTextLength: Int {
        
        let font: UIFont = self.font
        let mode: NSLineBreakMode = self.lineBreakMode
        let labelWidth: CGFloat = self.frame.size.width
        let labelHeight: CGFloat = self.frame.size.height
        let sizeConstraint = CGSize(width: labelWidth, height: CGFloat.greatestFiniteMagnitude)
        
        if let myText = self.text {
            
            let attributes: [AnyHashable: Any] = [NSAttributedString.Key.font: font]
            let attributedText = NSAttributedString(string: myText, attributes: attributes as? [NSAttributedString.Key : Any])
            let boundingRect: CGRect = attributedText.boundingRect(with: sizeConstraint, options: .usesLineFragmentOrigin, context: nil)
            
            if boundingRect.size.height > labelHeight {
                var index: Int = 0
                var prev: Int = 0
                let characterSet = CharacterSet.whitespacesAndNewlines
                repeat {
                    prev = index
                    if mode == NSLineBreakMode.byCharWrapping {
                        index += 1
                    } else {
                        index = (myText as NSString).rangeOfCharacter(from: characterSet, options: [], range: NSRange(location: index + 1, length: myText.count - index - 1)).location
                    }
                } while index != NSNotFound && index < myText.count && (myText as NSString).substring(to: index).boundingRect(with: sizeConstraint, options: .usesLineFragmentOrigin, attributes: attributes as? [NSAttributedString.Key : Any], context: nil).size.height <= labelHeight
                return prev
            }
        }
        
        if self.text == nil {
            return 0
        } else {
            return self.text!.count
        }
    }
}
///https://stackoverflow.com/questions/32309247/add-read-more-to-the-end-of-uilabel

class PostImageLoader: Operation {
    
    /// set of operations for loading a postImage 
    var images: [UIImage] = []
    var loadingCompleteHandler: (([UIImage]?) -> ())?
    private var post: MapPost
    
    init(_ post: MapPost) {
        self.post = post
    }
        
    override func main() {

        if isCancelled { return }
        
        var imageCount = 0
        var images: [UIImage] = []
        for _ in post.imageURLs {
            images.append(UIImage())
        }
        
        func imageEscape() {
            
            imageCount += 1
            if imageCount == post.imageURLs.count {
                self.images = images
                self.loadingCompleteHandler?(images)
            }
        }
        
        if post.imageURLs.count == 0 { return }

        var frameIndexes = post.frameIndexes ?? []
        if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i) } }
        
        var aspectRatios = post.aspectRatios ?? []
        if aspectRatios.isEmpty { for _ in 0...post.imageURLs.count - 1 { aspectRatios.append(1.3333) } }

        var currentAspect: CGFloat = 1
        
        for x in 0...post.imageURLs.count - 1 {
            
            let postURL = post.imageURLs[x]
            if let y = frameIndexes.firstIndex(where: {$0 == x}) { currentAspect = aspectRatios[y] }
            
            let transformer = SDImageResizingTransformer(size: CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.width * 2 * currentAspect), scaleMode: .aspectFit)

            SDWebImageManager.shared.loadImage(with: URL(string: postURL), options: [.highPriority, .scaleDownLargeImages], context: [.imageTransformer: transformer], progress: nil) { (rawImage, data, err, cache, download, url) in
                DispatchQueue.main.async { [weak self] in
                    
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    
                    let i = self.post.imageURLs.lastIndex(where: {$0 == postURL})
                    guard let image = rawImage else { images[i ?? 0] = UIImage(); imageEscape(); return } /// return blank image on failed download
                    images[i ?? 0] = image
                    imageEscape()
                }
            }
        }
    }
}

class PostImageView: UIImageView {
    
    var stillImage: UIImage = UIImage()
    var animationCounter = 0
    var navBarHeight: CGFloat!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        tag = 16
        clipsToBounds = true
        isUserInteractionEnabled = true
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        contentMode = .scaleAspectFill
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageExpand(_:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func imageExpand(_ sender: UITapGestureRecognizer) {
        
        guard let postCell = superview?.superview as? PostCell else { return }
        if postCell.post.imageURLs.contains(where: {$0 == ""}) { return } /// patch fix for being able to expand image on failed image upload post
        
        postCell.imageMask.isHidden = false
        postCell.imageMask.alpha = 0.0
        
        let minX = frame.minX - postCell.imageScroll.contentOffset.x
        let minY = self.frame.minY + navBarHeight + postCell.imageScroll.frame.minY
        
        let originalFrame = CGRect(x: minX, y: minY, width: self.frame.width, height: self.frame.height)
        
        if postCell.globalRow != postCell.selectedPostIndex {

            postCell.selectedPostIndex += 1; postCell.notifyIndexChange()
            if tag != postCell.post.selectedImageIndex {
                /// delayed scroll to next cell if scrolling to next row
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self = self else { return }
                    postCell.scrollToImageAt(position: self.tag, animated: true)
                }
            }
            
        } else if tag != postCell.post.selectedImageIndex { postCell.scrollToImageAt(position: tag, animated: true) }
        
        postCell.imageMask.imageExpand(originalFrame: originalFrame, frameIndexes: postCell.post.frameIndexes ?? [], images: postCell.post.postImage, selectedIndex: tag, alive: postCell.post.gif ?? false)
        postCell.imageMask.postCell = postCell
    }
}
