//
//  MapActionsExtension.swift
//  Spot
//
//  Created by Kenny Barone on 12/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension MapController {
    @objc func currentLocationTap() {
        Mixpanel.mainInstance().track(event: "MapCurrentLocationTap")
        addFriendsView.removeFromSuperview()
        animateToCurrentLocation()
    }

    @objc func inviteFriendsTap() {
        Mixpanel.mainInstance().track(event: "MapInviteFriendsTap")
        addFriendsView.removeFromSuperview()
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "Add me on sp0t 🌎🦦"] as [Any]

        DispatchQueue.main.async {
            let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
            self.present(activityView, animated: true)
            activityView.completionWithItemsHandler = { activityType, completed, _, _ in
                if completed {
                    Mixpanel.mainInstance().track(event: "MapInviteSent", properties: ["type": activityType?.rawValue ?? ""])
                } else {
                    Mixpanel.mainInstance().track(event: "MapInviteCancelled")
                }
            }
        }
    }

    @objc func addTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenAddTap")
        addFriendsView.removeFromSuperview()
        if navigationController?.viewControllers.contains(where: { $0 is AVCameraController }) ?? false {
            return
        }

        guard let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController
        else { return }

        let transition = AddButtonTransition()
        self.navigationController?.view.layer.add(transition, forKey: kCATransition)
        self.navigationController?.pushViewController(vc, animated: false)

    }

    @objc func profileTap() {
        homeScreenDelegate?.openProfile()
    }

    @objc func notificationsTap() {
        homeScreenDelegate?.openNotifications()
    }

    @objc func searchTap() {
        openFindFriends()
    }

    @objc func findFriendsTap() {
        openFindFriends()
    }

    func openFindFriends() {
        homeScreenDelegate?.openFindFriends()
    }

    func openPosts(posts: [MapPost]) {
        homeScreenDelegate?.openPosts(posts: posts)
    }

    func openSpot(spotID: String, spotName: String, mapID: String, mapName: String) {
        let emptyPost = MapPost(spotID: spotID, spotName: spotName, mapID: mapID, mapName: mapName)
        homeScreenDelegate?.openSpot(post: emptyPost)
    }

    func openExploreMaps(onboarding: Bool) {
        let fromValue: ExploreMapViewModel.OpenedFrom = onboarding ? .onBoarding : .mapController
        let viewController = ExploreMapViewController(viewModel: ExploreMapViewModel(serviceContainer: ServiceContainer.shared, from: fromValue))
        viewController.delegate = self
        self.navigationController?.pushViewController(viewController, animated: true)
    }

    func openNewMap() {
        if navigationController?.viewControllers.contains(where: { $0 is NewMapController }) ?? false {
            return
        }

        DispatchQueue.main.async { [weak self] in
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
                UploadPostModel.shared.createSharedInstance()
                vc.presentedModally = true
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func drawerViewSet(open: Bool) {
        // called when sheetView value is set on home screen controller
        DispatchQueue.main.async {
            self.toggleHomeAppearance(hidden: open)
          //  if !open { self.animateHomeAlphas() }
            self.navigationController?.setNavigationBarHidden(open, animated: false)
        }
    }

    func toggleHomeAppearance(hidden: Bool) {
        newPostsButton.setHidden(hidden: hidden)
        addButton.isHidden = hidden
        currentLocationButton.isHidden = hidden
        inviteFriendsButton.isHidden = hidden
        cityLabel.isHidden = hidden
        /// if hidden, remove annotations, else reset with selected annotations
        if hidden {
            addFriendsView.removeFromSuperview()
        } else {
            mapView.delegate = self
            mapView.spotMapDelegate = self
            // re-add map annotations only if they've been removed (custom map opened in drawer)
            if mapView.annotations.count < 2 {
                DispatchQueue.main.async { self.addMapAnnotations() }
            }
        }
    }

    func animateHomeAlphas() {
        navigationController?.navigationBar.alpha = 0.0
        addButton.alpha = 0.0
        newPostsButton.alpha = 0.0
        currentLocationButton.alpha = 0.0
        inviteFriendsButton.alpha = 0.0
        cityLabel.alpha = 0.0

        UIView.animate(withDuration: 0.15) {
            self.navigationController?.navigationBar.alpha = 1
            self.addButton.alpha = 1
            self.newPostsButton.alpha = 1
            self.currentLocationButton.alpha = 1
            self.inviteFriendsButton.alpha = 1
            self.cityLabel.alpha = 1
        }
    }

    @objc func hamburgerTap() {
        homeScreenDelegate?.animateSideBar()
    }
}
