//
//  HomeScreenController.swift
//  Spot
//
//  Created by Kenny Barone on 7/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Combine

class HomeScreenController: UIViewController {
    private let viewModel: HomeScreenViewModel

    init(viewModel: HomeScreenViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        addNotifications()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // setup view
        checkLocationAuth()
        // fetch user data
        UserDataModel.shared.addListeners()

        let chooseSpotButton = UIButton()
        chooseSpotButton.setTitle("Choose spot", for: .normal)
        chooseSpotButton.backgroundColor = .blue
        chooseSpotButton.addTarget(self, action: #selector(chooseSpotTap), for: .touchUpInside)
        view.addSubview(chooseSpotButton)

        chooseSpotButton.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.height.equalTo(40)
            $0.width.equalTo(100)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setUpDarkNav(translucent: false)
    }

    private func addNotifications() {
        // deep link notis sent from SceneDelegate
        NotificationCenter.default.addObserver(self, selector: #selector(gotPost(_:)), name: NSNotification.Name("IncomingPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(gotNotification(_:)), name: NSNotification.Name("IncomingNotification"), object: nil)
    }

    @objc func chooseSpotTap() {
        let chooseSpotController = ChooseSpotController()
        chooseSpotController.delegate = self
        DispatchQueue.main.async {
            self.present(chooseSpotController, animated: true)
        }
    }
}

extension HomeScreenController: ChooseSpotDelegate {
    func finishPassing(spot: MapSpot?) {
        guard let spot else { return }
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot)), animated: true)
        }
    }

    func toggle(cancel: Bool) {
    }
}

extension HomeScreenController {
    private func checkLocationAuth() {
        if let alert = viewModel.locationService.checkLocationAuth() {
            present(alert, animated: true)
        }
    }
    @objc func gotMap(_ notification: NSNotification) {
        if let map = notification.userInfo?["mapInfo"] as? CustomMap {
         //   openMap(map: map)
        }
    }

    @objc func gotPost(_ notification: NSNotification) {
        if let post = notification.userInfo?["postInfo"] as? MapPost {
         //   openPost(post: post)
        }
    }

    private func openPost(post: MapPost, commentNoti: Bool? = false) {
 //       guard post.privacyLevel == "public" || (post.friendsList.contains(UserDataModel.shared.uid) ||
 //         (post.inviteList?.contains(UserDataModel.shared.uid) ?? false)) else { return }
        // push spot vc, passthrough selected post
        /*
        if let selectedVC = selectedViewController as? UINavigationController {
            selectedVC.pushViewController(postVC, animated: true)
        }
        */
    }

    @objc func gotNotification(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        /*
        if let mapID = userInfo["mapID"] as? String, mapID != "" {
            Task {
                do {
                    let map = try? await mapService?.getMap(mapID: mapID)
                    if let map {
                        self.openMap(map: map)
                    }
                }
            }
        } else if let postID = userInfo["postID"] as? String, postID != "" {
            Task {
                do {
                    let post = try? await postService?.getPost(postID: postID)
                    if let post {
                        let notiString = userInfo["commentNoti"] as? String
                        let commentNoti = notiString == "yes"
                        self.openPost(post: post, commentNoti: commentNoti)
                    }
                }
            }
        } else if let nav = viewControllers?[safe: 3] as? UINavigationController {
            nav.popToRootViewController(animated: false)
            selectedIndex = 3
        }
        */
    }

    @objc func notifyLogout() {
        DispatchQueue.main.async { self.dismiss(animated: false) }
    }

}
