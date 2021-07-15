//
//  DraftsViewController.swift
//  Spot
//
//  Created by kbarone on 5/15/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CoreLocation
import Firebase
import Geofirestore
import Mixpanel

class DraftsViewController: UIViewController, UIGestureRecognizerDelegate {
    
    unowned var mapVC: MapViewController!
    var spotObject: MapSpot!
    
    lazy var aliveCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: LeftAlignedCollectionViewFlowLayout.init())
    lazy var failedUploadCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: LeftAlignedCollectionViewFlowLayout.init())
    lazy var aliveDrafts: [([UIImage], Int64, CLLocation)] = []
    lazy var alivesIndicator = CustomActivityIndicator()
    
    /// previewView
    var maskView: UIView!
    var previewView: UIImageView!
    var cityName: UILabel!
    
    var baseSize: CGSize!
    let failedSize: CGSize = CGSize(width: 120, height: 214)
    lazy var selectedItem = 0
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let db = Firestore.firestore()
    
    var failedUploads: [(coverImage: UIImage, spotName: String, timestampID: Int64, type: String)] = []
    
    lazy var failedSpots: [SpotDraft] = []
    lazy var failedPosts: [PostDraft] = []
    
    var progressView: UIProgressView!
    
    var shouldUploadPost = true
    var emptyState = true
    var uploadsFetched = 0 /// patch variable to avoid empty alives prematurely adding empty state
    
    var mainScroll = UIScrollView()
    var shadowScroll = UIScrollView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        mainScroll = UIScrollView(frame: view.frame)
        mainScroll.backgroundColor = UIColor(named: "SpotBlack")
        mainScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        mainScroll.isScrollEnabled = false
        mainScroll.isUserInteractionEnabled = true
        mainScroll.showsVerticalScrollIndicator = false
        view.addSubview(mainScroll)
        
        shadowScroll = UIScrollView(frame: CGRect(x: 0, y: -UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        shadowScroll.backgroundColor = nil
        shadowScroll.isScrollEnabled = true
        shadowScroll.isUserInteractionEnabled = true
        shadowScroll.showsVerticalScrollIndicator = false
        shadowScroll.delegate = self
        shadowScroll.panGestureRecognizer.delaysTouchesBegan = true
        shadowScroll.tag = 84
        
        mainScroll.removeGestureRecognizer(mainScroll.panGestureRecognizer)
        mainScroll.addGestureRecognizer(shadowScroll.panGestureRecognizer)

        if emptyState {
            self.addEmptyState()
            return
        }
        
        setUpViews()
        getFailedUploads()
        getImages()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        mapVC.customTabBar.tabBar.isHidden = true
        Mixpanel.mainInstance().track(event: "DraftsOpen")
        setUpNavBar()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removePreview()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
     
    func setUpViews() {
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)

        let width = (UIScreen.main.bounds.width - 60) / 4
        baseSize = CGSize(width: width, height: width * 1.43)
        aliveCollection.frame = CGRect(x: 0, y: 35, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - navBarHeight)
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        aliveCollection.backgroundColor = UIColor(named: "SpotBlack")
        aliveCollection.register(AliveThumbnail.self, forCellWithReuseIdentifier: "AliveThumbnail")
        aliveCollection.tag = 0
        aliveCollection.showsVerticalScrollIndicator = false
        aliveCollection.isUserInteractionEnabled = true
        aliveCollection.delegate = self
        aliveCollection.dataSource = self
        aliveCollection.isScrollEnabled = false
        aliveCollection.delaysContentTouches = false
        aliveCollection.contentInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        aliveCollection.removeGestureRecognizer(aliveCollection.panGestureRecognizer)
        mainScroll.addSubview(aliveCollection)
        
        alivesIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 10, width: UIScreen.main.bounds.width - 28, height: 25))
        alivesIndicator.startAnimating()
        aliveCollection.addSubview(alivesIndicator)
        
        /// failed upload collection hidden by default (height: 0)
        failedUploadCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0)
        failedUploadCollection.backgroundColor = UIColor(named: "SpotBlack")
        failedUploadCollection.register(FailedUploadCell.self, forCellWithReuseIdentifier: "FailedUploadCell")
        failedUploadCollection.register(FailedUploadHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "FailedUploadHeader")
        failedUploadCollection.tag = 1
        failedUploadCollection.showsHorizontalScrollIndicator = false
        failedUploadCollection.isUserInteractionEnabled = true
        failedUploadCollection.delegate = self
        failedUploadCollection.dataSource = self
        failedUploadCollection.delaysContentTouches = false
        failedUploadCollection.isScrollEnabled = false
        failedUploadCollection.contentInset = UIEdgeInsets(top: 15, left: 7, bottom: 0, right: 7)
                
        mainScroll.addSubview(failedUploadCollection)
        
        maskView = UIView(frame: CGRect(x: 0, y: navBarHeight, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - navBarHeight))
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        maskView.isHidden = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(removePreview(_:)))
        tap.delegate = self
        maskView.addGestureRecognizer(tap)
        
        window?.addSubview(maskView)
        
        let previewHeight = (UIScreen.main.bounds.width - 80) * 1.75
        let previewY = (UIScreen.main.bounds.height - navBarHeight - previewHeight - 20)/2
            
        previewView = UIImageView(frame: CGRect(x: 40, y: previewY, width: UIScreen.main.bounds.width - 80, height: previewHeight))
        previewView.layer.cornerRadius = 12
        previewView.layer.masksToBounds = true
        previewView.contentMode = .scaleAspectFill
        previewView.isUserInteractionEnabled = true
                
        /// mask for preview view
        let layer0 = CAGradientLayer()
        layer0.frame = CGRect(x: 0, y: 0, width: previewView.bounds.width, height: 60)
        layer0.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 0.24).cgColor,
            UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 0.6).cgColor
        ]
        layer0.locations = [0, 0.49, 1.0]
        layer0.startPoint = CGPoint(x: 0.5, y: 1.0)
        layer0.endPoint = CGPoint(x: 0.5, y: 0)
        previewView.layer.addSublayer(layer0)
        
        let deleteButton = UIButton(frame: CGRect(x: 6, y: previewView.bounds.maxY - 49, width: 43, height: 43))
        deleteButton.setImage(UIImage(named: "DeleteDraftButton"), for: .normal)
        deleteButton.imageView?.contentMode = .scaleAspectFit
        deleteButton.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
        previewView.addSubview(deleteButton)

        let cityIcon = UIImageView(frame: CGRect(x: 15, y: 14.5, width: 10, height: 15))
        cityIcon.image = UIImage(named: "DraftsCityIcon")
        previewView.addSubview(cityIcon)

        cityName = UILabel(frame: CGRect(x: cityIcon.frame.maxX + 5, y: 14.5, width: previewView.frame.width - 70, height: 16))
        cityName.textColor = .white
        cityName.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        previewView.addSubview(cityName)
        
        progressView = UIProgressView(frame: CGRect(x: 50, y: 260, width: UIScreen.main.bounds.width - 100, height: 20))
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 2.3)
        progressView.layer.cornerRadius = 2
        progressView.layer.sublayers![1].cornerRadius = 2
        progressView.subviews[1].clipsToBounds = true
        progressView.clipsToBounds = true
        progressView.isHidden = true
        progressView.progressTintColor = UIColor(named: "SpotGreen")
        progressView.progress = 0.0
        maskView.addSubview(progressView)
    }
    
    func setUpNavBar() {
        navigationItem.title = "Drafts"
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.addShadow()
        navigationController?.navigationBar.addBackgroundImage(alpha: 1.0)
    }
    
    func addEmptyState() {
        
        let bot = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 15, y: UIScreen.main.bounds.height/2 - 100, width: 30, height: 34))
        bot.image = UIImage(named: "OnboardB0t")
        bot.contentMode = .scaleAspectFit
        mainScroll.addSubview(bot)
        
        let emptyDescription = UILabel(frame: CGRect(x: 50, y: bot.frame.maxY + 8, width: UIScreen.main.bounds.width - 100, height: 18))
        emptyDescription.text = "Your drafts are empty"
        emptyDescription.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        emptyDescription.font = UIFont(name: "SFCamera-Regular", size: 14)
        emptyDescription.textAlignment = .center
        mainScroll.addSubview(emptyDescription)
        
        let returnButton = UIButton(frame: CGRect(x: 100, y: emptyDescription.frame.maxY + 10, width: UIScreen.main.bounds.width - 200, height: 28))
        returnButton.backgroundColor = nil
        returnButton.setTitle("Back to camera", for: .normal)
        returnButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        returnButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        returnButton.titleLabel?.textAlignment = .center
        returnButton.addTarget(self, action: #selector(returnToCamera(_:)), for: .touchUpInside)
        returnButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        mainScroll.addSubview(returnButton)
        
        if let camera = parent as? AVCameraController {
            camera.draftsActive = false
        }
    }
    
    @objc func returnToCamera(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func getImages() {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<ImagesArray>(entityName: "ImagesArray")
        
        fetchRequest.relationshipKeyPathsForPrefetching = ["images"]
        fetchRequest.returnsObjectsAsFaults = false
        let timeSort = NSSortDescriptor(key: "id", ascending: false)
        fetchRequest.sortDescriptors = [timeSort]
        fetchRequest.predicate = NSPredicate(format: "uid == %@", self.uid)
        
        var counter = 0
        
        DispatchQueue.global().async {
            do {
                
                let drafts = try managedContext.fetch(fetchRequest)
                if drafts.count == 0 { self.removeAlives() }
                
                for draft in drafts {
                    
                    var draftImages: [UIImage] = []
                    
                    if draft.images?.count == 0 { counter += 0; if counter == drafts.count { self.finishAlivesLoad() } }
                    
                    let model = draft.images! as! Set<ImageModel>
                    
                    ///sort images according to their original upload position (images dont always save in order)
                    let mod = model.sorted(by: {$0.position < $1.position})
                    
                    for i in 0...mod.count - 1 {
                        let im = mod[i]
                        let imageData = im.imageData
                        let image = UIImage(data: imageData! as Data) ?? UIImage()
                        draftImages.append(image)
                    }
                    
                    let timestamp = draft.id

                    var draftLocation = CLLocation()
                    
                    if draft.postLat != nil {
                        let postLat = Double(truncating: draft.postLat!)
                        let postLong = Double(truncating: draft.postLong!)
                        
                        draftLocation = CLLocation(latitude: postLat, longitude: postLong)
                    }

                    self.aliveDrafts.append((draftImages, timestamp, draftLocation))
                    
                    counter += 1
                    if counter == drafts.count { self.finishAlivesLoad() }
                }
                
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }
    }
    
    func finishAlivesLoad() {
        
        DispatchQueue.main.async {
            self.aliveCollection.reloadData()
            self.aliveCollection.performBatchUpdates(nil) { (result) in
                self.alivesIndicator.stopAnimating()
                self.shadowScroll.contentSize = CGSize(width: self.shadowScroll.contentSize.width, height: self.aliveCollection.frame.minY + self.aliveCollection.contentSize.height + 150) /// 150 accounts for navBar + extra space on bottom
            }
        }
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
                self.failedPosts = failedPosts
                if self.failedPosts.count == 0 { self.uploadsFetched += 1 }
                
                for post in failedPosts {
                    /// uploads fetched checks to make both failed spots and failed posts have been fetched before adding empty state
                    if post == failedPosts.last { self.uploadsFetched += 1 }
                    
                    ///if add-to-spot mode, only get failed uploads that are posts to this spot
                    if self.spotObject != nil {  if post.spotID != self.spotObject.id { continue } }
                    
                    let spotName = post.spotName
                    let timestampID = post.timestamp
                    let images = post.images! as! Set<ImageModel>
                    let firstImageData = images.first?.imageData
                    if firstImageData == nil {
                        self.deletePost(timestampID: timestampID, upload: false)
                    }
                    let image = UIImage(data: firstImageData! as Data) ?? UIImage()
                    
                    self.failedUploads.append((coverImage: image, spotName: spotName ?? "", timestampID: timestampID, type: "post"))
                    
                    DispatchQueue.main.async {
                        
                        if self.failedUploadCollection.frame.height == 0 {
                            self.unhideFailedUploads()
                        } else {
                            self.failedUploadCollection.reloadData()
                        }
                    }
                }
                
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }
        
        /// only get failed spot uploads if not in add-to-spot flow
        if self.spotObject != nil { self.uploadsFetched += 1; return }
        
        let spotsRequest = NSFetchRequest<SpotDraft>(entityName: "SpotDraft")
        spotsRequest.relationshipKeyPathsForPrefetching = ["images"]
        spotsRequest.returnsObjectsAsFaults = false
        let timeSort2 = NSSortDescriptor(key: "timestamp", ascending: false)
        spotsRequest.sortDescriptors = [timeSort2]
        spotsRequest.predicate = NSPredicate(format: "uid == %@", self.uid)
        
        
        DispatchQueue.global().async {

            do {
                let failedSpots = try managedContext.fetch(spotsRequest)
                self.failedSpots = failedSpots
                if self.failedSpots.count == 0 { self.uploadsFetched += 1 }

                for spot in failedSpots {
                    
                    if spot == failedSpots.last { self.uploadsFetched += 1 }

                    let spotName = spot.spotName
                    let timestampID = spot.timestamp
                    let images = spot.images! as! Set<ImageModel>
                    let firstImageData = images.first?.imageData
                    if firstImageData == nil {
                        self.deleteSpot(timestampID: timestampID, upload: false)
                    } else {
                        let image = UIImage(data: firstImageData! as Data) ?? UIImage()
                        
                        self.failedUploads.append((coverImage: image, spotName: spotName ?? "", timestampID: timestampID, type: "spot"))
                        
                        
                        DispatchQueue.main.async {
                            if self.failedUploadCollection.frame.height == 0 {
                                self.unhideFailedUploads()
                            } else {
                                self.failedUploadCollection.reloadData()
                            }
                        }
                    }
                }
                
            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }
    }
    
    func unhideFailedUploads() {

        self.failedUploadCollection.frame = CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 245)
        self.aliveCollection.frame = CGRect(x: 0, y: failedUploadCollection.frame.maxY + 50, width: self.aliveCollection.frame.width, height: self.aliveCollection.frame.height)
        self.failedUploadCollection.reloadData()
    }
    
    func hideFailedUploads() {
        
        self.failedUploadCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0)
        self.aliveCollection.frame = CGRect(x: 0, y: 35, width: self.aliveCollection.frame.width, height: self.aliveCollection.frame.height)
        if aliveDrafts.count == 0 { self.addEmptyState() }
        
    }
    
    @objc func removePreview(_ sender: UITapGestureRecognizer) {
        removePreview()
    }
    
    func removePreview() {
        if previewView == nil { return }
        previewView.removeFromSuperview()
        cityName.text = ""
        maskView.isHidden = true
        mainScroll.isUserInteractionEnabled = true
        navigationItem.rightBarButtonItem = nil
        selectedItem = 100000
    }
    
    @objc func deleteTapped(_ sender: UIButton) {
        
        let alert = UIAlertController(title: "Delete draft?",
                                      message: "",
                                      preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Delete",
                                       style: .default) {
                                        [unowned self] action in
                                        self.deleteDraft()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    func deleteDraft() {
            
        Mixpanel.mainInstance().track(event: "DraftsDeletedUpload")
        
        let draft = aliveDrafts[selectedItem]
        aliveDrafts.remove(at: selectedItem)
        if aliveDrafts.isEmpty { self.removeAlives() }
        
        removePreview()
        
        DispatchQueue.main.async { self.aliveCollection.reloadData() }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        let fetchRequest =
            NSFetchRequest<ImagesArray>(entityName: "ImagesArray")
        fetchRequest.predicate = NSPredicate(format: "id == %d", draft.1)
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
    
    func deleteUpload(item: Int) {
        let uploadObj = self.failedUploads[item]
        if uploadObj.type == "spot" {
            self.deleteSpot(timestampID: uploadObj.timestampID, upload: false)
        } else {
            self.deletePost(timestampID: uploadObj.timestampID, upload: false)
        }
    }
    
    func retryUpload(item: Int) {
        
        progressView.isHidden = false
        maskView.isHidden = false
        self.progressView.setProgress(0.1, animated: true)

        let uploadObj = self.failedUploads[item]
        
        if uploadObj.type == "spot" {
            if let spotObj = self.failedSpots.first(where: {$0.timestamp == uploadObj.timestampID}) {
                self.uploadSpot(spot: spotObj)
            }
            
        } else {
            if let postObj = self.failedPosts.first(where: {$0.timestamp == uploadObj.timestampID}) {
                self.uploadPost(post: postObj)
            }
        }
    }
    
    func deletePost(timestampID: Int64, upload: Bool) {
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
        
        if !upload {
            self.failedUploads.removeAll(where: {$0.timestampID == timestampID})
            self.failedPosts.removeAll(where: {$0.timestamp == timestampID
            })
            DispatchQueue.main.async {
                self.failedUploadCollection.reloadData()
            }
            
        }
        
        DispatchQueue.main.async {
            if self.failedUploads.isEmpty {
                self.hideFailedUploads()
                if self.aliveDrafts.isEmpty {
                    self.addEmptyState()
                }
            }
        }
    }
    
    func deleteSpot(timestampID: Int64, upload: Bool) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else { return }
        let managedContext =
            appDelegate.persistentContainer.viewContext
        let fetchRequest =
            NSFetchRequest<SpotDraft>(entityName: "SpotDraft")
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
        
        if !upload {
            self.failedUploads.removeAll(where: {$0.timestampID == timestampID})
            self.failedSpots.removeAll(where: {$0.timestamp == timestampID
            })
            DispatchQueue.main.async {
                self.failedUploadCollection.reloadData()
            }
        }
        
        DispatchQueue.main.async {
            if self.failedUploads.isEmpty {
                self.hideFailedUploads()
                if self.aliveDrafts.isEmpty {
                    self.addEmptyState()
                }
            }
        }
    }
    
    @objc func nextTapped(_ sender: UIBarButtonItem) {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "LocationPicker") as? LocationPickerController {
            
            Mixpanel.mainInstance().track(event: "DraftsGIFSelection")
            let draft = aliveDrafts[selectedItem]
            
            /// selected item represents the row selected before the gif preview appears
            let selectedImages = draft.0
            vc.mapVC = mapVC
            vc.spotObject = spotObject
            
            vc.selectedImages = selectedImages
            vc.frameIndexes = [0] /// always only one image grouping for drafts
            
            if aliveDrafts[selectedItem].2 != CLLocation() {
                /// gallery location sets location on location picker
                vc.galleryLocation = draft.2
            }
                
                            
            vc.postDate = Date(timeIntervalSince1970: TimeInterval(draft.1))
            vc.draftID = draft.1
            self.navigationController!.pushViewController(vc, animated: true)
        }
    }
    
    func removeAlives() {
        DispatchQueue.main.async {
            self.aliveCollection.frame = CGRect(x: self.aliveCollection.frame.minX, y: self.aliveCollection.frame.minY, width: self.aliveCollection.frame.width, height: 0)
            if self.failedUploads.isEmpty && self.uploadsFetched >= 2 { self.addEmptyState() }
        }
    }
        
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.isDescendant(of: self.previewView) ?? false {
            return false
        }
        return true
    }

}

