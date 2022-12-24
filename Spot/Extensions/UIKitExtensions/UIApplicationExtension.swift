//
//  UIApplicationExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

extension UIApplication {
    var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap({ $0 as? UIWindowScene })?.windows
            .first(where: \.isKeyWindow)
    }
}
