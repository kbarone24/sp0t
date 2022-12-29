//
//  HomeScreenContainerController.swift
//  Spot
//
//  Created by Kenny Barone on 12/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class HomeScreenContainerController: UIViewController {
    lazy var mapController = MapNavigationController(rootViewController: MapController())
    lazy var sideBarController = MapSideBarController()

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .green

        addChild(mapController)
        view.addSubview(mapController.view)
        mapController.didMove(toParent: self)
        mapController.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addChild(sideBarController)
        view.addSubview(sideBarController.view)
        sideBarController.didMove(toParent: self)
        sideBarController.view.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalTo(view.snp.leading)
            $0.width.equalTo(view.snp.width).inset(70)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
