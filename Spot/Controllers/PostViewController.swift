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

class PostViewController: UIViewController {

    lazy var postsList: [MapPost] = []

    var spotObject: MapSpot!
    var tableView: UITableView!
    var cellHeight, closedY, tabBarHeight: CGFloat!
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
        
        tabBarHeight = tabBar?.tabBar.frame.height ?? 44 + safeBottom
        closedY = !(tabBar?.tabBar.isHidden ?? false) ? tabBarHeight + 77 : safeBottom + 115
        cellHeight = UIScreen.main.bounds.height > 800 ? (UIScreen.main.bounds.width * 1.72267) : (UIScreen.main.bounds.width * 1.5)
        cellHeight += tabBarHeight
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.tag = 16
        tableView.backgroundColor = nil
        tableView.allowsSelection = false
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.prefetchDataSource = self
        tableView.isScrollEnabled = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: cellHeight, right: 0)
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
        
        if self.commentNoti {
            self.openComments()
            self.commentNoti = false
        }

        if parentVC != .feed {
            
            setUpNavBar()
            
            if parentVC == .spot {
                /// add spot name banner over the top of feed for spot page
                let pan = UIPanGestureRecognizer(target: self, action: #selector(topViewTableSwipe(_:)))

                let spotNameBanner = UIView(frame: CGRect(x: 12, y: 19, width: UIScreen.main.bounds.width - 63, height: 30))
                spotNameBanner.backgroundColor = nil
                spotNameBanner.addGestureRecognizer(pan)
                view.addSubview(spotNameBanner)
                
                let targetIcon = UIImageView(frame: CGRect(x: 0, y: 0.5, width: 19, height: 19))
                targetIcon.image = UIImage(named: "PlainSpotIcon")
                targetIcon.isUserInteractionEnabled = false
                spotNameBanner.addSubview(targetIcon)
                
                let spotNameLabel = UILabel(frame: CGRect(x: 22, y: 2.5, width: UIScreen.main.bounds.width - 40, height: 14.5))
                spotNameLabel.lineBreakMode = .byTruncatingTail
                spotNameLabel.text = spotObject.spotName
                spotNameLabel.textColor = .white
                spotNameLabel.clipsToBounds = true
                spotNameLabel.isUserInteractionEnabled = false
                spotNameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
                spotNameLabel.sizeThatFits(CGSize(width: UIScreen.main.bounds.width - 40, height: 14.5))
                
                spotNameBanner.addSubview(spotNameLabel)
                
                let cityLabel = UILabel(frame: CGRect(x: 1, y: spotNameLabel.frame.maxY + 3, width: 300, height: 14))
                cityLabel.isUserInteractionEnabled = false
                cityLabel.text = spotObject.city ?? ""
                cityLabel.textColor = UIColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.00)
                cityLabel.font = UIFont(name: "SFCamera-Semibold", size: 11.5)
                cityLabel.sizeToFit()
                spotNameBanner.addSubview(cityLabel)
                
                spotNameBanner.sizeToFit()
                
                let tempLabel = spotNameLabel
                tempLabel.sizeToFit()
                
                let tapButton = UIButton(frame: CGRect(x: 4, y: 14, width: tempLabel.frame.width + 35, height: tempLabel.frame.height + 15))
                tapButton.addTarget(self, action: #selector(spotNameTap(_:)), for: .touchUpInside)
                view.addSubview(tapButton)
                
            }
        }
    }
    
    @objc func notifyImageChange(_ sender: NSNotification) {

        if let info = sender.userInfo as? [String: Any] {
            
            guard let id = info["id"] as? String else { return }
            if id != vcid { return }
            guard let post = info["post"] as? MapPost else { return }
            
            if postsList[selectedPostIndex].selectedImageIndex != post.selectedImageIndex { if let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell { cell.animationCounter = 0; cell.postImage.animationImages?.removeAll() } } /// reset animation counter so that next post, if gif, starts animating at 0
            
            postsList[selectedPostIndex].selectedImageIndex = post.selectedImageIndex /// this really just resets the selected image index of the post before reloading data
            updateParentImageIndex(post: post)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.tableView.reloadRows(at: [IndexPath(row: self.selectedPostIndex, section: 0)], with: .none)
            }
        }
    }
    
    func addPullLineAndNotifications() {
        /// broken out into its own function so it can be called on transition from tutorial to regular view
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyImageChange(_:)), name: Notification.Name("PostImageChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyIndexChange(_:)), name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAddressChange(_:)), name: NSNotification.Name("PostAddressChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostTap(_:)), name: NSNotification.Name("FeedPostTap"), object: nil)
        
        if parentVC != .feed { mapVC.toggleMapTouch(enable: true) }
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(topViewTableSwipe(_:)))

        let pullLine = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 21.5, y: 0, width: 43, height: 14.5))
        pullLine.contentEdgeInsets = UIEdgeInsets(top: 7, left: 5, bottom: 0, right: 5)
        pullLine.setImage(UIImage(named: "PullLine"), for: .normal)
        pullLine.addTarget(self, action: #selector(lineTap(_:)), for: .touchUpInside)
        pullLine.addGestureRecognizer(pan)
        view.addSubview(pullLine)
    }
    
    func updateParentImageIndex(post: MapPost) {
        if let feedVC = parent as? FeedViewController {
            if feedVC.selectedSegmentIndex == 0 {
                if feedVC.selectedPostIndex != selectedPostIndex { return } /// these should always be equal but caused a crash once for index out of bounds so checking that edge case
                feedVC.friendPosts[selectedPostIndex].selectedImageIndex = post.selectedImageIndex
            } else {
                if feedVC.selectedPostIndex != selectedPostIndex { return }
                feedVC.nearbyPosts[selectedPostIndex].selectedImageIndex = post.selectedImageIndex
            }
        } else if let profilePostsVC = parent as? ProfilePostsViewController {
            if profilePostsVC.postsList.count <= selectedPostIndex { return }
            profilePostsVC.postsList[selectedPostIndex].selectedImageIndex = post.selectedImageIndex
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
                
                if selectedPostIndex != index { if let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell { cell.animationCounter = 0; cell.postImage.animationImages?.removeAll() } }  /// reset animation counter so that next post, if gif, starts animating at 0
                selectedPostIndex = index

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.tableView.reloadData()
                    UIView.animate(withDuration: 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false) }}
                
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
        mapVC.navigationController?.setNavigationBarHidden(true, animated: false)
        
        if parentVC == .notifications {
            if let tabBar = parent?.parent as? CustomTabBar {
                tabBar.view.frame = CGRect(x: 0, y: mapVC.tabBarClosedY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            }
        }
        
        if parentVC == .feed {
            
            mapVC.customTabBar.tabBar.isHidden = false
            
            if let feedVC = parent as? FeedViewController { feedVC.unhideFeedSeg() }

            if selectedPostIndex == 0 && tableView != nil {
                if postsList.count == 0 { self.mapVC.animateToFullScreen(); return }
                DispatchQueue.main.async { self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true) }
            }
                        
        } else {
            setUpNavBar()
        }
        
        ///notify map to show this post
        let firstOpen = !addedLocationPicker /// fucked up nav bar after edit post location
        let mapPass = ["selectedPost": selectedPostIndex as Any, "firstOpen": firstOpen, "parentVC": parentVC] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
        
        addedLocationPicker = false
    }
    
    func setUpNavBar() {
        
        /// add exit button over top of feed for profile and spot page
        mapVC.navigationController?.setNavigationBarHidden(false, animated: false)
        mapVC.navigationController?.navigationBar.isTranslucent = true
        mapVC.navigationController?.navigationBar.removeShadow()
        mapVC.navigationController?.navigationBar.removeBackgroundImage()
        
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
            commentsVC.captionHeight = getCaptionHeight(caption: post.caption)
            
            commentsVC.postVC = self
            commentsVC.userInfo = self.mapVC.userInfo
            present(commentsVC, animated: true, completion: nil)
        }
    }
    
    func getCaptionHeight(caption: String) -> CGFloat {
        
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
            if cell.postImage.frame.minY != 0 { cell.postImage.addTopMask() }
            cell.postImage.frame = CGRect(x: cell.postImage.frame.minX, y: 0, width: cell.postImage.frame.width, height: cell.postImage.frame.height)
            if cell.topView != nil { cell.bringSubviewToFront(cell.topView) }
            if cell.tapButton != nil { cell.bringSubviewToFront(cell.tapButton) }
        })
        
        /// animate post view at same duration as animated zoom -> crash here? -> try to alleviate with weak self call. Could be reference to mapvc?
        UIView.animate(withDuration: 0.4, animations: { [weak self] in
            guard let self = self else { return }
            
            if let annoView = self.mapVC.mapView.view(for: self.mapVC.postAnnotation) {
                annoView.alpha = 1.0
            }
            
            /// show feed seg on animation
            if let feedVC = self.parent as? FeedViewController {
                feedVC.mapVC.feedMask.alpha = 0.0
                feedVC.feedSeg.alpha = 0.0
                feedVC.feedSegBlur.alpha = 0.0
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
        
        let prePanY = parentVC == .feed ? mapVC.tabBarOpenY : mapVC.tabBarClosedY
        mapVC.prePanY = prePanY
        hideFeedButtons()

        let duration: TimeInterval = swipe ? 0.15 : 0.30
        guard let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell else { return }
       
        UIView.animate(withDuration: duration) { [weak self] in
            
            guard let self = self else { return }

            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: prePanY!, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - prePanY!)
            if cell.imageY != 0 { cell.postImage.removeTopMask() }
            cell.postImage.frame = CGRect(x: cell.postImage.frame.minX, y: cell.imageY, width: cell.postImage.frame.width, height: cell.postImage.frame.height)
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
            if let feedVC = self.parent as? FeedViewController {
                feedVC.mapVC.feedMask.alpha = 1.0
                feedVC.feedSeg.alpha = 1.0
                feedVC.feedSegBlur.alpha = 1.0
            }
        })
    }

    @objc func topViewTableSwipe(_ gesture: UIPanGestureRecognizer) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell else { return }
        cell.topViewSwipe(gesture) /// pass through to cell method
    }
    
    @objc func exitPosts(_ sender: UIBarButtonItem) {
        exitPosts()
    }
    
    @objc func spotNameTap(_ sender: UIPanGestureRecognizer) {
        exitPosts()
    }
    
    @objc func lineTap(_ sender: UIButton) {
        guard let _ = tableView.cellForRow(at: IndexPath(row: selectedPostIndex, section: 0)) as? PostCell else { return }
        mapVC.prePanY < 200 ? closeDrawer(swipe: false) : openDrawer(swipe: false)
    }
}

