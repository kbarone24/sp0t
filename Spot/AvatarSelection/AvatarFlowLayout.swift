//
//  AvatarFlowLayout.swift
//  Spot
//
//  Created by Kenny Barone on 3/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class AvatarFlowLayout: UICollectionViewFlowLayout {
    override func prepare() {
        super.prepare()
        scrollDirection = .horizontal
        minimumInteritemSpacing = 15
        // sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        // snap to center
        var offsetAdjustment = CGFloat.greatestFiniteMagnitude
        let horizontalOffset = proposedContentOffset.x + (collectionView?.contentInset.left ?? 0)
        let targetRect = CGRect(x: proposedContentOffset.x, y: 0, width: (collectionView?.bounds.size.width ?? 0), height: (collectionView?.bounds.size.height ?? 0))
        let layoutAttributesArray = super.layoutAttributesForElements(in: targetRect)
        _ = layoutAttributesArray?.map { (layoutAttributes) in
            let itemOffset = layoutAttributes.frame.origin.x
            if fabsf(Float(itemOffset - horizontalOffset)) < fabsf(Float(offsetAdjustment)) {
                offsetAdjustment = itemOffset - horizontalOffset + 20
            }
        }
        
        return CGPoint(x: proposedContentOffset.x + offsetAdjustment, y: proposedContentOffset.y)
    }
}
