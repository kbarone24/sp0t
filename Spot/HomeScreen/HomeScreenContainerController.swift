//
//  HomeScreenContainerController.swift
//  Spot
//
//  Created by Kenny Barone on 12/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol HomeScreenDelegate: AnyObject {
    func openFindFriends()
    func openNotifications()
    func openProfile()
    func openSpot(post: MapPost)
    func openPosts(posts: [MapPost])
    func openMap(map: CustomMap)
    func openNewMap()
    func drawerOpen() -> Bool
    func animateSideBar()
}

class HomeScreenContainerController: UIViewController {
    lazy var mapController = MapController()
    lazy var mapNavController = MapNavigationController(rootViewController: mapController)
    lazy var sideBarController = MapSideBarController()
    var sheetView: DrawerView? {
        didSet {
            mapController.drawerViewSet(open: sheetView != nil)
        }
    }

    var selectedControllerIndex = 1
    var mapGesture: UITapGestureRecognizer?

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mapGesture = UITapGestureRecognizer(target: self, action: #selector(mapTap))
        mapController.homeScreenDelegate = self

        addChild(mapNavController)
        view.addSubview(mapNavController.view)
        mapNavController.didMove(toParent: self)
        mapNavController.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        sideBarController.homeScreenDelegate = self
        addChild(sideBarController)
        view.addSubview(sideBarController.view)
        sideBarController.didMove(toParent: self)
        sideBarController.view.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalTo(view.snp.leading)
            $0.width.equalToSuperview().inset(70)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension HomeScreenContainerController: HomeScreenDelegate {
    func openFindFriends() {
        if sheetView != nil { return }
        let findFriendsController = FindFriendsController()
        sheetView = DrawerView(present: findFriendsController, detentsInAscending: [.top, .middle, .bottom]) { [weak self] in
            self?.sheetView = nil
        }
        findFriendsController.containerDrawerView = sheetView
    }

    func openNotifications() {
        if sheetView != nil { return }
        let notificationsController = NotificationsController()
        sheetView = DrawerView(present: notificationsController, detentsInAscending: [.bottom, .middle, .top], closeAction: { [weak self] in
            self?.sheetView = nil
        })
        notificationsController.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openProfile() {
        if sheetView != nil { return }
        let profileVC = ProfileViewController(userProfile: nil)
        sheetView = DrawerView(present: profileVC, detentsInAscending: [.bottom, .middle, .top], closeAction: { [weak self] in
            self?.sheetView = nil
        })
        profileVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openSpot(post: MapPost) {
        if sheetView != nil { return }
        let spotVC = SpotPageController(mapPost: post, presentedDrawerView: nil)
        sheetView = DrawerView(present: spotVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }
        spotVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openPosts(posts: [MapPost]) {
        if sheetView != nil { return }
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = posts
        sheetView = DrawerView(present: postVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }
        postVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openMap(map: CustomMap) {
        if sheetView != nil { return }
        if selectedControllerIndex == 0 { animateSideBar() }

        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [], presentedDrawerView: nil, mapType: .customMap)
        sheetView = DrawerView(present: customMapVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }

        customMapVC.containerDrawerView = sheetView
        sheetView?.present(to: .middle)
    }

    func openNewMap() {
        if selectedControllerIndex == 0 { animateSideBar() }
        mapController.openNewMap()
    }

    func drawerOpen() -> Bool {
        return sheetView != nil
    }

    func animateSideBar() {
        mapNavController.view.snp.removeConstraints()
        sideBarController.view.snp.removeConstraints()

        selectedControllerIndex = selectedControllerIndex == 0 ? 1 : 0
        switch selectedControllerIndex {
        case 0: openSideBar()
        case 1: closeSideBar()
        default: return
        }

        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
    }
}

extension HomeScreenContainerController {
    func uploadMapReset() {
        mapController.uploadMapReset()
    }

    func openSideBar() {
        if let mapGesture { mapNavController.view.addGestureRecognizer(mapGesture) }
        mapController.view.isUserInteractionEnabled = false
        if sideBarController.mapsLoaded { sideBarController.reloadTable() }

        sideBarController.view.snp.updateConstraints {
            $0.leading.equalToSuperview()
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalToSuperview().inset(70)
        }

        mapNavController.view.snp.updateConstraints {
            $0.leading.equalTo(sideBarController.view.snp.trailing)
            $0.top.bottom.equalToSuperview()
            $0.width.equalToSuperview()
        }
    }

    func closeSideBar() {
        if let mapGesture { mapNavController.view.removeGestureRecognizer(mapGesture) }
        mapController.view.isUserInteractionEnabled = true

        mapNavController.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        sideBarController.view.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalTo(view.snp.leading)
            $0.width.equalToSuperview().inset(70)
        }
    }

    @objc func mapTap() {
        animateSideBar()
    }
}