extension PostViewController: UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var postCount = postsList.count

        /// increment postCount if added loading cell at the end. 6 is earliest that cell refresh can happen
        if let postParent = parent as? FeedViewController {
            if postParent.selectedSegmentIndex == 0 && postsEmpty { return 1 } /// only show the postsempty cell if 0 posts available on the friends feed
            if postParent.refresh != .noRefresh { postCount += 1 }
        }

        return postCount
    }
    
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let cell = cell as? PostCell else { return }
        guard let post = postsList[safe: indexPath.row] else { return }
        /// update cell image and related properties on completion
        
        let updateCellImage: ([UIImage]?) -> () = { [weak self] (images) in
            
            guard let self = self else { return }
            
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
        
        /// Try to find an existing data loader
        if let dataLoader = loadingOperations[post.id ?? ""] {
            
            /// Has the data already been loaded?
            if dataLoader.images.count == post.imageURLs.count {

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
            
            cell.setUp(post: post, selectedPostIndex: selectedPostIndex, postsCount: postsCount, parentVC: parentVC, selectedSegmentIndex: selectedSegmentIndex, currentLocation: mapVC.currentLocation, vcid: vcid, row: indexPath.row, cellHeight: cellHeight, tabBarHeight: tabBarHeight, closedY: closedY)
            
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
        return cellHeight
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
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
    
    func openSpotPage(edit: Bool) {
        
        guard let spotVC = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "SpotPage") as? SpotViewController else { return }
        
        let post = postsList[selectedPostIndex]
        
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
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name("PostImageChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.removeObserver(self,  name: NSNotification.Name("PostAddressChange"), object: nil)
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
}

class PostCell: UITableViewCell {
    
    var post: MapPost!
    var selectedSpotID: String!
    
    var topView: UIView!
    var postImage: UIImageView!
    var postImageNext: UIImageView!
    var postImagePrevious: UIImageView!
    var bottomMask: UIView!
    var dotView: UIView!
    
    var spotNameBanner: UIView!
    var tapButton: UIButton!
    var targetIcon: UIImageView!
    var spotNameLabel: UILabel!
    var cityLabel: UILabel!
    
    var userView: UIView!
    var profilePic: UIImageView!
    var username: UILabel!
    var timestamp: UILabel!
    var editButton: UIButton!
    
    var postCaption: UILabel!
    var trueCaptionHeight: CGFloat!
    
    var likeButton, commentButton: UIButton!
    var numLikes, numComments: UILabel!
    
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
    
    var screenSize = 0 /// 0 = iphone8-, 1 = iphoneX + with 375 width, 2 = iPhoneX+ with 414 width
    var offScreen = false /// off screen to avoid double interactions with first cell being pulled down
    var isZooming = false
    var originalCenter: CGPoint! /// used for resetting view after zooming
    var imageManager: SDWebImageManager!
    var globalRow = 0 /// row in table
    var imageY: CGFloat = 0 /// minY of postImage before moving drawer
    var closedY: CGFloat = 0
    var tabBarHeight: CGFloat = 0
    var beginningSwipe: CGFloat = 0
    var animationCounter = 0

    func setUp(post: MapPost, selectedPostIndex: Int, postsCount: Int, parentVC: PostViewController.parentViewController, selectedSegmentIndex: Int, currentLocation: CLLocation, vcid: String, row: Int, cellHeight: CGFloat, tabBarHeight: CGFloat, closedY: CGFloat) {
        
        resetTextInfo()

        self.backgroundColor = UIColor(named: "SpotBlack")
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
        self.cellHeight = cellHeight
        globalRow = row

        originalOffset = CGFloat(selectedPostIndex) * cellHeight
        screenSize = UIScreen.main.bounds.height < 800 ? 0 : UIScreen.main.bounds.width > 400 ? 2 : 1
                        
        let overflowBound = screenSize == 2 ? cellHeight - tabBarHeight - 116 : cellHeight - tabBarHeight - 92 /// clipping standards by ~20 px for iphone8, 3px for X
        /// reset fields so that other cell is completely cleared out
        
        nextPan = UIPanGestureRecognizer(target: self, action: #selector(verticalSwipe(_:)))
        self.addGestureRecognizer(nextPan)
                        
        imageY = screenSize == 0 ? 0 : 64

        postImage = UIImageView(frame: CGRect(x: 0, y: imageY, width: UIScreen.main.bounds.width, height: overflowBound - imageY))
        postImage.image = UIImage(color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0))
        postImage.backgroundColor = nil
        postImage.tag = 16
        postImage.clipsToBounds = true
        postImage.isUserInteractionEnabled = true
        addSubview(postImage)
        
        // load non image related post info
        /// spot name stuff added on each cell unless spot is parent
        if post.spotID != "" && parentVC != .spot {
            /// spot name banner added on the cell for non-spot
            topView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 64))
            let pan = UIPanGestureRecognizer(target: self, action: #selector(topViewSwipe(_:)))
            topView.addGestureRecognizer(pan)
            addSubview(topView)

            spotNameBanner = UIView(frame: CGRect(x: 11, y: 19, width: UIScreen.main.bounds.width - 13, height: 40))
            spotNameBanner.backgroundColor = nil
            topView.addSubview(spotNameBanner)
            
            targetIcon = UIImageView(frame: CGRect(x: 0, y: 0.5, width: 19, height: 19))
            targetIcon.image = UIImage(named: "PlainSpotIcon")
            targetIcon.isUserInteractionEnabled = false
            targetIcon.sizeToFit()
            spotNameBanner.addSubview(targetIcon)
            
            spotNameLabel = UILabel(frame: CGRect(x: 22, y: 2.5, width: UIScreen.main.bounds.width - 40, height: 14.5))
            spotNameLabel.lineBreakMode = .byTruncatingTail
            spotNameLabel.text = post.spotName ?? ""
            spotNameLabel.textColor = .white
            spotNameLabel.isUserInteractionEnabled = false
            spotNameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)
            spotNameLabel.sizeThatFits(CGSize(width: UIScreen.main.bounds.width - 40, height: 14.5))

            spotNameBanner.addSubview(spotNameLabel)
            
            cityLabel = UILabel(frame: CGRect(x: 1, y: spotNameLabel.frame.maxY + 3, width: 300, height: 14))
            cityLabel.isUserInteractionEnabled = false
            cityLabel.text = post.city ?? ""
            cityLabel.textColor = UIColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.00)
            cityLabel.font = UIFont(name: "SFCamera-Regular", size: 11.5)
            cityLabel.sizeToFit()
            spotNameBanner.addSubview(cityLabel)
            
            spotNameBanner.sizeToFit()
            
            let tempLabel = spotNameLabel
            tempLabel!.sizeToFit()
            
            tapButton = UIButton(frame: CGRect(x: 4, y: 14, width: tempLabel!.frame.width + 35, height: tempLabel!.frame.height + 15))
            tapButton.addTarget(self, action: #selector(spotNameTap(_:)), for: .touchUpInside)
            addSubview(tapButton)
        }
        
        var captionHeight = getCaptionHeight(caption: post.caption)
        trueCaptionHeight = captionHeight
                
        let maxCaption: CGFloat = 32
        let overflow = captionHeight > maxCaption
        captionHeight = min(captionHeight, maxCaption)
        
        
        /// adjust to incrementally move user info / caption down
        let freeSpace: CGFloat = cellHeight - tabBarHeight - overflowBound - captionHeight/2 - 33
        var userAdjust = freeSpace/2
        if screenSize == 2 { userAdjust += 4 }
        
        /// adjust up for 2 line caption, down for 0 line caption
        userAdjust += captionHeight > 30 ? -9 : captionHeight == 0 ? 10 : -1
                        
        userView = UIView(frame: CGRect(x: 0, y: overflowBound + userAdjust, width: UIScreen.main.bounds.width, height: 26))
        userView.backgroundColor = nil
        addSubview(userView)
        
        profilePic = UIImageView(frame: CGRect(x: 13, y: 0.5, width: 27, height: 27))
        profilePic.layer.cornerRadius = profilePic.frame.width/2
        profilePic.clipsToBounds = true
        userView.addSubview(profilePic)

        if post.userInfo != nil {
            let url = post.userInfo.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
                profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
        }
        
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: 6, width: 200, height: 16))
        username.text = post.userInfo == nil ? "" : post.userInfo!.username
        username.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        username.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        username.sizeToFit()
        userView.addSubview(username)
        
        let usernameButton = UIButton(frame: CGRect(x: 10, y: 0, width: username.frame.width + 40, height: 25))
        usernameButton.backgroundColor = nil
        usernameButton.addTarget(self, action: #selector(usernameTap(_:)), for: .touchUpInside)
        userView.addSubview(usernameButton)
        
        let showTimestamp = selectedSegmentIndex == 1 || parentVC != .feed
        
        if showTimestamp {

            let postTimestamp = post.actualTimestamp == nil ? post.timestamp : post.actualTimestamp
            
            timestamp = UILabel(frame: CGRect(x: username.frame.maxX + 8, y: 7, width: 150, height: 16))
            timestamp.font = UIFont(name: "SFCamera-Regular", size: 12.5)
            timestamp.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            timestamp.text = parentVC == .feed ? CLLocation(latitude: post.postLat, longitude: post.postLong).distance(from: currentLocation).getLocationString() : getDateTimestamp(postTime: postTimestamp!)
            timestamp.sizeToFit()
            userView.addSubview(timestamp)
        }
            
        if post.posterID == self.uid {
            let editX = showTimestamp ? timestamp.frame.maxX : username.frame.maxX + 2
            editButton = UIButton(frame: CGRect(x: editX, y: 0.5, width: 27, height: 27))
            editButton.setImage(UIImage(named: "EditPost"), for: .normal)
            editButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            editButton.addTarget(self, action: #selector(pencilTapped(_:)), for: .touchUpInside)
            userView.addSubview(editButton)
        }
        
        let liked = post.likers.contains(uid)
        let likeImage = liked ? UIImage(named: "UpArrowFilled") : UIImage(named: "UpArrow")
        
        commentButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 112, y: 0, width: 29.5, height: 29.5))
        commentButton.setImage(UIImage(named: "CommentIcon"), for: .normal)
        commentButton.contentMode = .scaleAspectFill
        commentButton.imageEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        commentButton.addTarget(self, action: #selector(commentsTap(_:)), for: .touchUpInside)
        userView.addSubview(commentButton)
        
        numComments = UILabel(frame: CGRect(x: commentButton.frame.maxX + 0.5, y: 6.5, width: 30, height: 15))
        let commentCount = max(post.commentList.count - 1, 0)
        numComments.text = String(commentCount)
        numComments.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
        numComments.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        numComments.textAlignment = .center
        numComments.sizeToFit()
        userView.addSubview(numComments)
        
        likeButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 54, y: 0, width: 29.5, height: 29.5))
        liked ? likeButton.addTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside) : likeButton.addTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        likeButton.setImage(likeImage, for: .normal)
        likeButton.contentMode = .scaleAspectFill
        likeButton.imageEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        userView.addSubview(likeButton)
        
        numLikes = UILabel(frame: CGRect(x: likeButton.frame.maxX + 0.5, y: 6.5, width: 30, height: 15))
        numLikes.text = String(post.likers.count)
        numLikes.font = UIFont(name: "SFCamera-Semibold", size: 12)
        numLikes.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00)
        numLikes.textAlignment = .center
        numLikes.sizeToFit()
        userView.addSubview(numLikes)
        
        postCaption = UILabel(frame: CGRect(x: 15.5, y: userView.frame.maxY + 8, width: UIScreen.main.bounds.width - 31, height: captionHeight + 0.5))
        postCaption.text = post.caption
        postCaption.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        postCaption.font = UIFont(name: "SFCamera-Regular", size: 13)
        
        let numberOfLines = overflow ? 2 : 0
        postCaption.numberOfLines = numberOfLines
        postCaption.lineBreakMode = overflow ? .byClipping : .byWordWrapping
        postCaption.isUserInteractionEnabled = true
        
        postCaption.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap(_:))))
        
        /// adding links for tagged users
        if !(post.taggedUsers?.isEmpty ?? true) {
            
            let attString = self.getAttString(caption: post.caption, taggedFriends: post.taggedUsers!)
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
    }
    
    func finishImageSetUp(images: [UIImage]) {
                
        resetImageInfo()
        var frameIndexes = post.frameIndexes ?? []
        if post.imageURLs.count == 0 { return }
        if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }
        post.frameIndexes = frameIndexes

        if images.isEmpty { return }
        let animationImages = getGifImages(selectedImages: images, frameIndexes: frameIndexes)
        let isGif = !animationImages.isEmpty
        
        post.postImage = images
        
        guard let currentImage = images[safe: frameIndexes[post.selectedImageIndex]] else { return }
        if !isGif { postImage.image = currentImage }

        let im = currentImage
        let aspect = im.size.height / im.size.width
        let trueHeight = aspect * UIScreen.main.bounds.width
        
        let overflowBound = screenSize == 2 ? cellHeight - tabBarHeight - 116 : cellHeight - tabBarHeight - 92 /// clipping standards by ~20 px for iphone8, 3px for X

        let standardSize = UIScreen.main.bounds.width * 1.333
        let aliveSize = UIScreen.main.bounds.width * 1.78
        var minY: CGFloat = 0

        /// max height is view size, minHeight is overflow boundary
        let maxHeight = min(aliveSize, trueHeight)
        let minHeight = max(maxHeight, standardSize)
        var adjustedHeight = minHeight
        
        /// height adjustment so that image is either completely full screen or at the overflow bound. Or if multiple images, constrain to bounds for smooth swiping
        
        if (adjustedHeight < standardSize + 20) || frameIndexes.count > 1 {
            adjustedHeight = standardSize
            minY = screenSize == 0 ? 0 : 64
            if adjustedHeight + minY > overflowBound { adjustedHeight = overflowBound - minY } /// crop for small screens
        
        } else {
            adjustedHeight = min(aliveSize, cellHeight - tabBarHeight + 20)
            minY = 0
        }

        imageY = minY
        print("animation counter", animationCounter)

        if isGif {
            postImage.animationImages = animationImages
            ///there may be a rare case where there is a single post of a 5 frame alive. but i wasnt sure which posts 
            animationImages.count == 5 && frameIndexes.count == 1 ? postImage.animate5FrameAlive(directionUp: true, counter: animationCounter) : postImage.animateGIF(directionUp: true, counter: animationCounter, frames: animationImages.count, alive: post.gif ?? false)  /// use old animation for 5 frame alives
        }
        
        postImage.frame = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: adjustedHeight)
        postImage.contentMode = aspect > 0.9 ? .scaleAspectFill : .scaleAspectFit
        postImage.tag = 16
        postImage.enableZoom()
    
        // add top mask to show title if title overlaps image
        if minY == 0 && post.spotID != ""  { postImage.addTopMask() }
        if adjustedHeight > standardSize { postImage.addBottomMask() }

        if postImage != nil { bringSubviewToFront(postImage) }

        postImageNext = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: adjustedHeight))
        postImageNext.clipsToBounds = true
        let nImage = post.selectedImageIndex < frameIndexes.count - 1 ?  images[frameIndexes[post.selectedImageIndex + 1]] : UIImage()
        let nAspect = nImage.size.height / nImage.size.width > 0.9
        postImageNext.contentMode = nAspect ? .scaleAspectFill : .scaleAspectFit
        postImageNext.image = nImage
        addSubview(postImageNext)
        if minY == 0 && post.spotID != "" { postImageNext.addTopMask() }
        
        postImagePrevious = UIImageView(frame: CGRect(x: -UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: adjustedHeight))
        postImagePrevious.clipsToBounds = true
        let pImage = post.selectedImageIndex > 0 ? images[frameIndexes[post.selectedImageIndex - 1]] : UIImage()
        let pAspect = pImage.size.height / pImage.size.width > 0.9
        postImagePrevious.contentMode = pAspect ? .scaleAspectFill : .scaleAspectFit
        postImagePrevious.image = pImage
        addSubview(postImagePrevious)
        if minY == 0 && post.spotID != "" { postImagePrevious.addTopMask() }
                
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
        tap.numberOfTapsRequired = 2
        postImage.addGestureRecognizer(tap)
        
        if frameIndexes.count > 1 {
            
            swipe = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
            postImage.addGestureRecognizer(swipe)
                        
            dotView = UIView(frame: CGRect(x: 0, y: overflowBound - 19, width: UIScreen.main.bounds.width, height: 10))
            dotView.backgroundColor = nil
            addSubview(dotView)
            
            var i = 1.0
            
            /// 1/2 of size of dot + the distance between that half and the next dot 
            var xOffset = CGFloat(6 + (Double(frameIndexes.count - 1) * 7.5))
            while i <= Double(frameIndexes.count) {
                
                let view = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - xOffset, y: 0, width: 12, height: 12))
                view.layer.cornerRadius = 6
                
                if i == Double(post.selectedImageIndex + 1) {
                    view.image = UIImage(named: "ElipsesFilled")
                } else {
                    view.image = UIImage(named: "ElipsesUnfilled")
                }
                
                view.contentMode = .scaleAspectFit
                dotView.addSubview(view)
                
                i = i + 1.0
                xOffset = xOffset - 15
            }
        }
        
        /// bring subviews and tap areas above masks
        if topView != nil { bringSubviewToFront(topView) }
        if tapButton != nil { bringSubviewToFront(tapButton) }
        if userView != nil { bringSubviewToFront(userView) }
        if postCaption != nil { bringSubviewToFront(postCaption) }
    }
    
    func resetTextInfo() {
        /// reset for fields that are set before image fetch
        if targetIcon != nil { targetIcon.image = UIImage() }
        if spotNameLabel != nil { spotNameLabel.text = "" }
        if cityLabel != nil { cityLabel.text = "" }
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
        if timestamp != nil { timestamp.text = "" }
        if editButton != nil { editButton.setImage(UIImage(), for: .normal) }
        if commentButton != nil { commentButton.setImage(UIImage(), for: .normal) }
        if numComments != nil { numComments.text = "" }
        if likeButton != nil { likeButton.setImage(UIImage(), for: .normal) }
        if numLikes != nil { numLikes.text = "" }
        if postCaption != nil { postCaption.text = "" }
        if postImage != nil { postImage.image = UIImage(); postImage.removeFromSuperview(); postImage.animationImages?.removeAll() }
    }
    
    func resetImageInfo() {
        /// reset for fields that are set after image fetch (right now just called on cell init)
        if bottomMask != nil { bottomMask.removeFromSuperview() }
        if postImageNext != nil { postImageNext.image = UIImage() }
        if postImagePrevious != nil { postImagePrevious.image = UIImage() }
        if notFriendsView != nil { notFriendsView.removeFromSuperview() }
        if addFriendButton != nil { addFriendButton.removeFromSuperview() }
        
        if editView != nil { editView.removeFromSuperview(); editView = nil }
        if editPostView != nil { editPostView.removeFromSuperview(); editPostView = nil }
       
        /// remove top mask
        if postImage != nil { for sub in postImage.subviews { sub.removeFromSuperview() } }
        if postImagePrevious != nil { for sub in postImagePrevious.subviews { sub.removeFromSuperview()} }
        if postImageNext != nil { for sub in postImageNext.subviews { sub.removeFromSuperview()} }
        /// remove dots within dotview
        if dotView != nil {
            for dot in dotView.subviews { dot.removeFromSuperview() }
            dotView.removeFromSuperview()
        }
        
        if postMask != nil {
            for sub in postMask.subviews { sub.removeFromSuperview() }
            postMask.removeFromSuperview()
        }
    }
    
    override func prepareForReuse() {
        
        super.prepareForReuse()

        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
        if profilePic != nil { profilePic.removeFromSuperview(); profilePic.sd_cancelCurrentImageLoad() }
        if postImage != nil { postImage.removeFromSuperview(); postImage.animationImages?.removeAll(); postImage = nil }
    }
        
    @objc func spotNameTap(_ sender: UIButton) {
        /// get spot level info then open spot page
        
        Mixpanel.mainInstance().track(event: "PostSpotNameTap")
        
        if parentVC == .spot { exitPosts(); return }
        
        sender.isEnabled = false
        if let postVC = self.viewContainingController() as? PostViewController {
                        
            if post.createdBy != self.uid && post.spotPrivacy == "friends" &&  !postVC.mapVC.friendIDs.contains(post.createdBy ?? "") {
                self.addNotFriends()
                sender.isEnabled = true
                return
            }
            postVC.openSpotPage(edit: false)
        }
    }
    
    @objc func pencilTapped(_ sender: UIButton) {
        addEditOverview()
    }
    
    
    @objc func usernameTap(_ sender: UIButton) {
        if post.userInfo == nil { return }
        openProfile(user: post.userInfo)
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
        if swipe != nil { self.postImage.removeGestureRecognizer(swipe) }
    }
    
    func getCaptionHeight(caption: String) -> CGFloat {
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 31, height: 20))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
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
                    if let friend = postVC.mapVC.friendsList.first(where: {$0.username == r.username}) {
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
    
    @objc func imageTapped(_ sender: UITapGestureRecognizer) {
        if post.likers.contains(self.uid) { return }
        likePost()
    }
    
    @objc func likePost(_ sender: UIButton) {
        likePost()
    }
    
    func likePost() {
        likeButton.setImage(UIImage(named: "UpArrowFilled"), for: .normal)
        
        post.likers.append(self.uid)
        numLikes.text = String(post.likers.count)
        
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": self.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostIndexChange"), object: nil, userInfo: infoPass)
        DispatchQueue.global(qos: .utility).async { self.likePostDB(post: self.post) }
    }
    
    @objc func unlikePost(_ sender: UIButton) {
        likeButton.setImage(UIImage(named: "UpArrow"), for: .normal)
        
        post.likers.removeAll(where: {$0 == self.uid})
        numLikes.text = String(post.likers.count)
        //update main data source -- send notification to map, update comments
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": self.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostIndexChange"), object: nil, userInfo: infoPass)
        DispatchQueue.global(qos: .utility).async { self.unlikePostDB(post: self.post) }
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
            let finalY = closedToStart ? parentVC == .feed ? postVC.mapVC.tabBarOpenY : postVC.mapVC.tabBarClosedY : UIScreen.main.bounds.height - closedY
            let currentY = translation + prePanY
            let multiplier = (finalY! - currentY) / (finalY! - prePanY)
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
            
            /// gradually adjust feed seg alpha on drawer offset
            if let feedVC = postVC.parent as? FeedViewController {
                feedVC.mapVC.feedMask.alpha = 1 - activeMultiplier
                feedVC.feedSegBlur.alpha = 1 - activeMultiplier
                feedVC.feedSeg.alpha = 1 - activeMultiplier
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
        if isZooming { return }
        
        let offsetY = postVC.mapVC.customTabBar.tabBar.isHidden ? postVC.mapVC.tabBarClosedY : postVC.mapVC.tabBarOpenY
        if Int(postVC.mapVC.customTabBar.view.frame.minY) != Int(offsetY ?? 0.0) {
            /// offset drawer if its already been offset some
            offsetDrawer(gesture: gesture)
            
        } else if abs(translation.y) > abs(translation.x) {
            if postImage.frame.maxX > UIScreen.main.bounds.width || postImage.frame.minX < 0 {
                ///stay with image swipe if image swipe already began
                imageSwipe(gesture: gesture)
            } else {
                verticalSwipe(gesture: gesture)
            }
            
        } else {
            if let tableView = self.superview as? UITableView {
                if tableView.contentOffset.y - originalOffset != 0 {
                    ///stay with vertical swipe if image swipe already began
                    verticalSwipe(gesture)
                } else {
                    imageSwipe(gesture: gesture)
                }
            }
        }
    }
    
    func resetImageFrames() {

        /// reset imageview to starting postition
        let minY = postImage.frame.minY
        let frameN1 = CGRect(x: -UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
        let frame0 = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
        let frame1 = CGRect(x: UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
        
        if postImageNext != nil { postImageNext.frame = frame1 }
        if postImagePrevious != nil { postImagePrevious.frame = frameN1 }
        postImage.frame = frame0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let infoPass = ["post": self.post as Any, "id": self.vcid as Any] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostImageChange"), object: nil, userInfo: infoPass)
        }
    }
    
    func imageSwipe(gesture: UIPanGestureRecognizer) {
        /// cancel gesture if zooming
        guard let postVC = self.viewContainingController() as? PostViewController else { return }

        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
        
        let minY = postImage.frame.minY
        let frameN1 = CGRect(x: -UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
        let frame0 = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
        let frame1 = CGRect(x: UIScreen.main.bounds.width, y: minY, width: UIScreen.main.bounds.width, height: postImage.frame.height)
        
        if (post.selectedImageIndex == 0 && direction.x > 0) || postVC.view.frame.minX > 0 {
            if parentVC != .feed && postImage.frame.minX == 0 { swipeToExit(gesture: gesture); return }
        }
        
        if offScreen { resetPostFrame(); return }

        switch gesture.state {
            
        case .changed:
            
            //translate to follow finger tracking
            postImage.transform = CGAffineTransform(translationX: translation.x, y: 0)
            postImageNext.transform = CGAffineTransform(translationX: translation.x, y: 0)
            postImagePrevious.transform = CGAffineTransform(translationX: translation.x, y: 0)
            
        case .ended, .cancelled:
            
            if direction.x < 0 {
                if postImage.frame.maxX + direction.x < UIScreen.main.bounds.width/2 && post.selectedImageIndex < (post.frameIndexes?.count ?? 0) - 1 {
                    //animate to next image
                    UIView.animate(withDuration: 0.2) {
                        self.postImageNext.frame = frame0
                        self.postImage.frame = frameN1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.post.selectedImageIndex += 1
                        let infoPass = ["post": self.post as Any, "id": self.vcid as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostImageChange"), object: nil, userInfo: infoPass)
                        return
                    }
                    
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.resetImageFrames() }
                }
                
            } else {
                
                if postImage.frame.minX + direction.x > UIScreen.main.bounds.width/2 && post.selectedImageIndex > 0 {
                    //animate to previous image
                    UIView.animate(withDuration: 0.2) {
                        self.postImagePrevious.frame = frame0
                        self.postImage.frame = frame1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.post.selectedImageIndex -= 1
                        let infoPass = ["post": self.post as Any, "id": self.vcid as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostImageChange"), object: nil, userInfo: infoPass)
                        return
                    }
                    
                } else {
                    //return to original state
                    UIView.animate(withDuration: 0.2) { self.resetImageFrames() }
                }
            }
        default:
            return
        }
    }
    
    @objc func verticalSwipe(_ gesture: UIPanGestureRecognizer) {
        verticalSwipe(gesture: gesture)
    }
    
    func resetCellFrame() {

        if let tableView = self.superview as? UITableView {
            DispatchQueue.main.async { UIView.animate(withDuration: 0.2) {
                tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
                }
            }
        }
    }
    
    func verticalSwipe(gesture: UIPanGestureRecognizer) {
        
        let direction = gesture.velocity(in: self)
        let translation = gesture.translation(in: self)
            
        /// offset drawer if touch occurs in topview
        if beginningSwipe != 0 && beginningSwipe < 80 { offsetDrawer(gesture: gesture); return }
        if isZooming { return }
        
        guard let postVC = viewContainingController() as? PostViewController else { return }
        let offsetY = postVC.mapVC.customTabBar.tabBar.isHidden ? postVC.mapVC.tabBarClosedY : postVC.mapVC.tabBarOpenY
        if Int(postVC.mapVC.customTabBar.view.frame.minY) != Int(offsetY ?? 0) {
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
                if parentVC != .feed && postImage.frame.minX == 0 { swipeToExit(gesture: gesture) }
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
                        
                        Mixpanel.mainInstance().track(event: "PostPageNextPost", properties: ["postIndex": self.selectedPostIndex])
                        let infoPass = ["index": self.selectedPostIndex as Any, "id": vcid as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostIndexChange"), object: nil, userInfo: infoPass)
                        
                        // send notification to map to change post annotation location
                        let mapPass = ["selectedPost": self.selectedPostIndex as Any, "firstOpen": false, "parentVC": parentVC as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                        removeGestures()
                        return
                        
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
                        let infoPass = ["index": self.selectedPostIndex as Any, "id": vcid as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostIndexChange"), object: nil, userInfo: infoPass)
                        /// send notification to map to change post annotation location
                        let mapPass = ["selectedPost": self.selectedPostIndex as Any, "firstOpen": false, "parentVC": parentVC as Any] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                        removeGestures()
                        return
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
        return gestureRecognizer.view?.tag == 16 && otherGestureRecognizer.view?.tag == 16 /// only user for postImage zoom / swipe
    }
    
    func getGifImages(selectedImages: [UIImage], frameIndexes: [Int]) -> [UIImage] {

        let selectedFrame = frameIndexes[post.selectedImageIndex]
        if frameIndexes.count == 1 {
            return selectedImages.count > 1 ? selectedImages : []
        } else if frameIndexes.count - 1 == post.selectedImageIndex {
            return selectedImages[selectedFrame] != selectedImages.last ? selectedImages.suffix(selectedImages.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[post.selectedImageIndex + 1]
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
        
        if let mapVC = self.parentContainerViewController() as? MapViewController {
            addFriend(senderProfile: mapVC.userInfo, receiverID: self.noAccessFriend.id!)
        }
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
        
        let editPost = UIButton(frame: CGRect(x: 41, y: 47, width: 116, height: 35))
        editPost.setImage(UIImage(named: "EditPostButton"), for: .normal)
        editPost.backgroundColor = nil
        editPost.addTarget(self, action: #selector(editPostTapped(_:)), for: .touchUpInside)
        editPost.imageView?.contentMode = .scaleAspectFit
        editView.addSubview(editPost)
        
        ///expand the edit view frame to include a delete button if this post can be deleted
        editView.frame = CGRect(x: editView.frame.minX, y: editView.frame.minY, width: editView.frame.width, height: 171)
        
        let deleteButton = UIButton(frame: CGRect(x: 46, y: 100, width: 112, height: 29))
        deleteButton.setImage(UIImage(named: "DeletePostButton"), for: UIControl.State.normal)
        deleteButton.backgroundColor = nil
        deleteButton.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
        editView.addSubview(deleteButton)
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
        
        let postCopy = deletePost
        
        if let postVC = self.viewContainingController() as? PostViewController {

            /// delete funcs
            DispatchQueue.global(qos: .userInitiated).async {
                
                if spotDelete {
                    
                    let spotID = postCopy.spotID!
                    postVC.postDelete(postsList: [postCopy], spotID: "")
                    postVC.spotDelete(spotID: spotID)
                    postVC.userDelete(spot: spot)
                    
                    postVC.mapVC.deletedSpotIDs.append(spotID)
                    
                    DispatchQueue.main.async {
                        let infoPass: [String: Any] = ["spotID": spotID as Any]
                        NotificationCenter.default.post(name: Notification.Name("DeleteSpot"), object: nil, userInfo: infoPass)
                    }
                    
                    if let spotVC = postVC.parent as? SpotViewController {
                        
                        DispatchQueue.main.async {
                            postVC.willMove(toParent: nil)
                            postVC.view.removeFromSuperview()
                            postVC.removeFromParent()
                            spotVC.removeSpotPage(delete: true)
                        }
                    }
                    
                } else {
                    /// pass spotID through to delete post info from spot page when not deleting the spot
                    postVC.postDelete(postsList: [postCopy], spotID: postCopy.spotID ?? "")

                    /// remove post from this users spotsList document or remove from users spotsList
                    postVC.checkUserSpotsOnPostDelete(spotID: postCopy.spotID!, deletedID: deletePost.id!)
                    
                    /// spot score incremented in delete spot method otherwise
                    self.incrementSpotScore(user: self.uid, increment: -3)
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
        
        self.backgroundColor = UIColor(named: "SpotBlack")
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

extension UIImageView {
    
    func removeTopMask() {
        if let sub = subviews.first(where: {$0.tag == 7}) {
            sub.removeFromSuperview()
        }
    }
    
    func addTopMask() {
        let topMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 118))
        topMask.backgroundColor = nil
        topMask.tag = 7
        let layer0 = CAGradientLayer()
        layer0.frame = topMask.bounds
        layer0.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.04).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.15).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.32).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.45).cgColor
          ]
        layer0.locations = [0, 0.23, 0.49, 0.76, 1]
        layer0.startPoint = CGPoint(x: 0.5, y: 1.0)
        layer0.endPoint = CGPoint(x: 0.5, y: 0)
        topMask.layer.addSublayer(layer0)
        addSubview(topMask)
    }
    
    func addBottomMask() {
        let bottomMask = UIView(frame: CGRect(x: 0, y: bounds.height - 140, width: UIScreen.main.bounds.width, height: 140))
        bottomMask.backgroundColor = nil
        let layer0 = CAGradientLayer()
        layer0.frame = bottomMask.bounds
        layer0.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.01).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.06).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.23).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.85).cgColor
        ]
        layer0.locations = [0, 0.11, 0.24, 0.43, 0.65, 1]
        layer0.startPoint = CGPoint(x: 0.5, y: 0)
        layer0.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomMask.layer.addSublayer(layer0)
        addSubview(bottomMask)
    }
}

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
