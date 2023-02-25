//
//  AllPostsViewController.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Combine

final class AllPostsViewController: UIViewController {
    
    enum Section: Hashable {
        case main
    }
    
    enum Item: Hashable {
        case item(customMap: CustomMap, post: MapPost)
    }
    
    private(set) lazy var contentTable: UITableView = {
        let view = UITableView()
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIScreen.main.bounds.height, right: 0)
        view.backgroundColor = .black
        view.separatorStyle = .none
        view.isScrollEnabled = false
        view.isPrefetchingEnabled = true
        view.showsVerticalScrollIndicator = false
        view.scrollsToTop = false
        view.contentInsetAdjustmentBehavior = .never
        view.shouldIgnoreContentInsetAdjustment = true
        // inset to show button view
        view.register(ContentViewerCell.self, forCellReuseIdentifier: ContentViewerCell.reuseID)
        view.register(ContentLoadingCell.self, forCellReuseIdentifier: ContentLoadingCell.reuseID)
        return view
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
