//
//  GuestbookPreview.swift
//  Spot
//
//  Created by Kenny Barone on 6/17/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation

struct GuestbookPreview {

    var postID: String
    var frameIndex: Int /// the frame to display in preview
    var imageIndex: Int /// the image # that the user will see in the expanded post view
    var imageURL: String
    var seconds: Int64
    var date: String

    init(postID: String, frameIndex: Int, imageIndex: Int, imageURL: String, seconds: Int64, date: String) {
        self.postID = postID
        self.frameIndex = frameIndex
        self.imageIndex = imageIndex
        self.imageURL = imageURL
        self.seconds = seconds
        self.date = date
    }
}
