//
//  LinkPresentationItemSource.swift
//  Spot
//
//  Created by Kenny Barone on 9/14/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import LinkPresentation
import FirebaseDynamicLinks

class LinkPresentationItemSource: NSObject, UIActivityItemSource {
    var linkMetaData = LPLinkMetadata()

    //Prepare data to share
     func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        return linkMetaData
    }

    //Placeholder for real data, we don't care in this example so just return a simple string
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return "Placeholder"
    }

    /// Return the data will be shared
    /// - Parameters:
    ///   - activityType: Ex: mail, message, airdrop, etc..
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return linkMetaData.originalURL
    }

    init(metaData: LPLinkMetadata) {
        self.linkMetaData = metaData
    }
}
