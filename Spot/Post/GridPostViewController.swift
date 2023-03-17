//
//  GridPostViewController.swift
//  Spot
//
//  Created by Kenny Barone on 3/16/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

protocol PostControllerDelegate: AnyObject {
    func indexChanged(rowsRemaining: Int)
}

class GridPostViewController: UIViewController {
    var parentVC: PostParent
    var postsList: [MapPost]
    weak var delegate: PostControllerDelegate?
    var openComments = false
    private var selectedPostIndex: Int = 0 {
        didSet {
            delegate?.indexChanged(rowsRemaining: postsList.count - selectedPostIndex)
        }
    }

    lazy var postService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    lazy var mapService: MapServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapsService)
        return service
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIScreen.main.bounds.height, right: 0)
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.scrollsToTop = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.shouldIgnoreContentInsetAdjustment = true
        // inset to show button view
        tableView.register(MapPostImageCell.self, forCellReuseIdentifier: MapPostImageCell.reuseID)
        tableView.register(MapPostVideoCell.self, forCellReuseIdentifier: MapPostVideoCell.reuseID)
        tableView.sectionHeaderTopPadding = 0.0
        tableView.delegate = self
        tableView.dataSource = self

        return tableView
    }()

    var titleView: GridPostTitleView
    private lazy var addMapConfirmationView = AddMapConfirmationView()

    var mapData: CustomMap?

    var rowHeight: CGFloat {
        return tableView.bounds.height - 0.01
    }

    var currentRowContentOffset: CGFloat {
        return rowHeight * CGFloat(selectedPostIndex)
    }

    var maxRowContentOffset: CGFloat {
        return rowHeight * CGFloat(postsList.count - 1)
    }

    init(parentVC: PostParent, postsList: [MapPost], delegate: PostControllerDelegate?, title: String?, subtitle: String?) {
        self.parentVC = parentVC
        self.postsList = postsList
        self.delegate = delegate
        titleView = GridPostTitleView(title: title ?? "", subtitle: subtitle ?? "")
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addMapConfirmationView.isHidden = true
        view.addSubview(addMapConfirmationView)
        addMapConfirmationView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(34)
            $0.height.equalTo(57)
            $0.bottom.equalTo(-23)
        }

        if openComments {
            openComments(row: selectedPostIndex, animated: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    private func setUpNavBar() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()

        navigationItem.titleView = titleView

        if parentVC == .Map || parentVC == .Explore {
            if !(mapData?.likers.contains(where: { $0 == UserDataModel.shared.uid }) ?? true) {
                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    image: UIImage(named: "AddPlusButton")?.withRenderingMode(.alwaysOriginal),
                    style: .plain,
                    target: self,
                    action: #selector(addMapTap))
            } else {
                navigationItem.rightBarButtonItem = UIBarButtonItem()
            }
        }
    }

    private func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyImageChange(_:)), name: NSNotification.Name("PostImageChange"), object: nil)
    }

    @objc func notifyImageChange(_ notification: NSNotification) {
        if let index = notification.userInfo?.values.first as? Int {
            postsList[selectedPostIndex].selectedImageIndex = index
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GridPostViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postsList.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return max(0.01, tableView.bounds.height - 0.01)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let post = postsList[indexPath.row]
        if let videoURLString = post.videoURL,
           let videoURL = URL(string: videoURLString),
           let videoCell = tableView.dequeueReusableCell(withIdentifier: MapPostVideoCell.reuseID, for: indexPath) as? MapPostVideoCell {
            videoCell.configure(post: post, url: videoURL)
            videoCell.delegate = self
            return videoCell

        } else if let imageCell = tableView.dequeueReusableCell(withIdentifier: MapPostImageCell.reuseID, for: indexPath) as? MapPostImageCell {
            imageCell.configure(post: post, row: indexPath.row)
            imageCell.delegate = self
            return imageCell
        } else {
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MapPostImageCell {
            cell.animateLocation()
        } else if let cell = cell as? MapPostVideoCell {
            cell.playerView.player?.play()
            cell.animateLocation()
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let videoCell = cell as? MapPostVideoCell else {
            return
        }
        videoCell.playerView.player?.pause()
    }
}

extension GridPostViewController: ContentViewerDelegate {
    func tapToNextPost() {
        if selectedPostIndex < postsList.count - 1 {
            tapToSelectedRow(increment: 1)
        }
    }

    func tapToPreviousPost() {
        if selectedPostIndex > 0 {
            tapToSelectedRow(increment: -1)
        }
    }

    func tapToSelectedRow(increment: Int = 0) {
        tableView.scrollToRow(at: IndexPath(row: selectedPostIndex + increment, section: 0), at: .top, animated: true)
    }

    func likePost(postID: String) {
        HapticGenerator.shared.play(.light)

        if postsList[selectedPostIndex].likers.firstIndex(where: { $0 == UserDataModel.shared.uid }) != nil {
            Mixpanel.mainInstance().track(event: "PostPageUnlikePost")
            unlikePost()
        } else {
            Mixpanel.mainInstance().track(event: "PostPageLikePost")
            likePost()
        }

        // TODO: need smoother solution for like
        DispatchQueue.main.async { self.tableView.reloadRows(at: [IndexPath(row: self.selectedPostIndex, section: 0)], with: .automatic) }
    }

    func openPostComments() {
        openComments(row: selectedPostIndex, animated: true)
    }

    func openPostActionSheet() {
        Mixpanel.mainInstance().track(event: "PostPageElipsesTap")
     //   addActionSheet()
    }

    func getSelectedPostIndex() -> Int {
        return selectedPostIndex
    }

    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user)
        DispatchQueue.main.async { self.navigationController?.pushViewController(profileVC, animated: true) }
    }

    func openMap(mapID: String, mapName: String) {
        var map = CustomMap(
            founderID: "",
            imageURL: "",
            likers: [],
            mapName: mapName,
            memberIDs: [],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            secret: false,
            spotIDs: []
        )

        map.id = mapID
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [])
        navigationController?.pushViewController(customMapVC, animated: true)
    }

    func openSpot(post: MapPost) {
        let spotVC = SpotPageController(mapPost: post)
        navigationController?.pushViewController(spotVC, animated: true)
    }

    func openComments(row: Int, animated: Bool) {
        if presentedViewController != nil { return }
        Mixpanel.mainInstance().track(event: "PostOpenComments")
        let post = postsList[row]
        let commentsVC = CommentsController(commentsList: post.commentList, post: post)
        commentsVC.delegate = self
        present(commentsVC, animated: animated, completion: nil)
    }

    private func likePost() {
        // TODO: update parent
        postsList[selectedPostIndex].likers.append(UserDataModel.shared.uid)
        let post = postsList[selectedPostIndex]
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.postService?.likePostDB(post: post)
        }
    }

    private func unlikePost() {
        // TODO: update parent
        postsList[selectedPostIndex].likers.removeAll(where: { $0 == UserDataModel.shared.uid })
        let post = postsList[selectedPostIndex]
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.postService?.unlikePostDB(post: post)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let velocity = scrollView.panGestureRecognizer.velocity(in: view)
        let translation = scrollView.panGestureRecognizer.translation(in: view)
        let composite = translation.y + velocity.y / 4

        let rowHeight = tableView.bounds.height
        if composite < -(rowHeight / 4) && selectedPostIndex < postsList.count - 1 {
            selectedPostIndex += 1
        } else if composite > rowHeight / 4 && selectedPostIndex != 0 {
            selectedPostIndex -= 1
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - 1), animated: true)
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y + 1), animated: true)
        scrollToSelectedRow(animated: true)
    }

    func scrollToSelectedRow(animated: Bool) {
        var duration: TimeInterval = 0.15
        if animated {
            let offset = abs(currentRowContentOffset - tableView.contentOffset.y)
            duration = max(TimeInterval(0.25 * offset / tableView.bounds.height), 0.15)
        }

        UIView.transition(with: tableView, duration: duration, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.tableView.setContentOffset(CGPoint(x: 0, y: CGFloat(self.currentRowContentOffset)), animated: false)
            self.tableView.layoutIfNeeded()

        }, completion: { [weak self] _ in
            if let cell = self?.tableView.cellForRow(at: IndexPath(row: self?.selectedPostIndex ?? 0, section: 0)) as? MapPostImageCell {
                cell.animateLocation()
            }
        })
    }

    @objc func addMapTap() {
        Mixpanel.mainInstance().track(event: "MapHeaderJoinTap")
        guard let map = mapData else { return }

        mapData?.likers.append(UserDataModel.shared.uid)
        if mapData?.communityMap ?? false { mapData?.memberIDs.append(UserDataModel.shared.uid) }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.mapService?.followMap(customMap: map) { _ in }
        }

        toggleAddMapView()
        setUpNavBar()

        guard let mapData = mapData else { return }
        NotificationCenter.default.post(Notification(name: Notification.Name("EditMap"), object: nil, userInfo: ["map": mapData as Any]))
    }

    private func toggleAddMapView() {
        addMapConfirmationView.isHidden = false
        addMapConfirmationView.alpha = 1.0
        UIView.animate(withDuration: 0.3, delay: 2.0, animations: { [weak self] in
            self?.addMapConfirmationView.alpha = 0.0
        }, completion: { [weak self] _ in
            self?.addMapConfirmationView.isHidden = true
            self?.addMapConfirmationView.alpha = 1.0
        })
    }
}

extension GridPostViewController: CommentsDelegate {
    func openProfileFromComments(user: UserProfile) {
        openProfile(user: user)
    }
}
