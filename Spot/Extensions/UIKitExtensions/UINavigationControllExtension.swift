//
//  UINavigationControllExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/17/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension UINavigationController {

  open override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    navigationBar.topItem?.backButtonDisplayMode = .minimal
  }
}
