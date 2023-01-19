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
            // call on animation completion for open
            if sheetView == nil { mapController.drawerViewSet(open: false) }
        }
    }

    var selectedControllerIndex = 1
    var mapTapGesture: UITapGestureRecognizer?
    var mapPanGesture: UIPanGestureRecognizer?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mapTapGesture = UITapGestureRecognizer(target: self, action: #selector(mapTap))
        mapPanGesture = UIPanGestureRecognizer(target: self, action: #selector(mapPan(_:)))
        NotificationCenter.default.addObserver(self, selector: #selector(drawerViewOpen), name: NSNotification.Name("DrawerViewToTopComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(drawerViewClose), name: NSNotification.Name("DrawerViewDismissComplete"), object: nil)

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
        if let mapTapGesture { mapNavController.view.addGestureRecognizer(mapTapGesture) }
        if let mapPanGesture { mapNavController.view.addGestureRecognizer(mapPanGesture) }
        mapController.view.isUserInteractionEnabled = false
        if sideBarController.mapsLoaded { sideBarController.reloadTable() }

        makeSideBarOpenConstraints(offset: 0)
    }

    func closeSideBar() {
        Mixpanel.mainInstance().track(event: "MapCloseSideBar")
        if let mapTapGesture { mapNavController.view.removeGestureRecognizer(mapTapGesture) }
        if let mapPanGesture { mapNavController.view.removeGestureRecognizer(mapPanGesture) }
        mapController.view.isUserInteractionEnabled = true

        makeSideBarClosedConstraints()
    }

    func makeSideBarOpenConstraints(offset: CGFloat) {
        sideBarController.view.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(offset)
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-70 + offset)
        }

        mapNavController.view.snp.makeConstraints {
            $0.leading.equalTo(sideBarController.view.snp.trailing)
            $0.top.bottom.equalToSuperview()
            $0.width.equalToSuperview()
        }
    }

    func makeSideBarClosedConstraints() {
        mapNavController.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        sideBarController.view.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalTo(view.snp.leading)
            $0.leading.equalToSuperview().offset(-UIScreen.main.bounds.width + 70)
        }
    }

    @objc func drawerViewOpen() {
        if !(mapController.navigationController?.navigationBar.isHidden ?? false) {
            mapController.drawerViewSet(open: true)
        }
    }

    @objc func drawerViewClose() {
        mapController.drawerViewSet(open: false)
    }

    @objc func mapTap() {
        animateSideBar()
    }

    @objc func mapPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        switch gesture.state {
        case .began:
            mapTapGesture?.isEnabled = false
        case .changed:
            offsetSideBar(offset: translation.x)
        case .ended, .cancelled, .failed:
            mapTapGesture?.isEnabled = true
            finishPanGesture(translationX: translation.x, velocityX: velocity.x)

        default:
            return
        }
    }

    func offsetSideBar(offset: CGFloat) {
        mapNavController.view.snp.removeConstraints()
        sideBarController.view.snp.removeConstraints()
        makeSideBarOpenConstraints(offset: offset)
    }

    func finishPanGesture(translationX: CGFloat, velocityX: CGFloat) {
        mapNavController.view.snp.removeConstraints()
        sideBarController.view.snp.removeConstraints()
        if translationX + velocityX < -100 {
            closeSideBar()
        } else {
            openSideBar()
        }

        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
    }
}
