//
//  UploadChooseSpotExt.swift
//  Spot
//
//  Created by Kenny Barone on 11/19/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//
/*
import Foundation
import UIKit
import MapKit
import CoreData
import Firebase
import Mixpanel

extension UploadPostController: UISearchBarDelegate {
    
    func animateToChooseSpot() {
        
        chooseSpotMode = true
        setPostAnnotation(first: false, animated: true) /// adjust postAnno center point
        ///
        DispatchQueue.main.async {
          //  self.addTempGradient(hide: true)

            UIView.animate(withDuration: 0.3) {
                self.searchContainer.frame = CGRect(x: self.searchContainer.frame.minX, y: self.navBarHeight + 150, width: self.searchContainer.frame.width, height: self.searchContainer.frame.height)
                self.uploadTable.frame = CGRect(x: self.uploadTable.frame.minX, y: UIScreen.main.bounds.height, width: self.uploadTable.frame.width, height: self.uploadTable.frame.height)
                self.navigationController?.navigationBar.alpha = 0.0
            }
        }
    }
    
    func animateToUpload() {
        
        chooseSpotMode = false
        setPostAnnotation(first: false, animated: true)

        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25) {
                self.uploadTable.frame = CGRect(x: self.uploadTable.frame.minX, y: self.tableY, width: self.uploadTable.frame.width, height: self.uploadTable.frame.height)
                self.searchContainer.frame = CGRect(x: self.searchContainer.frame.minX, y: UIScreen.main.bounds.height, width: self.searchContainer.frame.width, height: self.searchContainer.frame.height)
                self.navigationController?.navigationBar.alpha = 1.0
            }
            
            /*
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                self.addTempGradient(hide: false)
                UIView.animate(withDuration: 0.15, animations: { self.gradientContainer.alpha = 1.0 })
            } */
        }
    }
    
    /*
    func addTempGradient(hide: Bool) {
        /// add temp black mask to fade and make gradient change look smoother
        
        let alpha0: CGFloat = hide ? 0.8 : 0.0
        let alpha1: CGFloat = hide ? 0.0 : 0.8

        let height0: CGFloat = hide ? 0 : UIScreen.main.bounds.height - gradientContainer.frame.maxY
        let height1 : CGFloat = hide ? UIScreen.main.bounds.height - gradientContainer.frame.maxY : 0
        let tempGradient = UIView(frame: CGRect(x: 0, y: gradientContainer.frame.maxY, width: UIScreen.main.bounds.width, height: height0))
        tempGradient.backgroundColor = .black
        tempGradient.alpha = alpha0
        mapView.addSubview(tempGradient)
        
        UIView.animate(withDuration: 0.15, animations: {
            tempGradient.alpha = alpha1
            tempGradient.frame = CGRect(x: tempGradient.frame.minX, y: tempGradient.frame.minY, width: tempGradient.frame.width, height: height1)
        }) { _ in tempGradient.removeFromSuperview()}
    }
    */

    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.endEditing(true)
    }
    
    @objc func searchButtonTap(_ sender: UIButton) {
        searchBar.becomeFirstResponder()
    }
    
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        openSearch()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        closeSearch()
        searchBar.text = ""
    }
        
    func openSearch() {
        
        // switch tables, show search bar items
        
        cancelButton.alpha = 0.0
        cancelButton.isHidden = false
        resultsTable.alpha = 0.0
        resultsTable.isHidden = false
                
        UIView.animate(withDuration: 0.15) {
            self.searchContainer.frame = CGRect(x: self.searchContainer.frame.minX, y: self.navBarHeight, width: self.searchContainer.frame.width, height: self.searchContainer.frame.height)
            self.searchBar.frame = CGRect(x: 16, y: 26, width: UIScreen.main.bounds.width - 106, height: 36)
            self.cancelButton.alpha = 1.0
            self.resultsTable.alpha = 1.0
            self.nearbyTable.alpha = 0.0
            self.chooseLabel.alpha = 0.0
            self.exitButton.alpha = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.isHidden = true
            self.nearbyTable.isHidden = true
            self.chooseLabel.isHidden = true
            self.exitButton.isHidden = true
            self.nearbyTable.alpha = 1.0
            self.chooseLabel.alpha = 1.0
            self.exitButton.alpha = 1.0
        }
    }
    
    func closeSearch() {
        
        // switch tables, remove search bar stuff
        
        self.nearbyTable.alpha = 0.0
        self.nearbyTable.isHidden = false
        self.chooseLabel.alpha = 0.0
        self.chooseLabel.isHidden = false
        self.exitButton.alpha = 0.0
        self.exitButton.isHidden = false

        UIView.animate(withDuration: 0.15) {
            self.searchContainer.frame = CGRect(x: self.searchContainer.frame.minX, y: self.navBarHeight + 150, width: self.searchContainer.frame.width, height: self.searchContainer.frame.height)
            self.searchBar.frame = CGRect(x: 12, y: 46, width: UIScreen.main.bounds.width - 130, height: 36)
            self.resultsTable.alpha = 0.0
            self.cancelButton.alpha = 0.0
            self.nearbyTable.alpha = 1.0
            self.chooseLabel.alpha = 1.0
            self.exitButton.alpha = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.stopAnimating()
            self.resultsTable.reloadData()
            self.resultsTable.isHidden = true
            self.resultsTable.alpha = 1.0
            self.cancelButton.isHidden = true
            self.cancelButton.alpha = 1.0
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
      
        self.searchTextGlobal = searchText
        emptyQueries()
        DispatchQueue.main.async { self.resultsTable.reloadData() }
        
        if searchBar.text == "" { self.searchIndicator.stopAnimating(); return }
        if !self.searchIndicator.isAnimating() { self.searchIndicator.startAnimating() }
        
        /// cancel search requests after user stops typing for 0.65/sec
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runQuery), object: nil)
        self.perform(#selector(runQuery), with: nil, afterDelay: 0.65)
    }
    
    @objc func runQuery() {
        
        emptyQueries()
        DispatchQueue.main.async { self.resultsTable.reloadData() }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.runPOIQuery(searchText: self.searchTextGlobal)
            self.runSpotsQuery(searchText: self.searchTextGlobal)
        }
    }
    
    func emptyQueries() {
        searchRefreshCount = 0
        querySpots.removeAll()
    }
    
    func runPOIQuery(searchText: String) {
        
        let search = MKLocalSearch.Request()
        search.naturalLanguageQuery = searchText
        search.resultTypes = .pointOfInterest
        search.region = MKCoordinateRegion(center: UserDataModel.shared.mapView.cameraState.center, latitudinalMeters: 5000, longitudinalMeters: 5000)
        search.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.atm, .carRental, .evCharger, .parking, .police])
        
        let searcher = MKLocalSearch(request: search)
        searcher.start { [weak self] response, error in
            
            guard let self = self else { return }
            if error != nil { self.reloadResultsTable(searchText: searchText) }
            if !self.queryValid(searchText: searchText) { return }
            guard let response = response else { self.reloadResultsTable(searchText: searchText); return }
            
            var index = 0
            
            for item in response.mapItems {

                if item.name != nil {

                    if self.querySpots.contains(where: {$0.spotName == item.name || ($0.phone ?? "" == item.phoneNumber ?? "" && item.phoneNumber ?? "" != "")}) { index += 1; if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }; continue }
                                        
                    let name = item.name!.count > 60 ? String(item.name!.prefix(60)) : item.name!
                                    
                    var spotInfo = MapSpot(spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotName: name, spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    
                    spotInfo.phone = item.phoneNumber ?? ""
                    spotInfo.id = UUID().uuidString
                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
                    
                    self.querySpots.append(spotInfo)
                    index += 1
                    if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }
                    
                } else {
                    index += 1
                    if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }
                }
                
            }
        }

    }
    
    func runSpotsQuery(searchText: String) {
                
        let spotsRef = db.collection("spots")
        let spotsQuery = spotsRef.whereField("searchKeywords", arrayContains: searchText.lowercased()).limit(to: 10)
                
        spotsQuery.getDocuments { [weak self] (snap, err) in
                        
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { return }
            
            if docs.count == 0 { self.reloadResultsTable(searchText: searchText) }

            for doc in docs {

                do {
                    /// get all spots that match query and order by distance
                    let info = try doc.data(as: MapSpot.self)
                    guard var spotInfo = info else { return }
                    spotInfo.id = doc.documentID
                    
                    if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                        
                        if spotInfo.privacyLevel != "public" {
                            spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"
                            
                        } else {
                            spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                        }
                        
                        /// replace duplicate POI with correct spotObject
                        if let i = self.querySpots.firstIndex(where: {$0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
                            self.querySpots[i] = spotInfo
                            self.querySpots[i].poiCategory = nil
                            
                        } else {
                            self.querySpots.append(spotInfo)
                        }
                    }
                    
                    if doc == docs.last {
                        self.reloadResultsTable(searchText: searchText)
                    }
                    
                } catch { if doc == docs.last {
                    self.reloadResultsTable(searchText: searchText) }; return }
            }
        }
    }

    
    func reloadResultsTable(searchText: String) {
        
        searchRefreshCount += 1
        if searchRefreshCount < 2 { return }
        
        querySpots.sort(by: {$0.distance < $1.distance})

        DispatchQueue.main.async {
            self.resultsTable.reloadData()
            self.searchIndicator.stopAnimating()
        }
    }
    
    func queryValid(searchText: String) -> Bool {
        return searchText == searchTextGlobal && searchText != ""
    }
    
    @objc func newSpotTap(_ sender: UIButton) {
        animateToUpload()
        presentAddNew()
    }
    
    @objc func exitTap(_ sender: UIButton) {
        animateToUpload()
    }
        
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
                    if self.spotObject != nil {  if (post.spotIDs?.first ?? "") != self.spotObject.id { return } }
                    /// test for corrupted draft or old draft (pre 1.0)
                    let timestampID = post.timestamp
                    
                    if post.images == nil { self.deletePostDraft(timestampID: timestampID, upload: false) }
                    let images = post.images! as! Set<ImageModel>
                    let firstImageData = images.first?.imageData
                    
                    if firstImageData == nil || post.addedUsers == nil {
                        self.deletePostDraft(timestampID: timestampID, upload: false)
                        
                    } else {
                        self.postDraft = post
                        let postImage = UIImage(data: firstImageData! as Data) ?? UIImage()
                        
                        DispatchQueue.main.async {
                            let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
                            window?.addSubview(self.maskView)

                            let infoView = BotDetailView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 116, y: UIScreen.main.bounds.height/2 - 140, width: 232, height: 190))
                            infoView.setUp(postDraft: post, image: postImage)
                            infoView.actionButton.addTarget(self, action: #selector(self.submitPostDraft(_:)), for: .touchUpInside)
                            infoView.cancelButton.addTarget(self, action: #selector(self.deletePostDraft(_:)), for: .touchUpInside)
                            self.maskView.addSubview(infoView)
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
    
    @objc func submitPostDraft(_ sender: UIButton) {
        
        Mixpanel.mainInstance().track(event: "UploadSubmitPostDraft", properties: nil)
        
        /// 1. remove preview
        removeBotDetail()

        /// 2. convert post draft to postObject and call submit func
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
        
        postObject = MapPost(id: postObject.id!, caption: postDraft.caption!, postLat: postDraft.postLat, postLong: postDraft.postLong, posterID: uid, timestamp: Timestamp(date: Date()), actualTimestamp: actualTimestamp, userInfo: UserDataModel.shared.userInfo, spotID: postDraft.spotIDs?.first!, city: postDraft.city, frameIndexes: postDraft.frameIndexes, aspectRatios: aspectRatios, imageURLs: [], postImage: uploadImages, seconds: postDraft.timestamp, selectedImageIndex: 0, postScore: 0, commentList: [], likers: [], taggedUsers: postDraft.taggedUsers ?? [], taggedUserIDs: postDraft.taggedUserIDs ?? [], imageHeight: 0, captionHeight: 0, cellHeight: 0, spotName: postDraft.spotNames?.first!, spotLat: postDraft.spotLat, spotLong: postDraft.spotLong, privacyLevel: postDraft.privacyLevel, spotPrivacy: postDraft.spotPrivacy ?? "friends", createdBy: postDraft.createdBy ?? "", inviteList: postDraft.inviteList ?? [], friendsList: postDraft.friendsList ?? [], hideFromFeed: postDraft.hideFromFeed, gif: false, isFirst: postDraft.isFirst, addedUsers: postDraft.addedUsers ?? [], addedUserProfiles: [], tag: postDraft.tags?.first!)
        postObject.posterUsername = UserDataModel.shared.userInfo.username

        spotObject = MapSpot(spotDescription: postDraft.caption ?? "", spotName: postDraft.spotNames?.first ?? "", spotLat: postDraft.spotLat, spotLong: postDraft.spotLong, founderID: postDraft.createdBy ?? "", privacyLevel: postDraft.spotPrivacy ?? "friends", imageURL: "")
        
        spotObject.id = postDraft.spotIDs?.first!
        spotObject.posterUsername = UserDataModel.shared.userInfo.username
        spotObject.poiCategory = postDraft.poiCategory
        spotObject.phone = postDraft.phone
        
        postType = postDraft.newSpot ? .newSpot : postDraft.postToPOI ? .postToPOI : .postToSpot

        setPostAnnotation(first: false, animated: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.uploadPost()
        }
    }

    @objc func deletePostDraft(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "UploadDeletePostDraft", properties: nil)
        deletePostDraft(timestampID: postDraft.timestamp, upload: false)
        removeBotDetail()
    }

    func deletePostDraft(timestampID: Int64, upload: Bool) {

        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        let managedContext =
            appDelegate.persistentContainer.viewContext
        let fetchRequest =
            NSFetchRequest<PostDraft>(entityName: "PostDraft")
        fetchRequest.predicate = NSPredicate(format: "timestamp == %d", timestampID)
        do {
            let drafts = try managedContext.fetch(fetchRequest)
            for draft in drafts {
                managedContext.delete(draft)
            }
            do {
                try managedContext.save()
            } catch let error as NSError {
                print("could not save. \(error)")
            }
        }
        catch let error as NSError {
            print("could not fetch. \(error)")
        }
      }
}

class LocationPickerAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        isEnabled = true
        isDraggable = true
        isSelected = true
        clusteringIdentifier = nil
        centerOffset = CGPoint(x: 0, y: -15)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class UploadAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        isEnabled = true
        isDraggable = true
        isSelected = true
        clusteringIdentifier = nil
        centerOffset = CGPoint(x: 0, y: -15)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
*/


