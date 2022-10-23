//
//  ExploreMapViewController.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Combine
import Firebase
import UIKit

final class ExploreMapViewController: UIViewController {

    enum Section: Hashable {
        case title
        case body
    }

    enum Item: Hashable {
        case title(title: String, subtitle: String)
        case item(data: CustomMap)
    }

    private let viewModel: ExploreMapViewModel

    init(viewModel: ExploreMapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
