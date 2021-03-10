//
//  Post.swift
//  Spot
//
//  Created by kbarone on 2/27/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Foundation
import UIKit

class FeedPost {
    
    var spotname: String
    var spotID : String
    var posterID : String
    var founderID: String
    var caption: String
    var captionHeight: CGFloat
    var imageURL: [String]
    var photo: [UIImage]
    var uName: String
    var profilePic: UIImage
    var likers: [String]
    var wasLiked : Bool
    var location: String
    var spotLat : Double
    var spotLong : Double
    var time : Int64
    var date : Date
    var postID : String
    var commentList : [Comment]
    var imageHeight : Int
    var isFirst : Bool
    var seen : Bool
    var friends: Bool
    var selectedImageIndex: Int
    var privacyLevel: String
    var taggedFriends: [String]
    var GIF: Bool
    
    init(spotname:String, spotID: String, posterID: String, founderID: String, captionText:String, captionHeight: CGFloat, imageURL: [String], photo: [UIImage], uNameString:String, profilePic: UIImage, likers:[String], wasLiked: Bool, location: String, spotLat: Double, spotLong: Double, time: Int64, date: Date, postID: String, commentList: [Comment], imageHeight: Int, isFirst: Bool, seen: Bool, friends: Bool, selectedImageIndex: Int, privacyLevel: String, taggedFriends: [String], GIF: Bool){
        self.spotname = spotname
        self.spotID = spotID
        self.posterID = posterID
        self.founderID = founderID
        self.caption = captionText
        self.captionHeight = captionHeight
        self.imageURL = imageURL
        self.photo = photo
        self.uName = uNameString
        self.profilePic = profilePic
        self.likers = likers
        self.wasLiked = wasLiked
        self.spotLat = spotLat
        self.spotLong = spotLong
        self.location = location
        self.time = time
        self.date = date
        self.postID = postID
        self.commentList = commentList
        self.imageHeight = imageHeight
        self.isFirst = isFirst
        self.seen = seen
        self.friends = friends
        self.selectedImageIndex = selectedImageIndex
        self.privacyLevel = privacyLevel
        self.taggedFriends = taggedFriends
        self.GIF = GIF
    }
  
}
