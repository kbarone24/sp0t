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
    var userListener, mapsListener: ListenerRegistration?
    
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

        addNotifications()
        checkLocationAuth()
        DispatchQueue.global(qos: .utility).async {
            self.getActiveUser()
        }
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

    private func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost), name: NSNotification.Name(("NewPost")), object: nil)
    }
}

extension SpotTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let nav = viewController as? UINavigationController {
            if let post = nav.viewControllers.first as? PostController {
                if selectedIndex == 0 {
                    post.scrollToTop()
                } else {
                    return true
                }
            }
            if let explore = nav.viewControllers.first as? ExploreMapViewController {
                print("explore map")
            } else if let notis = nav.viewControllers.first as? NotificationsController {
                print("notis")
            } else if let profile = nav.viewControllers.first as? ProfileViewController {
                print("profile")
            }
        } else {
            openCamera()
        }
        return false
    }
}
