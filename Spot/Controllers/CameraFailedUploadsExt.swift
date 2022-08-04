//
//  CameraFailedUploadsExt.swift
//  Spot
//
//  Created by Kenny Barone on 7/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import CoreData
import Mixpanel
import Firebase

extension AVCameraController {
    
    func getFailedUploads() {
        
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let managedContext =
        appDelegate.persistentContainer.viewContext
        let postsRequest =
        NSFetchRequest<PostDraft>(entityName: "PostDraft")
        
        postsRequest.relationshipKeyPathsForPrefetching = ["images"]
        postsRequest.returnsObjectsAsFaults = false
        postsRequest.predicate = NSPredicate(format: "uid == %@", self.uid)
        let timeSort = NSSortDescriptor(key: "timestamp", ascending: false)
        postsRequest.sortDescriptors = [timeSort]
        
        DispatchQueue.global().async {
            do {
                
                let failedPosts = try managedContext.fetch(postsRequest)
                if let post = failedPosts.first {
                    ///if add-to-spot mode, only get failed uploads that are posts to this spot
                    if self.spotObject != nil { return }
                    /// test for corrupted draft or old draft (pre 1.0)
                    let timestampID = post.timestamp
                    
                    if post.images == nil { self.deletePostDraft(timestampID: timestampID) }
                    let images = post.images! as! Set<ImageModel>
                    let firstImageData = images.first?.imageData
                    
                    if firstImageData == nil || post.addedUsers == nil {
                        self.deletePostDraft(timestampID: timestampID)
                        
                    } else {
                        self.postDraft = post
                        let postImage = UIImage(data: firstImageData! as Data) ?? UIImage()
                        
                        DispatchQueue.main.async {
                            self.failedPostView = FailedPostView {
                                $0.coverImage.image = postImage
                                self.view.addSubview($0)
                            }
                            self.failedPostView!.snp.makeConstraints {
                                $0.edges.equalToSuperview()
                            }
                        }
                        return
                    }
                    return
                }
                
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }
    }
    
    func deletePostDraft() {
        Mixpanel.mainInstance().track(event: "CameraDeletePostDraft", properties: nil)
        deletePostDraft(timestampID: postDraft!.timestamp)
        
        failedPostView!.removeFromSuperview()
        failedPostView = nil
    }
    
    func uploadPostDraft() {
        let postDraft = postDraft!
        let model = postDraft.images! as! Set<ImageModel>
        let mod = model.sorted(by: {$0.position < $1.position})
        
        var uploadImages: [UIImage] = []
        
        for i in 0...mod.count - 1 {
            let im = mod[i]
            let imageData = im.imageData
            uploadImages.append(UIImage(data: imageData!) ?? UIImage())
        }
        
        let actualTimestamp = Timestamp(seconds: postDraft.timestamp, nanoseconds: 0)
        var aspectRatios: [CGFloat] = []
        for ratio in postDraft.aspectRatios ?? [] { aspectRatios.append(CGFloat(ratio)) }
        var post = MapPost(id: UUID().uuidString, addedUsers: postDraft.addedUsers, aspectRatios: aspectRatios, caption: postDraft.caption ?? "", city: postDraft.city, createdBy: postDraft.createdBy, frameIndexes: postDraft.frameIndexes, friendsList: postDraft.friendsList ?? [], hideFromFeed: postDraft.hideFromFeed, imageLocations: [], imageURLs: [], inviteList: postDraft.inviteList ?? [], likers: [], mapID: postDraft.mapID ?? "", mapName: postDraft.mapName ?? "", postLat: postDraft.postLat, postLong: postDraft.postLong, posterID: uid, posterUsername: UserDataModel.shared.userInfo.username, privacyLevel: postDraft.privacyLevel ?? "", seenList: [uid], spotID: postDraft.spotID ?? "", spotLat: postDraft.spotLat, spotLong: postDraft.spotLong, spotName: postDraft.spotName, spotPrivacy: postDraft.spotPrivacy, tag: "", taggedUserIDs: postDraft.taggedUserIDs ?? [], taggedUsers: postDraft.taggedUsers ?? [], timestamp: actualTimestamp, addedUserProfiles: [], userInfo: UserDataModel.shared.userInfo, mapInfo: nil, commentList: [], postImage: uploadImages, postScore: 0, seconds: 0, selectedImageIndex: 0, imageHeight: 0, captionHeight: 0, cellHeight: 0, commentsHeight: 0, seen: true)
        
        /// set spot values
        var spot = MapSpot(founderID: postDraft.createdBy ?? "", imageURL: "", privacyLevel: postDraft.spotPrivacy ?? "", spotDescription: postDraft.caption ?? "", spotLat: postDraft.spotLat, spotLong: postDraft.spotLong, spotName: postDraft.spotName)
        spot.visitorList = postDraft.visitorList ?? []
        spot.id = post.spotID ?? ""
        spot.poiCategory = postDraft.poiCategory
        spot.phone = postDraft.phone
        UploadPostModel.shared.postType = postDraft.newSpot ? .newSpot : postDraft.postToPOI ? .postToPOI : spot.id != "" ? .postToSpot : .none
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMap(mapID: post.mapID ?? "") { map, failed in
                var map = map
                self.uploadPostImage(post.postImage, postID: post.id!, progressFill: self.failedPostView!.progressFill, fullWidth: UIScreen.main.bounds.width - 100) { [weak self] imageURLs, failed in
                    guard let self = self else { return }
                    
                    if imageURLs.isEmpty && failed {
                        Mixpanel.mainInstance().track(event: "FailedPostUpload")
                        self.showFailAlert()
                        return
                    }
                    
                    post.imageURLs = imageURLs
                    post.timestamp = Firebase.Timestamp(date: Date())
                    
                    self.uploadPost(post: post)

                    if spot.id != "" {
                        spot.imageURL = imageURLs.first ?? ""
                        self.uploadSpot(post: post, spot: spot, submitPublic: false)
                    }
                    
                    let newMap = post.mapID ?? "" != "" && map.id ?? "" == ""
                    if newMap {
                        map = CustomMap(id: post.mapID!, founderID: self.uid, imageURL: imageURLs.first!, likers: [], mapName: post.mapName ?? "", memberIDs: [self.uid], posterDictionary: [post.id! : [self.uid]], posterIDs: [self.uid], posterUsernames: [UserDataModel.shared.userInfo.username], postIDs: [post.id!], postImageURLs: post.imageURLs, postLocations: [["lat" : post.postLat, "long": post.postLong]], postTimestamps: [], secret: false, spotIDs: [post.spotID ?? ""], memberProfiles: [UserDataModel.shared.userInfo], coverImage: uploadImages.first!)
                  
                    } else if map.id ?? "" != "" {
                        /// set final map values
                        map.postIDs.append(post.id!)
                        if spot.id ?? "" != "" && !map.spotIDs.contains(spot.id!) { map.spotIDs.append(spot.id!) }
                        map.postLocations.append(["lat": post.postLat, "long": post.postLong])
                        
                        let uid = UserDataModel.shared.uid
                        var posters = [uid]
                        if !(post.addedUsers?.isEmpty ?? true) { posters.append(contentsOf: post.addedUsers!) }
                        map.posterDictionary[post.id!] = posters
                        map.posterIDs.append(uid)
                        map.posterUsernames.append(UserDataModel.shared.userInfo.username)
                        for poster in posters {
                            if !map.memberIDs.contains(poster) { map.memberIDs.append(poster) }
                        }
                    }
                    
                    if !(post.addedUsers ?? []).isEmpty { map.posterDictionary[post.id!]!.append(contentsOf: post.addedUsers!) }
                    if map.id ?? "" != "" {
                        if map.imageURL == "" { map.imageURL = imageURLs.first ?? "" }
                        self.uploadMap(map: map, newMap: newMap, post: post)
                    }

                    let visitorList = spot.visitorList
                    self.setUserValues(poster: self.uid, post: post, spotID: spot.id ?? "", visitorList: visitorList, mapID: map.id ?? "")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.showSuccessAlert()
                    }
                }
            }
        }
    }
    
    
    func showSuccessAlert() {
        deletePostDraft()
        let alert = UIAlertController(title: "Post successfully uploaded!", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func getMap(mapID: String, completion: @escaping (_ map: CustomMap, _ failed: Bool) -> Void) {
        let emptyMap = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        if mapID == "" { completion(emptyMap, false); return }
        
        let db: Firestore! = Firestore.firestore()
        let mapRef = db.collection("maps").document(mapID)
        
        mapRef.getDocument { (doc, err) in
            do {
                let unwrappedInfo = try doc?.data(as: CustomMap.self)
                guard var mapInfo = unwrappedInfo else { completion(emptyMap, true); return }
                mapInfo.id = mapID
                completion(mapInfo, false)
                return
            } catch {
                completion(emptyMap, true)
                return
            }
        }
    }

}

class FailedPostView: UIView {
    var contentView: UIView!
    var retryLabel: UILabel!
    var coverImage: UIImageView!
    var cancelButton: UIButton!
    var postButton: UIButton!
    
    var progressBar: UIView!
    var progressFill: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.9)
        
        contentView = UIView {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 12
            addSubview($0)
        }
        contentView.snp.makeConstraints {
            $0.height.equalTo(160)
            $0.width.equalToSuperview().inset(30)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }
        
        coverImage = UIImageView {
            $0.layer.cornerRadius = 8
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            contentView.addSubview($0)
        }
        coverImage.snp.makeConstraints {
            $0.leading.top.equalTo(12)
            $0.height.equalTo(70)
            $0.width.equalTo(70)
        }
        
        retryLabel = UILabel {
            $0.text = "Retry failed upload?"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            contentView.addSubview($0)
        }
        retryLabel.snp.makeConstraints {
            $0.leading.equalTo(coverImage.snp.trailing).offset(14)
            $0.centerY.equalTo(coverImage.snp.centerY)
        }
        
        cancelButton = UIButton {
            $0.backgroundColor = UIColor(red: 0.871, green: 0.871, blue: 0.871, alpha: 1)
            $0.setTitle("Cancel", for: .normal)
            $0.setTitleColor(.red, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            $0.layer.cornerRadius = 13
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            $0.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.trailing.equalTo(contentView.snp.centerX).offset(-15)
            $0.bottom.equalToSuperview().inset(12)
            $0.width.equalTo(100)
            $0.height.equalTo(40)
        }
        
        postButton = UIButton {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.setTitle("Post", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
            $0.layer.cornerRadius = 13
            $0.contentVerticalAlignment = .center
            $0.contentHorizontalAlignment = .center
            $0.addTarget(self, action: #selector(postTap), for: .touchUpInside)
            contentView.addSubview($0)
        }
        postButton.snp.makeConstraints {
            $0.leading.equalTo(contentView.snp.centerX).offset(15)
            $0.bottom.equalToSuperview().inset(12)
            $0.width.equalTo(100)
            $0.height.equalTo(40)
        }
        
        progressBar = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
            $0.layer.cornerRadius = 6
            $0.layer.borderWidth = 2
            $0.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            $0.isHidden = true
            addSubview($0)
        }
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.top.equalTo(contentView.snp.bottom).offset(30)
            $0.height.equalTo(18)
        }
        
        progressFill = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 6
            progressBar.addSubview($0)
        }
        progressFill.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(1)
            $0.width.equalTo(0)
            $0.height.equalTo(16)
        }
    }
    
    @objc func cancelTap() {
        if let cameraVC = viewContainingController() as? AVCameraController {
            cameraVC.deletePostDraft()
        }
       // infoView.cancelButton.addTarget(self, action: #selector(self.deletePostDraft(_:)), for: .touchUpInside)
    }
    
    @objc func postTap() {
        /// upload and delete post draft if success
        self.isUserInteractionEnabled = false
        if let cameraVC = viewContainingController() as? AVCameraController {
            cameraVC.uploadPostDraft()
            progressBar.isHidden = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
