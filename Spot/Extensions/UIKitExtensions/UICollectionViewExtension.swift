//
//  UICollectionViewExtension.swift
//  Spot
//
//  Created by Kenny Barone on 5/17/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

extension UICollectionView {
    // scroll to next row if pagination is stuck between rows on reload
    func scrollToNextRowInFeed() {
        DispatchQueue.main.async {
            let currentOffset = self.contentOffset.y / self.frame.height
            if currentOffset.truncatingRemainder(dividingBy: 1) != 0 {
                let roundedOffset = currentOffset.rounded(.up)
                let selectedRow = roundedOffset * self.frame.height
                let duration = 0.3 * (roundedOffset - currentOffset)
                UIView.animate(withDuration: duration) {
                    self.setContentOffset(CGPoint(x: 0, y: selectedRow), animated: false)
                }
            }
        }
    }
}
