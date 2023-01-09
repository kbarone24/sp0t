//
//  HomeScreenContainerController.swift
//  Spot
//
//  Created by Kenny Barone on 12/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

protocol HomeScreenDelegate: AnyObject {
    func openFindFriends()
    func openNotifications()
    func openProfile()
    func openSpot(post: MapPost)
    func openPosts(posts: [MapPost])
    func openMap(map: CustomMap)
    func openNewMap()
    func openExploreMaps()
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

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

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
            $0.leading.equalToSuperview().offset(-UIScreen.main.bounds.width + 70)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension HomeScreenContainerController {
    func uploadMapReset() {
        mapController.uploadMapReset()
    }

    func openSideBar() {
        Mixpanel.mainInstance().track(event: "MapOpenSideBar")
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
        Mixpanel.mainInstance().track(event: "MapCloseSideBar")
        if let mapGesture { mapNavController.view.removeGestureRecognizer(mapGesture) }
        mapController.view.isUserInteractionEnabled = true

        mapNavController.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        sideBarController.view.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalTo(view.snp.leading)
            $0.leading.equalToSuperview().offset(-UIScreen.main.bounds.width + 70)
        }
    }

    @objc func mapTap() {
        animateSideBar()
    }
}
