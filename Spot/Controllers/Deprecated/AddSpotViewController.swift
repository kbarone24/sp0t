//
//  AddSpotViewController.swift
//  Spot
//
//  Created by kbarone on 2/24/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import MapKit
import Geofirestore
import Photos
import RSKImageCropper


protocol AddSpotDelegate {
    func FinishPassing(newSpot: NewSpot)
}

class AddSpotViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    let db: Firestore! = Firestore.firestore()
    
    let userId = Auth.auth().currentUser?.uid
    
    var passedSpotImages: [UIImage] = []
    var selectedImageView: UIImageView!
    var nextImageView: UIImageView!
    var previousImageView: UIImageView!
    var selectedImageIndex = 0
    
    var nameTextField : UITextField!
    var descriptionTextField: UITextView!
    
    var tagsLabel : UILabel!
    var tagScroll = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var tagLayout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    let imgPicker = UIImagePickerController()
    
    var tags: [(UIImage, String, Bool)] = []
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    let locationManager : CLLocationManager = CLLocationManager()
    var currentLocation : CLLocation!
    
    var passedLocation : CLLocation!
    var spotLocationRaw : CLLocation!
    
    var errorBox : UIView!
    var errorTextLayer: UILabel!
    
    var delegate: AddSpotDelegate?
    var delegateObject: (CLLocationCoordinate2D, UIImage, String) =  (CLLocationCoordinate2D(latitude: 0, longitude: 0), UIImage(), "")
    
    var newSpot = NewSpot(name: "", description: "", directions: "", spotLat: 0, spotLong: 0, tag1: "", tag2: "", tag3: "", createdBy: "", tips: "", visitorList: [], spotImages: [UIImage](), gifMode: false, selectedUsers: [(uid: "", username: "")], draftID: 0)
        
    let newSpotPostNotificationName = Notification.Name("newSpotPost")
    let newSpotNotificationName = Notification.Name("newSpot")
    let addSpotNotificatioName = Notification.Name("addSpotPass")
    
    var maskView: UIView!
    
    var start: CFAbsoluteTime!
    
    var progressView: UIProgressView!
    var shouldUploadPost: Bool!
    
    var imageFromCamera = false
    var dotView: UIView!
    
    var friendsListRaw: [String] = []
    var friendsList: [(uid: String, username: String, name: String)] = []
    
    var queryObject: [(name: String, username: String)] = []
    
    var queried = false
    var resultsView: UITableView!
    
    var resultsMask: UIView!
    
    var listener1, listener2: ListenerRegistration!
    
    var largeScreen = false
    
    var activityIndicatorView: CustomActivityIndicator!
    
    var gifMode = false
    var constantHeight: CGFloat = 104.0
    
    var draftID: Int64!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        start = CFAbsoluteTimeGetCurrent()
        
        shouldUploadPost = true
        //Get User's current location
        if CLLocationManager.locationServicesEnabled() == true{
            if CLLocationManager.authorizationStatus() == .restricted ||
                CLLocationManager.authorizationStatus() == .denied ||
                CLLocationManager.authorizationStatus() == .notDetermined{
                
                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.desiredAccuracy = 1.0
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
            currentLocation = locationManager.location
            
        }else{
            locationManager.requestWhenInUseAuthorization()
        }
        
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(named: "TopNav"), for: .default)
        
        self.setUpFields()
        self.getFriends()
        //  self.checkForTutorial()
    }
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(false)
        
        self.navigationItem.backBarButtonItem?.title = ""
        
        if let tabArray = self.tabBarController?.tabBar.items {
            let tabBarItem1 = tabArray[1]
            let tabBarItem2 = tabArray[2]
            
            tabBarItem1.isEnabled = true
            tabBarItem2.isEnabled = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if listener1 != nil {listener1.remove()}
       
        if listener2 != nil {listener2.remove()}
    }
    func setUpFields() {
        
              if (UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792) {
                  errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 130, width: UIScreen.main.bounds.width, height: 32))
                  errorTextLayer = UILabel(frame: CGRect(x: 30, y: UIScreen.main.bounds.height - 124, width: UIScreen.main.bounds.width - 46, height: 18))
                  largeScreen = true
              } else {
                  errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 100, width: UIScreen.main.bounds.width, height: 32))
                  errorTextLayer = UILabel(frame: CGRect(x: 30, y: UIScreen.main.bounds.height - 94, width: UIScreen.main.bounds.width - 46, height: 18))
                constantHeight = 79.0
              }
              
        
        let nextImage = UIImage(named: "NextButton")!
        nextImage.withRenderingMode(.alwaysOriginal)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: nextImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(nextTapped))
        self.navigationItem.rightBarButtonItem?.tintColor = nil
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: self, action: nil)
        
        
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        self.navigationItem.title = "Create Spot"
        
        if passedLocation != nil {
            spotLocationRaw = passedLocation
        } else {
            spotLocationRaw = CLLocation(latitude: 0, longitude: 0)
        }
        
        selectedImageView = UIImageView(frame: CGRect(x: 15, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3))
        selectedImageView.contentMode = .scaleAspectFit
        selectedImageView.isUserInteractionEnabled = true
        view.addSubview(selectedImageView)
        
        nextImageView = UIImageView(frame: CGRect(x: 15 + UIScreen.main.bounds.width, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3))
        nextImageView.contentMode = .scaleAspectFit
        nextImageView.isUserInteractionEnabled = true
        view.addSubview(nextImageView)
        
        previousImageView = UIImageView(frame: CGRect(x: -(15 + UIScreen.main.bounds.width), y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3))
        previousImageView.contentMode = .scaleAspectFit
        previousImageView.isUserInteractionEnabled = true
        view.addSubview(previousImageView)
        
        
        if (!passedSpotImages.isEmpty && !gifMode) {
            self.selectedImageView.image = passedSpotImages[0]
            selectedImageView.roundCornersForAspectFit(radius: 8)
            
            if passedSpotImages.count > 1 {
                let swipe = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
                swipe.cancelsTouchesInView = false
                self.selectedImageView.addGestureRecognizer(swipe)
                nextImageView.image = passedSpotImages[1]
                self.nextImageView.roundCornersForAspectFit(radius: 8)
            }
            
            self.selectedImageIndex = 0
            
            if self.passedSpotImages.count > 1 { self.setUpDotView(count: self.passedSpotImages.count) }
        }
        
        if self.gifMode {
            self.selectedImageView.image = passedSpotImages[0]
            selectedImageView.roundCornersForAspectFit(radius: 8)
            selectedImageView.animateGIF(directionUp: true, counter: 0, photos: passedSpotImages)
        }
        
        nameTextField = UITextField(frame: CGRect(x: 19, y: selectedImageView.frame.maxY + 15, width: UIScreen.main.bounds.width - 30, height: 30))
        nameTextField.textColor = UIColor(named: "SpotGreen")
        nameTextField.textAlignment = .left
        var textStr = ""
        if self.newSpot.name == "" {
            textStr = "Spot name"
        } else {
            textStr = self.newSpot.name
        }
        nameTextField.attributedText =  NSAttributedString(string: textStr, attributes: [NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any])
        nameTextField.font = UIFont(name: "SFCamera-Semibold", size: 21)!
        nameTextField.alpha = 0.75
        nameTextField.autocorrectionType = .no
        nameTextField.delegate = self
        nameTextField.accessibilityHint = "name"
        
        view.addSubview(nameTextField)
        
        descriptionTextField = UITextView(frame: CGRect(x: 15, y: nameTextField.frame.maxY, width: UIScreen.main.bounds.width - 30, height: 70))
        descriptionTextField.delegate = self
        descriptionTextField.accessibilityLabel = "description"
        descriptionTextField.textAlignment = .left
        descriptionTextField.backgroundColor = nil 
        descriptionTextField.text = "Add a description..."
        
        descriptionTextField.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        descriptionTextField.alpha = 0.65
        descriptionTextField.font = UIFont(name: "SFCamera-regular", size: 14)!
        descriptionTextField.isScrollEnabled = false
        descriptionTextField.textContainer.lineBreakMode = .byTruncatingHead
        descriptionTextField.keyboardDistanceFromTextField = 100

        view.addSubview(descriptionTextField)
        
        //tag label
        
        tagsLabel = UILabel(frame: CGRect(x: 20, y: descriptionTextField.frame.maxY + 20, width: 298, height: 29))
        tagsLabel.textColor = UIColor.lightGray
        tagsLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)!
        tagsLabel.text = "Add Tags"
        tagsLabel.sizeToFit()
        view.addSubview(tagsLabel)
        
        tagScroll = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
        tagLayout = UICollectionViewFlowLayout.init()
        
        tagLayout.scrollDirection = .horizontal
        tagLayout.itemSize = CGSize(width: 69, height: 57)
        tagLayout.minimumInteritemSpacing = 30
        tagLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        tagScroll.setCollectionViewLayout(tagLayout, animated: false)
        tagScroll.delegate = self
        tagScroll.dataSource = self
        tagScroll.backgroundColor = nil
        tagScroll.accessibilityLabel = "tags"
        tagScroll.showsHorizontalScrollIndicator = false
        tagScroll.frame = CGRect(x: 0, y: tagsLabel.frame.maxY + 5, width: UIScreen.main.bounds.width, height: 60)
        view.addSubview(tagScroll)
        tagScroll.register(TagCell.self, forCellWithReuseIdentifier: "tagCell")
        
        // setUpTagScroll()
        tags = [(UIImage(named: "ActiveTag")!, "Active", false), (UIImage(named: "ArtTag")!, "Art", false), (UIImage(named: "DrinkTag")!, "Drink", false), (UIImage(named: "FoodTag")!, "Food", false), (UIImage(named: "NatureTag")!, "Nature", false), (UIImage(named: "NitelifeTag")!, "Nitelife", false), (UIImage(named: "RelaxTag")!, "Relax", false), (UIImage(named: "ShopTag")!, "Shop", false), (UIImage(named: "SunsetTag")!, "Sunset", false), (UIImage(named: "WeirdTag")!, "Weird", false), (UIImage(named: "WorkTag")!, "Work", false)]
        if self.newSpot.tag1 != "" {
            for i in 0...tags.count - 1 {
                if self.newSpot.tag1 == tags[i].1 || self.newSpot.tag2 == tags[i].1 || self.newSpot.tag3 == tags[i].1 {
                    tags[i].2 = true
                }
            }
        }
        
        tagScroll.reloadData()
      
        
        errorBox.backgroundColor = UIColor(red:0.35, green:0, blue:0.04, alpha:1)
        self.view.addSubview(errorBox)
        errorBox.isHidden = true
        
        //Load error text
        errorTextLayer.lineBreakMode = .byWordWrapping
        errorTextLayer.numberOfLines = 0
        errorTextLayer.textColor = UIColor.white
        errorTextLayer.textAlignment = .center
        let errorTextContent = "this is a generic placeholder error message"
        let errorTextString = NSMutableAttributedString(string: errorTextContent, attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCamera-regular", size: 14)!
        ])
        let errorTextRange = NSRange(location: 0, length: errorTextString.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.14
        errorTextString.addAttribute(NSAttributedString.Key.paragraphStyle, value:paragraphStyle, range: errorTextRange)
        errorTextLayer.attributedText = errorTextString
        //  errorTextLayer.sizeToFit()
        self.view.addSubview(errorTextLayer)
        errorTextLayer.isHidden = true
        
        // Do any additional setup after loading the view.
        
        maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        
        maskView.accessibilityIdentifier = "maskView"
        maskView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        maskView.isUserInteractionEnabled = false
        maskView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        maskView.isHidden = true
        
        view.addSubview(maskView)
        
        progressView = UIProgressView(frame: CGRect(x: 50, y: 370, width: UIScreen.main.bounds.width - 100, height: 20))
        progressView.heightAnchor.constraint(equalToConstant: 10).isActive = true
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 10)
        
        progressView.layer.cornerRadius = 5
        
        progressView.layer.sublayers![1].cornerRadius = 5
        progressView.subviews[1].clipsToBounds = true
        
        progressView.clipsToBounds = true
        
        //progressView.layoutSubviews()
        progressView.isHidden = true
        progressView.progressTintColor = UIColor(named: "SpotGreen")
        progressView.progress = 0.0
        view.addSubview(progressView)
        
        
        resultsMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: descriptionTextField.frame.minY + 2))
        resultsMask.backgroundColor = UIColor(named: "SpotBlack")
        resultsMask.isHidden = true
        view.addSubview(resultsMask)
        
        resultsView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 200))
        resultsView.backgroundColor = UIColor(named: "SpotBlack")
        resultsView.separatorStyle = .none
        resultsView.dataSource = self
        resultsView.delegate = self
        resultsView.register(resultsCell.self, forCellReuseIdentifier: "resultsCell")
        resultsView.isHidden = true
        resultsView.allowsSelection = true
        view.addSubview(resultsView)
        
        activityIndicatorView = CustomActivityIndicator(frame: CGRect(x: 0, y: resultsMask.frame.maxY - 60, width: UIScreen.main.bounds.width, height: 40))
        resultsView.addSubview(activityIndicatorView)
    }
    
    func getFriends() {
        listener1 = self.db.collection("users").document(self.uid).addSnapshotListener { (snapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                self.friendsListRaw =  snapshot?.get("friendsList") as! [String]
                for friend in self.friendsListRaw {
                    self.listener2 = self.db.collection("users").document(friend).addSnapshotListener { (snap, err) in
                        if err != nil {
                            return
                        } else {
                            if let name = snap!.get("name") as? String {
                                let username = snap!.get("username") as! String
                                self.friendsList.append((uid: friend, username: username, name: name))
                            }
                        }
                    }
                }
            }
        }
    }
    
    func setUpDotView(count: Int) {
        if dotView != nil {self.dotView.removeFromSuperview()}
        let dotY = self.selectedImageView.frame.maxY + 5
        dotView = UIView(frame: CGRect(x: 0, y: dotY, width: UIScreen.main.bounds.width, height: 10))
        dotView.backgroundColor = nil
        view.addSubview(dotView)
        
        var i = 1.0
        var xOffset = CGFloat(3.5 + (Double(count - 1) * 5.5))
        while i <= Double(count) {
            let view = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - xOffset, y: 0, width: 7, height: 7))
            view.layer.cornerRadius = 3.5
            
            if i == Double(self.selectedImageIndex + 1) {
                view.image = UIImage(named: "ElipsesFilled")
            } else {
                view.image = UIImage(named: "ElipsesUnfilled")
            }
            dotView.addSubview(view)
            
            i = i + 1.0
            xOffset = xOffset - 11
        }
    }
    
    
    //func reloadScrollView(tagClick: Int) {}
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.alpha < 0.7 {
            textView.text = nil
            textView.alpha = 1.0
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.alpha = 0.65
            if textView.accessibilityLabel == "description" {
                textView.text = "Add a description..."
            } 
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        var diff : CGFloat = textView.frame.height
        let amountOfLinesToBeShown: CGFloat = 10
        let maxHeight: CGFloat = textView.font!.lineHeight * amountOfLinesToBeShown
                        
        //keep height > 70 , < maxHeight
        var size = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: maxHeight))
        if size.height > maxHeight {
            while size.height > maxHeight {
                textView.text = String(textView.text.dropLast())
                size = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: maxHeight))
            }
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY, width: textView.frame.width, height: maxHeight)
        } else if size.height > 70 {
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY, width: textView.frame.width, height: size.height)
        } else {
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY, width: textView.frame.width, height: 70)
        }
        
        diff = textView.frame.height - diff
        
        // only move tags for big enough change
        if diff > abs(5) {
            tagsLabel.frame = CGRect(x: tagsLabel.frame.minX, y: tagsLabel.frame.minY + diff, width: tagsLabel.frame.width, height: tagsLabel.frame.height)
            tagScroll.frame = CGRect(x: tagScroll.frame.minX, y: tagScroll.frame.minY + diff, width: tagScroll.frame.width, height: tagScroll.frame.height)
        }
        
        ///for tag search
        if textView.text.last != " " {
            if let word = textView.text?.split(separator: " ").last {
                if word.hasPrefix("@") {
                    resultsView.isHidden = false
                    resultsMask.isHidden = false
                    activityIndicatorView.startAnimating()
                    runQuery(searchText: String(word.lowercased().dropFirst()))
                } else {
                    activityIndicatorView.stopAnimating()
                    resultsView.isHidden = true
                    resultsMask.isHidden = true
                }
            } else {
                activityIndicatorView.stopAnimating()
                resultsView.isHidden = true
                resultsMask.isHidden = true
            }
        } else {
            activityIndicatorView.stopAnimating()
            resultsView.isHidden = true
            resultsMask.isHidden = true
        }
    }
    
    func runQuery(searchText: String) {
        queryObject.removeAll()
        
        var index = 0
        
        for friend in self.friendsList {
            
            if String(friend.username.prefix(searchText.count)) == searchText {
                if !self.queryObject.contains(where: {$0.username == friend.username}) {
                    self.queryObject.append((name: friend.name, username: friend.username))
                }
            } else if String(friend.name.prefix(searchText.count)) == searchText {
                if !self.queryObject.contains(where: {$0.username == friend.username}) {
                    self.queryObject.append((name: friend.name, username: friend.username))
                }
            } else if String(friend.name.lowercased().prefix(searchText.count)) == searchText {
                if !self.queryObject.contains(where: {$0.username == friend.username}) {
                    self.queryObject.append((name: friend.name, username: friend.username))
                }
            }
            
            index = index + 1
            
            if index == self.friendsList.count {
                queryObject.append((name: friend.name, username: friend.username))
                self.queried = true
                self.resultsView.reloadData()
            }
        }
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text == "" {
            textField.alpha = 0.65
            textField.text = "Spot name"
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.alpha < 0.8 {
            textField.text = ""
            textField.alpha = 1.0
        }
    }
    
    @objc func singleTapGestureCaptured(gesture: UITapGestureRecognizer){
        self.view.endEditing(true)
    }
    
    
    
    @objc func nextTapped(sender: UIBarButtonItem) {
        //do delegate passing here
        self.view.endEditing(true)
        
        if (self.nameTextField.text?.isEmpty == true || self.nameTextField.text == "Spot name"){
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Give your spot a name"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
        }
            
        else if (self.selectedImageView.image == nil){
            errorBox.isHidden = false
            errorTextLayer.isHidden = false
            errorTextLayer.text = "Add a picture of your spot"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.errorTextLayer.isHidden = true
                self.errorBox.isHidden = true
            }
        }
            
        else {
            if (self.descriptionTextField.text?.isEmpty == true || self.descriptionTextField.text! == "Add a description...") {
                self.newSpot.description = ""
            } else {
                self.newSpot.description = descriptionTextField.text!
            }
            
            while self.newSpot.description.last?.isNewline ?? false {
                self.newSpot.description = String(self.newSpot.description.dropLast())
            }
            if self.draftID != nil {self.newSpot.draftID = self.draftID}
            self.newSpot.createdBy = self.uid
            self.newSpot.name = nameTextField.text!
            self.newSpot.spotImages = self.passedSpotImages
            var counter = 1
            for tag in tags {
                if (tag.2) {
                    if (counter == 1) {
                        newSpot.tag1 = tag.1
                        counter = counter + 1
                    } else if (counter == 2) {
                        newSpot.tag2 = tag.1
                        counter = counter + 1
                    } else if (counter == 3) {
                        newSpot.tag3 = tag.1
                        counter = counter + 1
                    }
                }
            }
            newSpot.spotLat = self.passedLocation.coordinate.latitude
            newSpot.spotLong = self.passedLocation.coordinate.longitude
            if gifMode {
                saveGIF(images: self.passedSpotImages)
            } else if imageFromCamera {
                PHPhotoLibrary.requestAuthorization { status in
                    guard status == .authorized else { return }
                    SpotPhotoAlbum.sharedInstance.save(image: self.selectedImageView.image!)
                }
            }
            
            editLocation()
        }
    }
    
    
    @objc func backToMap(sender: UIBarButtonItem) {
        navigationController?.popToRootViewController(animated: false)
    }
    
    @objc func editLocation() {
        Analytics.logEvent("addSpotToConfirmLocation", parameters: nil)
        let word = self.descriptionTextField.text.split(separator: " ")
        
        var selectedUsers: [(uid: String, username: String)] = []
        
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = friendsList.first(where: {$0.username == username}) {
                    selectedUsers.append((f.uid, f.username))
                }
            }
        }
        newSpot.selectedUsers = selectedUsers
        
        if gifMode { newSpot.gifMode = true}
        let infoPass = ["newSpot": self.newSpot] as [String : Any]
        NotificationCenter.default.post(name: self.addSpotNotificatioName, object: nil, userInfo: infoPass)
        self.tabBarController?.selectedIndex = 0
        self.navigationController?.popToRootViewController(animated: false)
    }
    
    func setImageViewBounds() {
        
        if self.previousImageView != nil {
            self.previousImageView.frame = CGRect(x: -(15 + UIScreen.main.bounds.width), y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3)
        }
        
        if self.selectedImageView != nil {
            self.selectedImageView.frame = CGRect(x: 15, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3)
        }
        
        if self.nextImageView != nil {
            self.nextImageView.frame = CGRect(x: 15 + UIScreen.main.bounds.width, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3)
        }
    }
    
    @objc func imageSwipe(_ gesture: UIGestureRecognizer) {
        if let swipe = gesture as? UIPanGestureRecognizer {
            let direction = swipe.velocity(in: view)
            let translation = swipe.translation(in: self.view)
            
            if abs(translation.y) > abs(translation.x) {
                return
            }
            
            if direction.x < 0 || translation.x < 0 {
                if self.selectedImageIndex != self.passedSpotImages.count - 1 {
                    
                    let frame0 = CGRect(x: 15 + translation.x, y: constantHeight, width: selectedImageView.frame.width, height: selectedImageView.frame.height)
                    selectedImageView.frame = frame0
                    
                    let frame1 = CGRect(x: selectedImageView.frame.minX + 30 + selectedImageView.frame.width, y: constantHeight, width: nextImageView.frame.width, height: nextImageView.frame.height)
                    nextImageView.frame = frame1
                    
                    if swipe.state == .ended {
                        
                        if frame1.minX + direction.x < UIScreen.main.bounds.width/2 {
                            UIView.animate(withDuration: 0.2, animations: { (self.nextImageView.frame = CGRect(x: 15, y: self.constantHeight, width: self.nextImageView.frame.width, height: self.nextImageView.frame.height))
                                self.selectedImageView.frame = CGRect(x: -(15 + UIScreen.main.bounds.width), y: self.constantHeight, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                            })
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                
                                self.selectedImageIndex = self.selectedImageIndex + 1
                                //pass by reference (try)
                                
                                self.selectedImageView.image = self.passedSpotImages[self.selectedImageIndex]
                                
                                self.previousImageView.image = self.passedSpotImages[self.selectedImageIndex - 1]
                                self.selectedImageView.roundCornersForAspectFit(radius: 8)
                                self.previousImageView.roundCornersForAspectFit(radius: 8)
                                
                                self.setImageViewBounds()
                                
                                if self.selectedImageIndex != self.passedSpotImages.count - 1 {
                                    
                                    self.nextImageView.image = self.passedSpotImages[self.selectedImageIndex + 1]
                                    self.nextImageView.roundCornersForAspectFit(radius: 8)
                                    
                                    
                                }
                                self.setUpDotView(count: self.passedSpotImages.count)
                                
                                
                            }
                            
                        } else {
                            print("not less than")
                            UIView.animate(withDuration: 0.2, animations: { self.setImageViewBounds()
                            })
                            
                            //    self.selectedImageIndex = self.selectedImageIndex + 1
                            //    self.tableView.reloadData()
                        }
                    }
                } else {
                    
                    let frame0 = CGRect(x: 0 + translation.x, y: self.selectedImageView.frame.minY, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0
                    
                    if swipe.state == .ended {
                        UIView.animate(withDuration: 0.2, animations: {
                            self.setImageViewBounds()
                        })
                    }
                }
            } else {
                if self.selectedImageIndex != 0 {
                    
                    let frame0 = CGRect(x: 15 + translation.x, y: constantHeight, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0
                    
                    let frame1 = CGRect(x: self.selectedImageView.frame.minX - self.selectedImageView.frame.width - 30, y: constantHeight, width: self.previousImageView.frame.width, height: self.previousImageView.frame.height)
                    self.previousImageView.frame = frame1
                    
                    if swipe.state == .ended {
                        if frame1.maxX + direction.x > UIScreen.main.bounds.width/2 {
                            print("greater than")
                            UIView.animate(withDuration: 0.2, animations: { (self.previousImageView.frame = CGRect(x: 15, y: self.constantHeight, width: self.previousImageView.frame.width, height: self.previousImageView.frame.height))
                                
                                self.selectedImageView.frame = CGRect(x: UIScreen.main.bounds.width + 15, y: self.constantHeight, width: self.selectedImageView.bounds.width, height: self.selectedImageView.bounds.height)
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.selectedImageIndex = self.selectedImageIndex - 1
                                self.selectedImageView.image = self.passedSpotImages[self.selectedImageIndex]
                                
                                self.nextImageView.image = self.passedSpotImages[self.selectedImageIndex + 1]
                                
                                
                                self.selectedImageView.roundCornersForAspectFit(radius: 8)
                                self.nextImageView.roundCornersForAspectFit(radius: 8)
                                
                                self.setImageViewBounds()
                                
                                if self.selectedImageIndex != 0 {
                                    self.previousImageView.image = self.passedSpotImages[self.selectedImageIndex - 1]
                                    self.previousImageView.roundCornersForAspectFit(radius: 8)
                                    
                                }
                                self.setUpDotView(count: self.passedSpotImages.count)
                            }
                        } else {
                            print("not greater than")
                            UIView.animate(withDuration: 0.2, animations: { self.setImageViewBounds()
                            })
                            
                            //    self.selectedImageIndex = self.selectedImageIndex + 1
                        }
                        
                    }
                } else {
                    
                    let frame0 = CGRect(x: 15 + translation.x, y: self.selectedImageView.frame.minY, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0
                    
                    if swipe.state == .ended {
                        
                        UIView.animate(withDuration: 0.2, animations: {
                            self.setImageViewBounds()
                        })
                    }
                }
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if textField.accessibilityHint == "name" {
            return updatedText.count <= 25
        }  else {
            return true
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let currentText = textView.text ?? ""
        
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        
        if textView.accessibilityHint == "description" {
            print("description type")
            return updatedText.count <= 560
        }
        else if textView.accessibilityHint == "tips" {
            print("tips type")
            return updatedText.count <= 560
        } else {
            return true
        }
    }
}



extension AddSpotViewController: UINavigationControllerDelegate, CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for currentLocation in locations{
            print(currentLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error){
        print("Unable to access your current location")
    }
}

extension AddSpotViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 11
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tagCell", for: indexPath) as! TagCell
        let tag = tags[indexPath.row]
        cell.setUp(image: tag.0, text: tag.1)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(cellTap(_:)))
        tap.accessibilityLabel = String(indexPath.row)
        cell.addGestureRecognizer(tap)
        
        if tag.2 {
            cell.isSelected = true
        } else {
            cell.isSelected = false
        }
        return cell
    }
    @objc func cellTap(_ sender: UIGestureRecognizer) {
        self.view.endEditing(true)
        
        let row = Int(sender.accessibilityLabel ?? "0")
        if tags[row!].2 {
            tags[row!].2 = false
        } else {
            let count = tags.filter({$0.2 == true})
            if count.count > 2 {
                return
            }
            tags[row!].2 = true
        }
        self.tagScroll.reloadData()
    }
}
extension AddSpotViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if queried {
            let cellHeight = CGFloat(self.queryObject.count * 45)
            
            var minY: CGFloat = 0
            var height: CGFloat = 0
            
            if cellHeight > self.descriptionTextField.frame.minY - 5 {
                height = self.descriptionTextField.frame.minY - 5
            } else {
                minY = self.descriptionTextField.frame.minY - 5 - cellHeight
                height = cellHeight
            }
            
            self.resultsView.frame = CGRect(x: 0, y: minY, width: self.resultsView.frame.width, height: height)
            view.bringSubviewToFront(resultsView)
            if self.queryObject.count != 0 {activityIndicatorView.stopAnimating()}
            return self.queryObject.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "resultsCell", for: indexPath) as! resultsCell
        if self.queried {
            if (!self.queryObject.isEmpty) {
                cell.setUp()
                cell.nameLabel.text = queryObject[indexPath.row].name
                cell.nameLabel.sizeToFit()
                cell.usernameLabel.text = queryObject[indexPath.row].username
                cell.usernameLabel.sizeToFit()
                cell.isUserInteractionEnabled = true
                return cell
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("select row")
        let cell = tableView.cellForRow(at: indexPath) as! resultsCell
        let username = cell.usernameLabel.text
        if let word = self.descriptionTextField.text?.split(separator: " ").last {
            if word.hasPrefix("@") {
                var text = String(self.descriptionTextField.text.dropLast(word.count - 1))
                text.append(contentsOf: username ?? "")
                self.self.descriptionTextField.text = text
                self.resultsView.isHidden = true
                self.resultsMask.isHidden = true
                activityIndicatorView.stopAnimating()
            }
        }
    }
}
