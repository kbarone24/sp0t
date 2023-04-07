//
//  PhotoGalleryLimitedAccessExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos

extension PhotoGalleryController {
    // for .limited photoGallery access
    func showLimitedAlert() {
        let alert = UIAlertController(title: "You've allowed access to a limited number of photos", message: "", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Allow access to all photos", style: .default, handler: { action in
            switch action.style {
            case .default:
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            default: return
            }}))

        alert.addAction(UIAlertAction(title: "Select more photos", style: .default, handler: { action in
            switch action.style {
            case .default:
                UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .normal)
                UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .highlighted)
                UINavigationBar.appearance().backgroundColor = UIColor(named: "SpotBlack")
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            default: return
            }}))

        alert.addAction(UIAlertAction(title: "Keep current selection", style: .default, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }
}
