//
//  PostController.swift
//  Spot
//
//  Created by kbarone on 1/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseFunctions
import MapKit
import Mixpanel
import SnapKit
import UIKit

protocol PostControllerDelegate: AnyObject {
    func indexChanged(rowsRemaining: Int)
}

final class PostController: UIViewController {
    private(set) lazy var allPostsViewController: AllPostsViewController = {
        let viewModel = AllPostsViewModel(serviceContainer: ServiceContainer.shared)
        let allPostsVC = AllPostsViewController(viewModel: viewModel)
        return allPostsVC
    }()
    
    private(set) lazy var nearbyPostsViewController: NearbyPostsViewController = {
        let viewModel = NearbyPostsViewModel(serviceContainer: ServiceContainer.shared)
        let nearby = NearbyPostsViewController(viewModel: viewModel)
        return nearby
    }()
    
    private(set) lazy var pageViewController: UIPageViewController = {
        let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        
        pageViewController.delegate = self
        // pageViewController.dataSource = self
        return pageViewController
    }()

    var parentVC: PostParent
    weak var delegate: PostControllerDelegate?

    private var selectedSegment: FeedFetchType = .MyPosts {
        didSet {
            DispatchQueue.main.async {
                self.setSelectedSegment(segment: self.selectedSegment)
                self.titleView.setButtonBar(animated: true, selectedSegment: self.selectedSegment)
            }
        }
    }

    private lazy var titleView = PostTitleView()
    var isPageControllerTransitioning = false

    // pause image loading during row animation to avoid laggy scrolling
    init(parentVC: PostParent) {
        self.parentVC = parentVC
        super.init(nibName: nil, bundle: nil)

        setUpView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = [.top]
        
        nearbyPostsViewController.viewDidLoad()
        allPostsViewController.viewDidLoad()
        setSelectedSegment(segment: selectedSegment)
        
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        
        pageViewController.view.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        pageViewController.didMove(toParent: self)
        
        switch selectedSegment {
        case .MyPosts:
            pageViewController.setViewControllers([allPostsViewController], direction: .reverse, animated: true)
        case .NearbyPosts:
            pageViewController.setViewControllers([nearbyPostsViewController], direction: .forward, animated: true)
        }
    }
    
    func setUpNavBar() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
    }

    func setUpView() {
        if parentVC == .Home {
            titleView.setUp(parentVC: parentVC, selectedSegment: selectedSegment)
            titleView.myWorldButton.addTarget(self, action: #selector(myWorldTap), for: .touchUpInside)
            titleView.nearbyButton.addTarget(self, action: #selector(nearbyTap), for: .touchUpInside)
            titleView.findFriendsButton.addTarget(self, action: #selector(findFriendsTap), for: .touchUpInside)

        } else {
            titleView.setUp(parentVC: parentVC, selectedSegment: nil)
        }

        navigationItem.titleView = titleView
    }
    
    @objc func findFriendsTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenFindFriendsTap")
        let findFriendsController = FindFriendsController()
        navigationController?.pushViewController(findFriendsController, animated: true)
    }
}

// MARK: UIPageViewControllerDelegate and UIPageViewControllerDataSource

extension PostController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    private func setSelectedSegment(segment: FeedFetchType) {
        guard isViewLoaded else {
            return
        }
        
        let viewController: UIViewController
        let direction: UIPageViewController.NavigationDirection
        
        switch segment {
        case .MyPosts:
            viewController = self.allPostsViewController
            direction = .reverse
            
        case .NearbyPosts:
            viewController = self.nearbyPostsViewController
            direction = .forward
        }
        
        pageViewController.setViewControllers([viewController], direction: direction, animated: true)
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        isPageControllerTransitioning = true
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        
        guard completed,
              let currentViewController = pageViewController.viewControllers?.first,
              let previousViewController = previousViewControllers.first,
              currentViewController != previousViewController else {
            isPageControllerTransitioning = false
            return
        }
        
        isPageControllerTransitioning = false
        if previousViewController == allPostsViewController {
            selectedSegment = .NearbyPosts
        } else if previousViewController == nearbyPostsViewController {
            selectedSegment = .MyPosts
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController == nearbyPostsViewController {
            return allPostsViewController
        }
        
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController == allPostsViewController {
            return nearbyPostsViewController
        }
        
        return nil
    }
    
    @objc func myWorldTap() {
        switch selectedSegment {
        case .MyPosts:
            allPostsViewController.scrollToTop()
        case .NearbyPosts:
            selectedSegment = .MyPosts
        }
    }

    @objc func nearbyTap() {
        switch selectedSegment {
        case .NearbyPosts:
            nearbyPostsViewController.scrollToTop()
        case .MyPosts:
            selectedSegment = .NearbyPosts
        }
    }
}