extension DraftsViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 0 {
            return aliveDrafts.count
        } else {
            return failedUploads.count > 2 ? 2 : failedUploads.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AliveThumbnail", for: indexPath) as! AliveThumbnail
            if indexPath.row < aliveDrafts.count {
                let draft = aliveDrafts[indexPath.row]
                cell.setUpAll(image0: draft.0[0])
            }
            return cell
            
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FailedUploadCell", for: indexPath) as! FailedUploadCell
            if indexPath.row < failedUploads.count {
                let upload = failedUploads[indexPath.row]
                cell.setUp(coverImage: upload.coverImage, spotName: upload.spotName)
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return collectionView.tag == 0 ? 10 : 15
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.tag == 0 ? baseSize : failedSize
    }
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if collectionView.tag == 1 {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FailedUploadHeader", for: indexPath) as? FailedUploadHeader else { return UICollectionReusableView() }
            return header
        } else { return UICollectionReusableView() }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return collectionView.tag == 1 ? CGSize(width: UIScreen.main.bounds.width, height: 30) : CGSize.zero
    }
        
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if collectionView.tag == 0 {
            
            let draft = aliveDrafts[indexPath.row]
                        
            /// > 1 image = animatable gif
            if draft.0.count > 1 {
                DispatchQueue.main.async {
                    self.previewView.animationImages = draft.0
                    draft.0.count == 5 ? self.previewView.animate5FrameAlive(directionUp: true, counter: 0) : self.previewView.animateGIF(directionUp: true, counter: 0, frames: draft.0.count, alive: true)
                }
            } else { previewView.image = draft.0[0] }
            
            maskView.addSubview(previewView)
            reverseGeocodeFromCoordinate(numberOfFields: 2, location: draft.2) { (city) in
                self.cityName.text = city
            }
            
            maskView.isHidden = false
            mainScroll.isUserInteractionEnabled = false
            
            selectedItem = indexPath.row
            
            let nextBtn = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextTapped(_:)))
            nextBtn.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCamera-Semibold", size: 16) as Any, NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any], for: .normal)
            self.navigationItem.setRightBarButton(nextBtn, animated: true)
            self.navigationItem.rightBarButtonItem?.tintColor = nil

        } else {
            
            let alert = UIAlertController(title: "Retry upload?",
                                          message: "",
                                          preferredStyle: .alert)
            
            let retry = UIAlertAction(title: "Retry",
                                      style: .default) {
                                        [unowned self] action in
                                        self.retryUpload(item: indexPath.row)
            }
            let delete = UIAlertAction(title: "Delete",
                                       style: .destructive) {
                                        [unowned self] action in
                                        self.deleteUpload(item: indexPath.row)
            }
            
            let cancel = UIAlertAction(title: "Cancel",
                                       style: .cancel, handler: nil)
            
            alert.addAction(retry)
            alert.addAction(delete)
            alert.addAction(cancel)
            
            present(alert, animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
                        
        let yOffset = scrollView.contentOffset.y
        if scrollView.tag != 84 || emptyState || aliveCollection.frame.maxY < UIScreen.main.bounds.height - 150 { return }
        
        let sec0Height = aliveCollection.frame.minY
        
        DispatchQueue.main.async {
            
            if scrollView.contentOffset.y < sec0Height {
                /// scrollView offset hasn't hit the alive drafts collection yet so offset the mainScroll
                self.mainScroll.setContentOffset(CGPoint(x: self.mainScroll.contentOffset.x, y: yOffset), animated: false)
                /// set alives collection offset to 0
                self.aliveCollection.setContentOffset(CGPoint(x: self.aliveCollection.contentOffset.x, y: 0), animated: false)
            } else {
                /// main scroll won't offset more than aliveCollection minY
                self.mainScroll.setContentOffset(CGPoint(x: self.mainScroll.contentOffset.x, y: sec0Height), animated: false)
                /// offset alives collection
                self.aliveCollection.setContentOffset(CGPoint(x: self.aliveCollection.contentOffset.x, y: yOffset - sec0Height), animated: false)
            }
        }
    }
}

