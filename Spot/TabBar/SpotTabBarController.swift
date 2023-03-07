//
//  SpotTabBarController.swift
//  Spot
//
//  Created by Kenny Barone on 2/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Mixpanel
import MapKit

final class SpotTabBarController: UITabBarController {
    
    private(set) lazy var feedItem = UITabBarItem(title: "", image: UIImage(named: "HomeTab"), selectedImage: UIImage(named: "HomeTabSelected"))
    
    private(set) lazy var mapItem = UITabBarItem(title: "", image: UIImage(named: "MapTab"), selectedImage: UIImage(named: "MapTabSelected"))
    
    private(set) lazy var addItem = UITabBarItem(title: "", image: UIImage(named: "AddButton")?.withRenderingMode(.alwaysOriginal), selectedImage: UIImage())
    
    private(set) lazy var notificationsItem = UITabBarItem(title: "", image: UIImage(named: "NotificationsTab"), selectedImage: UIImage(named: "NotificationsTabSelected"))
    
    private(set) lazy var profileItem = UITabBarItem(title: "", image: UIImage(named: "ProfileTab"), selectedImage: UIImage(named: "ProfileTabSelected"))
    
    private lazy var locationService: LocationServiceProtocol? = {
        return try? ServiceContainer.shared.service(for: \.locationService)
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        viewSetup()
        UserDataModel.shared.addListeners()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("tab bar deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        addNotifications()
        checkLocationAuth()
    }

    private func viewSetup() {
        view.backgroundColor = .black
        tabBar.backgroundColor = .black
        tabBar.clipsToBounds = false
        tabBar.tintColor = .white
        tabBar.isTranslucent = false

        let postVC = PostController(parentVC: .Home)
        let nav0 = UINavigationController(rootViewController: postVC)
        nav0.tabBarItem = feedItem

        // TODO: Replace with new explore vc
        let exploreVC = ExploreMapViewController(viewModel: ExploreMapViewModel(serviceContainer: ServiceContainer.shared))
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
        NotificationCenter.default.addObserver(self, selector: #selector(notifyLogout), name: NSNotification.Name(("Logout")), object: nil)
    }

    @objc private func notifyLogout() {
        DispatchQueue.main.async { self.dismiss(animated: false) }
    }
    
    private func checkLocationAuth() {
        if let alert = locationService?.checkLocationAuth() {
            present(alert, animated: true)
        }
    }
}

extension SpotTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let nav = viewController as? UINavigationController {
            if let post = nav.viewControllers.first as? PostController {
                Mixpanel.mainInstance().track(event: "PostsScreenNotificationsTap")
                if selectedIndex == 0 {
                    if nav.viewControllers.count == 1 {
                        post.allPostsViewController.scrollToTop()
                    } else {
                        nav.popToRootViewController(animated: true)
                    }
                    return false
                }
                return true
            }
            
            if nav.viewControllers.first is ExploreMapViewController {
                if selectedIndex == 1 {
                    if nav.viewControllers.count == 1 {
                        print("1")
                    } else {
                        nav.popToRootViewController(animated: true)
                    }
                    return false
                }
                return true
            }
            
            if let notis = nav.viewControllers.first as? NotificationsController {
                if selectedIndex == 3 {
                    if nav.viewControllers.count == 1 {
                        notis.scrollToTop()
                    } else {
                        nav.popToRootViewController(animated: true)
                    }
                    return false
                }
                return true
                
            } else if nav.viewControllers.first is ProfileViewController {
                if selectedIndex == 4 {
                    if nav.viewControllers.count == 1 {
                        // profile.scrollToTop()
                    } else {
                        nav.popToRootViewController(animated: true)
                    }
                    return false
                }
                return true
            }
        } else {
            openCamera()
        }
        return false
    }
}
