//
//  SpotTabBarController.swift
//  Spot
//
//  Created by Kenny Barone on 2/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel
import MapKit

class SpotTabBarController: UITabBarController {
    private(set) lazy var feedItem = UITabBarItem(title: "", image: UIImage(named: "HomeTab"), selectedImage: UIImage(named: "HomeTabSelected"))
    private(set) lazy var mapItem = UITabBarItem(title: "", image: UIImage(named: "MapTab"), selectedImage: UIImage(named: "MapTabSelected"))
    private(set) lazy var addItem = UITabBarItem(title: "", image: UIImage(named: "AddButton")?.withRenderingMode(.alwaysOriginal), selectedImage: UIImage())
    private(set) lazy var notificationsItem = UITabBarItem(title: "", image: UIImage(named: "NotificationsTab"), selectedImage: UIImage(named: "NotificationsTabSelected"))
    private(set) lazy var profileItem = UITabBarItem(title: "", image: UIImage(named: "ProfileTab"), selectedImage: UIImage(named: "ProfileTabSelected"))

    let db = Firestore.firestore()
    var userListener: ListenerRegistration?
    
    let locationManager = CLLocationManager()
    var firstTimeGettingLocation = false

    init() {
        super.init(nibName: nil, bundle: nil)
        viewSetup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        checkLocationAuth()
        getActiveUser()
    }

    override func viewDidLayoutSubviews() {
        print("height", tabBar.frame.height)
    }

    private func viewSetup() {
        view.backgroundColor = .black
        tabBar.backgroundColor = .black
        tabBar.tintColor = .white
        tabBar.isTranslucent = false

        let postVC = PostController(parentVC: .Home, postsList: [])
        let nav0 = UINavigationController(rootViewController: postVC)
        nav0.tabBarItem = feedItem

        // TODO: Replace with new explore vc
        let exploreVC = ExploreMapViewController(viewModel: ExploreMapViewModel(serviceContainer: ServiceContainer.shared, from: .mapController))
        let nav1 = UINavigationController(rootViewController: exploreVC)
        nav1.tabBarItem = mapItem

        let emptyVC = UIViewController()
        emptyVC.tabBarItem = addItem

        let notificationsVC = NotificationsController()
        let nav2 = UINavigationController(rootViewController: notificationsVC)
        nav2.tabBarItem = notificationsItem

        let profileVC = ProfileViewController()
        let nav3 = UINavigationController(rootViewController: profileVC)
        nav3.tabBarItem = profileItem

        self.viewControllers = [nav0, nav1, emptyVC, nav2, nav3]
    }
}

extension SpotTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        print("select")
        return false
    }
}