class AliveThumbnail: UICollectionViewCell {
    var aliveImage: UIImageView!
    
    func setUpAll(image0: UIImage) {
        if aliveImage != nil { aliveImage.image = UIImage() }
        
        aliveImage = UIImageView(frame: self.bounds)
        aliveImage.image = image0
        aliveImage.layer.cornerRadius = 7
        aliveImage.contentMode = .scaleAspectFill
        aliveImage.layer.masksToBounds = true
        aliveImage.clipsToBounds = true
        self.addSubview(aliveImage)
    }
}

extension DraftsViewController {
    
    func uploadPost(post: PostDraft) {
        
        // save post to spots -> feedpost
        let postID = UUID().uuidString
        
        let model = post.images! as! Set<ImageModel>
        let mod = model.sorted(by: {$0.position < $1.position})
        
        var uploadImages: [Data] = []
        
        for i in 0...mod.count - 1 {
            let im = mod[i]
            let imageData = im.imageData
            uploadImages.append(imageData!)
        }
        
        var city = post.city ?? ""
        if city == "" {
            self.reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: post.postLat, longitude: post.postLong)) { (postCity) in
                city = postCity
            }
        }
        
        self.uploadPostImage(uploadImages, postID: postID) { (imageURLs) in
            
            if imageURLs.isEmpty {  self.uploadFailed(); return }
            
            let interval = NSDate().timeIntervalSince1970
            let myTimeInterval = TimeInterval(interval)
            let timestamp = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
            let actualTimestamp = Date(timeIntervalSince1970: TimeInterval(post.timestamp))

            var finalInvites = post.inviteList ?? []
            finalInvites.append(self.uid)

            var postFriends: [String] = []
            if !post.hideFromFeed {
                postFriends = post.privacyLevel == "invite" ? finalInvites.filter(self.mapVC.friendIDs.contains) : self.mapVC.friendIDs
                if !postFriends.contains(self.uid) { postFriends.append(self.uid) }
            }
            
            var aspectRatios: [CGFloat] = []
            for index in post.frameIndexes ?? [] {
                let image = UIImage(data: uploadImages[index]) ?? UIImage()
                aspectRatios.append(image.size.height/image.size.width)
            }
            
            let postValues = ["caption" : post.caption ?? "",
                              "posterID": self.uid,
                              "likers": [],
                              "timestamp": timestamp,
                              "actualTimestamp": actualTimestamp,
                              "taggedUsers": post.taggedUsers ?? [],
                              "postLat": post.postLat,
                              "postLong": post.postLong,
                              "privacyLevel": post.privacyLevel ?? "friends",
                              "imageURLs" : imageURLs,
                              "spotName" : post.spotName ?? "",
                              "createdBy": post.createdBy ?? "",
                              "city" : city,
                              "inviteList" : finalInvites,
                              "friendsList" : postFriends,
                              "spotID": post.spotID ?? "",
                              "spotLat": post.spotLat,
                              "spotLong": post.spotLong,
                              "isFirst": false,
                              "spotPrivacy" : post.spotPrivacy ?? "",
                              "hideFromFeed": post.hideFromFeed,
                              "frameIndexes": post.frameIndexes ?? [],
                              "aspectRatios": aspectRatios,
                              "gif": post.gif] as [String : Any]
            
            let commentValues = ["commenterID" : self.uid,
                                 "comment" : post.caption ?? "",
                                 "timestamp" : timestamp,
                                 "taggedUsers": post.taggedUsers ?? []] as [String : Any]

            let commentID = UUID().uuidString
            let commentObject = MapComment(id: commentID, comment: post.caption ?? "", commenterID: self.uid, timestamp: Timestamp(date: timestamp as Date), userInfo: self.mapVC.userInfo, taggedUsers: post.taggedUsers ?? [], commentHeight: self.getCommentHeight(comment: post.caption ?? ""), seconds: Int64(interval))
            
            var postImages: [UIImage] = []
            guard let model = post.images as? Set<ImageModel> else { self.uploadFailed(); return }
            let mod = model.sorted(by: {$0.position < $1.position})
            
            for i in 0...mod.count - 1 {
                let im = mod[i]
                let imageData = im.imageData
                let image = UIImage(data: imageData! as Data) ?? UIImage()
                postImages.append(image)
            }
            
            var postObject = MapPost(id: postID, caption: post.caption ?? "", postLat: post.postLat, postLong: post.postLong, posterID: self.uid, timestamp: Timestamp(date: timestamp as Date), userInfo: self.mapVC.userInfo, spotID: post.spotID ?? "", city: city, frameIndexes: post.frameIndexes, aspectRatios: aspectRatios, imageURLs: imageURLs, postImage: postImages, seconds: Int64(interval), selectedImageIndex: 0, commentList: [commentObject], likers: [], taggedUsers: post.taggedUsers, spotName: post.spotName ?? "", spotLat: post.spotLat, spotLong: post.spotLong, privacyLevel: post.privacyLevel, spotPrivacy: post.spotPrivacy ?? "friends", createdBy: self.uid, inviteList: post.inviteList ?? [])
            postObject.friendsList = postFriends
            
            NotificationCenter.default.post(Notification(name: Notification.Name("NewPost"), object: nil, userInfo: ["post" : postObject]))
            
            self.db.collection("posts").document(postID).setData(postValues)
            self.db.collection("posts").document(postID).collection("comments").document(commentID).setData(commentValues, merge:true)
            self.setPostLocations(postLocation: CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong), postID: postID)

            /// add to users spotslist if not already there
            if post.visitorList != nil && post.visitorList!.contains(where: {$0 == self.uid}) {
                self.db.collection("users").document(self.uid).collection("spotsList").document(post.spotID!).updateData(["postsList" : FieldValue.arrayUnion([postID])])
            } else {
                self.db.collection("users").document(self.uid).collection("spotsList").document(post.spotID!).setData(["spotID" : post.spotID!, "checkInTime" : timestamp, "postsList" : [postID], "city": city], merge:true)
            }
            
            if post.createdBy != nil { self.incrementSpotScore(user: post.createdBy!, increment: 1) }
            self.incrementSpotScore(user: self.uid, increment: 3)

            self.runSpotTransactions(spotID: post.spotID!, postPrivacy: post.privacyLevel ?? "friends", postID: postID, timestamp: timestamp as Date, post: post)
        }
    }
    
    func runSpotTransactions(spotID: String, postPrivacy: String, postID: String, timestamp: Date, post: PostDraft) {
        
        let db = Firestore.firestore()
        let ref = db.collection("spots").document(spotID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let spotDoc: DocumentSnapshot
            do {
                try spotDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var posterIDs = spotDoc.data()?["posterIDs"] as? [String] ?? []
            posterIDs.append(self.uid)
            
            var postPrivacies = spotDoc.data()?["postPrivacies"] as? [String] ?? []
            postPrivacies.append(postPrivacy)
            
            var visitorList = spotDoc.data()?["visitorList"] as? [String] ?? []
            if !visitorList.contains(self.uid) { visitorList.append(self.uid) }
            
            var postIDs = spotDoc.data()?["postIDs"] as? [String] ?? []
            postIDs.append(postID)
            
            var postTimestamps = spotDoc.data()?["postTimestamps"] as? [Firebase.Timestamp] ?? []
            let firTimestamp = Firebase.Timestamp(date: timestamp as Date)
            postTimestamps.append(firTimestamp)
                        
            transaction.updateData([
                "posterIDs": posterIDs,
                "postPrivacies" : postPrivacies,
                "visitorList" : visitorList,
                "postIDs" : postIDs,
                "postTimestamps" : postTimestamps,
            ], forDocument: ref)
            
            return nil
            
        }) { (object, error) in
            self.finishPostUpload(post: post)
        }
    }

        
    func uploadSpot(spot: SpotDraft) {
        /// upload to posts

        // save post to spots -> feedpost
        let postID = UUID().uuidString
        
        let model = spot.images! as! Set<ImageModel>
        let mod = model.sorted(by: {$0.position < $1.position})
        
        var uploadImages: [Data] = []
        
        for i in 0...mod.count - 1 {
            let im = mod[i]
            let imageData = im.imageData
            uploadImages.append(imageData!)
        }
        
        var city = ""
        self.reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)) { (spotCity) in
            city = spotCity
        }

        self.uploadPostImage(uploadImages, postID: postID) { (imageURLs) in
            
            if imageURLs.isEmpty { self.uploadFailed(); return }

            self.checkForPOI(spot: spot) { (duplicateID) in
                
                let interval = Date().timeIntervalSince1970
                let myTimeInterval = TimeInterval(interval)
                let timestamp = Date(timeIntervalSince1970: TimeInterval(myTimeInterval))
                let actualTimestamp = Date(timeIntervalSince1970: TimeInterval(spot.timestamp))
                
                let spotPrivacy = spot.postToPOI ? "public" : spot.privacyLevel ?? "friends"
                let postPrivacy = spot.privacyLevel ?? "friends"
                
                var finalInvites = spot.inviteList ?? []
                if spot.privacyLevel == "invite" { finalInvites.append(self.uid) }
                
                
                var postFriends: [String] = []
                if !spot.hideFromFeed {
                    postFriends = spot.privacyLevel == "invite" ? finalInvites.filter(self.mapVC.friendIDs.contains) : self.mapVC.friendIDs
                    if !postFriends.contains(self.uid) { postFriends.append(self.uid) }
                }
                
                var aspectRatios: [CGFloat] = []
                for index in spot.frameIndexes ?? [] {
                    let image = UIImage(data: uploadImages[index]) ?? UIImage()
                    aspectRatios.append(image.size.height/image.size.width)
                }

                let postValues = ["caption" : spot.spotDescription ?? "",
                                  "posterID": self.uid,
                                  "likers": [],
                                  "timestamp": timestamp,
                                  "actualTimestamp": actualTimestamp,
                                  "taggedUsers": spot.taggedUsernames ?? [],
                                  "postLat": spot.postLat,
                                  "postLong": spot.postLong,
                                  "privacyLevel": postPrivacy,
                                  "imageURLs" : imageURLs,
                                  "spotName" : spot.spotName ?? "",
                                  "createdBy": self.uid ,
                                  "city" : city,
                                  "inviteList" : finalInvites,
                                  "friendsList" : postFriends,
                                  "spotID": spot.spotID ?? "",
                                  "spotLat": spot.spotLat,
                                  "spotLong": spot.spotLong,
                                  "isFirst": true,
                                  "spotPrivacy" : spotPrivacy,
                                  "hideFromFeed": spot.hideFromFeed,
                                  "frameIndexes": spot.frameIndexes ?? [],
                                  "aspectRatios": aspectRatios,
                                  "gif": spot.gif] as [String : Any]
                
                let commentValues = ["commenterID" : self.uid,
                                     "comment" : spot.spotDescription ?? "",
                                     "timestamp" : timestamp,
                                     "taggedUsers": spot.taggedUsernames ?? []] as [String : Any]

                let commentID = UUID().uuidString
                let commentObject = MapComment(id: commentID, comment: spot.spotDescription ?? "", commenterID: self.uid, timestamp: Timestamp(date: timestamp as Date), userInfo: self.mapVC.userInfo, taggedUsers: spot.taggedUsernames ?? [], commentHeight: self.getCommentHeight(comment: spot.spotDescription ?? ""), seconds: Int64(interval))
                
                var postImages: [UIImage] = []
                let model = spot.images! as! Set<ImageModel> /// crash inducing line 
                let mod = model.sorted(by: {$0.position < $1.position})
                
                for i in 0...mod.count - 1 {
                    let im = mod[i]
                    let imageData = im.imageData
                    let image = UIImage(data: imageData! as Data) ?? UIImage()
                    postImages.append(image)
                }
                
                var postObject = MapPost(id: postID, caption: spot.spotDescription ?? "", postLat: spot.spotLat, postLong: spot.spotLong, posterID: self.uid, timestamp: Timestamp(date: timestamp as Date), userInfo: self.mapVC.userInfo, spotID: spot.spotID ?? "", city: city, frameIndexes: spot.frameIndexes, aspectRatios: aspectRatios, imageURLs: imageURLs, postImage: postImages, seconds: Int64(interval), selectedImageIndex: 0, commentList: [commentObject], likers: [], taggedUsers: spot.taggedUsernames, spotName: spot.spotName ?? "", spotLat: spot.spotLat, spotLong: spot.spotLong, privacyLevel: spot.privacyLevel ?? "friends", spotPrivacy: spot.privacyLevel ?? "friends", createdBy: self.uid, inviteList: spot.inviteList ?? [])
                postObject.friendsList = postFriends
                
                NotificationCenter.default.post(Notification(name: Notification.Name("NewPost"), object: nil, userInfo: ["post" : postObject]))
                
                
                self.db.collection("posts").document(postID).setData(postValues)
                self.db.collection("posts").document(postID).collection("comments").document(commentID).setData(commentValues, merge:true)
                self.setPostLocations(postLocation: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), postID: postID)

                ///upload spot
                
                let lowercaseName = spot.spotName?.lowercased() ?? ""
                let keywords = lowercaseName.getKeywordArray()
                
                let spotValues =  ["city" : city,
                                   "spotName" : spot.spotName ?? "",
                                   "lowercaseName": lowercaseName,
                                   "description": spot.spotDescription ?? "",
                                   "tags": spot.tags ?? [],
                                   "createdBy": self.uid,
                                   "visitorList": [self.uid],
                                   "inviteList" : finalInvites,
                                   "privacyLevel": spotPrivacy,
                                   "taggedUsers": spot.taggedUsernames ?? [],
                                   "spotLat": spot.spotLat,
                                   "spotLong" : spot.spotLong,
                                   "imageURL" : imageURLs.first ?? "",
                                   "phone": spot.phone as Any,
                                   "postIDs": [postID],
                                   "postTimestamps": [timestamp],
                                   "posterIDs": [self.uid],
                                   "postPrivacies": [spot.privacyLevel ?? "friends"],
                                   "searchKeywords": keywords] as [String : Any]
                
                let spotID = duplicateID == "" ? spot.spotID! : duplicateID
                
                if duplicateID == "" { self.db.collection("spots").document(spotID).setData(spotValues, merge: true) }
                
                self.db.collection("users").document(self.uid).collection("spotsList").document(spotID).setData(["spotID" : spotID, "checkInTime" : timestamp, "postsList" : [postID], "city": city], merge:true)
                
                /// set spot for public submission
                if spot.submitPublic { self.db.collection("submissions").document(spotID).setData(["spotID" : spotID]) }
                
                if duplicateID == "" { self.setSpotLocations(spotLocation: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), spotID: spotID) }
                
                var spotObject = MapSpot(id: spotID, spotDescription: spot.spotDescription ?? "", spotName: spot.spotName ?? "", spotLat: spot.spotLat, spotLong: spot.spotLong, founderID: self.uid, privacyLevel: spot.privacyLevel ?? "friends", visitorList: [self.uid], inviteList: spot.inviteList ?? [], tags: spot.tags ?? [], imageURL: imageURLs.first ?? "", spotImage: postImages.first ?? UIImage(), taggedUsers: spot.taggedUsernames ?? [], city: city, friendVisitors: 0, distance: 0)
                spotObject.checkInTime = Int64(interval)
                
                /// send notifications if this is an invite only spot
                self.sendInviteNotis(spotObject: spotObject, postObject: postObject, username: self.mapVC.userInfo.username)

                /// add city to list of cities if this is the first post there
                DispatchQueue.global().async { self.addToCityList(city: city) }
                
                /// increment users spotScore
                self.incrementSpotScore(user: self.uid, increment: 6)

                NotificationCenter.default.post(name: NSNotification.Name("NewSpot"), object: nil, userInfo: ["spot" : spotObject])
                self.finishSpotUpload(spot: spot)
            }
        }
    }
    
    func finishPostUpload(post: PostDraft) {
        
        self.progressView.setProgress(1.0, animated: true)
        self.progressView.isHidden = true
        self.maskView.isHidden = true
        
        self.failedPosts.removeAll(where: {$0.timestamp == post.timestamp})
        self.failedUploads.removeAll(where: {$0.timestampID == post.timestamp})
        self.deletePost(timestampID: post.timestamp, upload: true)
        
        Mixpanel.mainInstance().track(event: "DraftSuccessfulUpload", properties: ["type": "post"])
        let alert = UIAlertController(title: "Post successfully uploaded",
                                             message: "",
                                             preferredStyle: .alert)
               
         let okBtn = UIAlertAction(title: "OK",
                                         style: .cancel)
         alert.addAction(okBtn)
         DispatchQueue.main.async {
             self.present(alert, animated: true)
             self.failedUploadCollection.reloadData()
        }
    }
    
    func finishSpotUpload(spot: SpotDraft) {
        
        self.progressView.setProgress(1.0, animated: true)
        self.progressView.isHidden = true
        self.maskView.isHidden = true
        
        self.failedSpots.removeAll(where: {$0.timestamp == spot.timestamp})
        self.failedUploads.removeAll(where: {$0.timestampID == spot.timestamp})
        self.deleteSpot(timestampID: spot.timestamp, upload: true)

        Mixpanel.mainInstance().track(event: "DraftSuccessfulUpload", properties: ["type": "spot"])
        let alert = UIAlertController(title: "Spot successfully uploaded",
                                             message: "",
                                             preferredStyle: .alert)
               
         let okBtn = UIAlertAction(title: "OK",
                                         style: .cancel)
         alert.addAction(okBtn)
         DispatchQueue.main.async {
             self.present(alert, animated: true)
             self.failedUploadCollection.reloadData()
        }
    }
    
    func uploadPostImage(_ imageData: [Data], postID: String, completion: @escaping ((_ urls: [String]) -> ())){
        var index = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self else { return }
            if self.progressView.progress != 1.0 {
                completion([])
                return
            }
        }
        
        var progress = 0.7/Double(imageData.count)
        var URLs: [String] = []
        for _ in imageData {
            URLs.append("")
        }
        for image in imageData {
            let imageID = UUID().uuidString
            let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageID)")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            storageRef.putData(image, metadata: metadata){metadata, error in
                if error != nil { completion([]); return }
                storageRef.downloadURL { [weak self] (url, err) in
                    
                    guard let self = self else { return }
                    
                    if error != nil { completion([]); return }
                    let urlString = url!.absoluteString
                    
                    let i = imageData.lastIndex(where: {$0 == image})
                    URLs[i ?? 0] = urlString
                    
                    DispatchQueue.main.async { self.progressView.setProgress(Float(0.3 + progress), animated: true) }
                    progress = progress * Double(index + 1)
                    
                    index += 1
                    if index == imageData.count {
                        DispatchQueue.main.async {
                            completion(URLs)
                            return
                        }
                    }
                }
            }
        }
    }
    
    func checkForPOI(spot: SpotDraft, completion: @escaping(_ id: String) -> () ) {
        
        if !spot.postToPOI { completion(""); return }
        
        db.collection("spots").whereField("spotName", isEqualTo: spot.spotName ?? "").getDocuments { [weak self] (snap, err) in
            
            guard let self = self else { return }
            
            if snap?.documents.count == 0 || err != nil { completion(""); return }
            
            for doc in snap!.documents {
                
                do {
                    
                    let spotInfo = try doc.data(as: MapSpot.self)
                    guard let querySpot = spotInfo else { completion(""); return }
                    
                    if spot.privacyLevel == "public" && self.locationsClose(coordinate1: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), coordinate2: CLLocationCoordinate2D(latitude: querySpot.spotLat, longitude: querySpot.spotLong)) {
                        completion(doc.documentID); return
                        
                    } else { completion(""); return }
                    
                } catch { completion(""); return }
            }
        }
    }
    
    func locationsClose(coordinate1: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) -> Bool {
        /// run to ensure that this is actually the same spot and not just one with the same name
        if abs(coordinate1.latitude - coordinate2.latitude) + abs(coordinate1.longitude - coordinate2.longitude) < 0.01 { return true }
        return false
    }

    func uploadFailed() {
        Mixpanel.mainInstance().track(event: "DraftFailedUpload")
        
        let alert = UIAlertController(title: "Upload failed",
                                      message: "Try again with better connection",
                                      preferredStyle: .alert)
        
        let okBtn = UIAlertAction(title: "OK",
                                  style: .cancel)
        alert.addAction(okBtn)
        DispatchQueue.main.async {
            self.present(alert, animated: true)
            self.progressView.isHidden = true
            self.maskView.isHidden = true
        }
    }
}

class FailedUploadCell: UICollectionViewCell {
    var imagePreview: UIImageView!
    var spotNameLabel: UILabel!
    
    func setUp(coverImage: UIImage, spotName: String) {
        if imagePreview != nil { imagePreview.image = UIImage() }
        imagePreview = UIImageView(frame: CGRect(x: 0, y: 12, width: 108, height: 160))
        imagePreview.image = (coverImage)
        imagePreview.layer.cornerRadius = 7
        imagePreview.contentMode = .scaleAspectFill
        imagePreview.clipsToBounds = true
        self.addSubview(imagePreview)
        
        if spotNameLabel != nil { spotNameLabel.text = "" }
        spotNameLabel = UILabel(frame: CGRect(x: 1, y: 183, width: 106, height: 18))
        spotNameLabel.font = UIFont(name: "SFCamera-Regular", size : 12)
        spotNameLabel.textColor = UIColor(red:0.82, green:0.82, blue:0.82, alpha:1.0)
        spotNameLabel.lineBreakMode = .byWordWrapping
        spotNameLabel.numberOfLines = 0
        spotNameLabel.text = spotName
        spotNameLabel.sizeToFit()
        self.addSubview(spotNameLabel)
        
        let alert = UIImageView(frame: CGRect(x: 96, y: 0, width: 24, height: 24))
        alert.image = UIImage(named: "DraftAlert")
        alert.contentMode = .scaleAspectFit
        self.addSubview(alert)
    }
}

class FailedUploadHeader: UICollectionReusableView {
    
    var label: UILabel!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 6, y: 0, width: 100, height: 16))
        label.text = "Failed Uploads"
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 14)
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
