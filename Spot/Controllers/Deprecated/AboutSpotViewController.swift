//
//  AboutSpotViewController.swift
//  Spot
//
//  Created by kbarone on 4/20/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
/*
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import CoreLocation

class AboutSpotViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var listener1, listener2, listener3, listener4, listener5: ListenerRegistration!
    
    var spotID : String!
    let db: Firestore! = Firestore.firestore()
    var imageURL : String?
    var imageURLs: [String] = []
    
    var founderID: String!
    var profilePicURL: String!
    
    var spotNameHeight: CGFloat = 0
    var descriptionHeight: CGFloat = 0
    var directionsHeight: CGFloat = 0
    var tipsHeight: CGFloat = 0
    var addressHeight: CGFloat = 0
    
    var spotLat : Double!
    var spotLong: Double!
    
    var userLat: Double!
    var userLong: Double!
    
    var uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var spotList: [String] = []
    
    var checkedInHere = false
    var checkInHidden = true
    var dataFetched = false
    var eventFetched = false
    
    var cellCount = 9
    
    var walkingExpand = false
    var tipExpand = false
    
    var spotImage: UIImage!
    var spotImages: [UIImage] = []
    var selectedImageIndex = 0
    
    var visitorList: [String] = []
    var friendsList: [String] = []
    var visitedFriends: [(id: String, imageURL: String, image: UIImage)] = []
    
    let editSpotNotificationName = Notification.Name("editSpot")
    
    var spotObject = AboutSpot(spotImage: UIImage(), spotName: "", userImage: UIImage(), username: "", description: "", tag1: "", tag2: "", tag3: "", address: "", directions: "", tips: "")
    
    var checkInButton: UIButton!
    var picToCheckInButton: UIButton!
    
    let checkInNotificationName = Notification.Name("checkIn")
    let checkedInWithPictureName = Notification.Name("checkInPicture")
    let eventTapNotificationName = Notification.Name("eventTap")
    
    var privacyLevel: String!
    var labelType: String!
    
    weak var timer: Timer?
    var runTimer = false
    
    var inviteList: [String] = []
    var invitePics: [(id: String, imageURL: String, image: UIImage)] = []
    
    var locationManager = CLLocationManager()
    
    var start: CFAbsoluteTime!
    
    let minimizeImage = UIImage(named: "Minimize")
    let maximizeImage = UIImage(named: "Expand")
    
    var userImageURL: String!
    
    var eventsList: [Event] = []
    var eventsScroll: UIScrollView!
    
    var largeScreen = true
    
    override func viewDidLoad() {
        print("view did load ran")
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        start = CFAbsoluteTimeGetCurrent()
        view.backgroundColor = UIColor.blue
        if (!(UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792)) {
            largeScreen = false
            let topConstraint = constraintWithIdentifier("aboutTop")
            topConstraint?.constant = 30
            let bottomConstraint = constraintWithIdentifier("aboutBottom")
            bottomConstraint?.constant = 70
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCheckIn(_:)), name: checkInNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(eventTap(_:)), name: eventTapNotificationName, object: nil)
        
        
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        //  tableView.estimatedRowHeight = tableView.rowHeight
        
        tableView.isScrollEnabled = true
        view.backgroundColor = UIColor.white
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEdit(_:)), name: editSpotNotificationName, object: nil)
        
        loadSpotData()
        
        navigationItem.backBarButtonItem?.title = ""
    }
    
    func loadSpotData() {
        self.listener1 = self.db.collection("spots").document(self.spotID!).addSnapshotListener { (snapshot, err) in
            
            if let err = err {
                print("Error getting documents: \(err)")
            } else{
                if (snapshot?.get("spotName") == nil) {
                    self.navigationController?.popToRootViewController(animated: false)
                }
                if let spotN = snapshot?.get("spotName") as? String {
                    self.spotObject.spotName = spotN
                    let nLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 34, height: 20))
                    nLabel.font = UIFont(name: "SFCamera-Semibold", size: 27)
                    nLabel.numberOfLines = 0
                    nLabel.lineBreakMode = .byWordWrapping
                    nLabel.text = spotN
                    nLabel.sizeToFit()
                    self.spotNameHeight = nLabel.frame.height
                    
                    self.privacyLevel = snapshot?.get("privacyLevel") as? String
                    if (self.privacyLevel == "invite") {
                        self.labelType = "invite"
                    } else if (self.privacyLevel == "friends") {
                        self.labelType = "friends"
                    }
                    
                    self.visitorList = snapshot?.get("visitorList") as! [String]
                    
                    self.checkLocation()
                    
                    if (self.privacyLevel == "invite") {
                        self.inviteList = snapshot?.get("inviteList") as! [String]
                    }
                    
                    self.imageURL = snapshot?.get("imageURL") as? String
                    self.imageURLs.append(self.imageURL!)
                    if let imageURL1 = snapshot?.get("imageURL1") as? String {
                        self.imageURLs.append(imageURL1)
                    }
                    if let imageURL2 = snapshot?.get("imageURL2") as? String {
                        self.imageURLs.append(imageURL2)
                    }
                    if let imageURL3 = snapshot?.get("imageURL3") as? String {
                        self.imageURLs.append(imageURL3)
                    }
                    if let imageURL4 = snapshot?.get("imageURL4") as? String {
                        self.imageURLs.append(imageURL4)
                    }
                    
                    self.spotObject.description = (snapshot?.get("description") as? String)!
                    let dLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 40, height: 20))
                    dLabel.font = UIFont(name: "SFCamera-regular", size: 13)
                    dLabel.numberOfLines = 0
                    dLabel.lineBreakMode = .byWordWrapping
                    dLabel.text = self.spotObject.description
                    dLabel.sizeToFit()
                    self.descriptionHeight = dLabel.frame.height
                    
                    if (snapshot?.get("tag1") as? String != "") {
                        
                        self.spotObject.tag1 = snapshot?.get("tag1") as! String
                        
                        if (snapshot?.get("tag2") as? String != "") {
                            
                            self.spotObject.tag2 = snapshot?.get("tag2") as! String
                            
                            if (snapshot?.get("tag3") as? String != "") {
                                
                                
                                self.spotObject.tag3 = snapshot?.get("tag3") as! String
                                
                            }
                        }
                    } else {
                        self.cellCount = self.cellCount - 1
                    }
                    let arrayLocation = snapshot?.get("l") as! [NSNumber]
                    
                    let spotLatitude : Double = arrayLocation[0] as! Double
                    let spotLongitude : Double = arrayLocation[1] as! Double
                    
                    let location = CLLocation(latitude: spotLatitude, longitude: spotLongitude)
                    
                    var addressString = "City, Earth"
                    
                    
                    CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in // 6
                        guard let placemark = placemarks?.first else {
                            print("placemark broke")
                            return
                        }
                        addressString = ""
                        
                        if placemark.thoroughfare != nil {
                            addressString = addressString + placemark.thoroughfare! + ", "
                        }
                        if placemark.locality != nil {
                            addressString = addressString + placemark.locality! + ", "
                        }
                        if placemark.administrativeArea != nil {
                            addressString = addressString + placemark.administrativeArea! + ", "
                        }
                        if placemark.country != nil {
                            addressString = addressString + placemark.isoCountryCode!
                        }
                        self.spotObject.address = addressString
                    }
                    
                    let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 220, height: 20))
                    tempLabel.font = UIFont(name: "SFCamera-regular", size: 13)
                    tempLabel.numberOfLines = 0
                    tempLabel.lineBreakMode = .byWordWrapping
                    tempLabel.text = self.spotObject.address
                    tempLabel.sizeToFit()
                    self.addressHeight = tempLabel.frame.height
                    
                    self.spotObject.directions = snapshot?.get("directions") as! String
                    if (self.spotObject.directions == "") {
                        self.cellCount = self.cellCount - 1
                    } else {
                        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 40, height: 20))
                        tempLabel.font = UIFont(name: "SFCamera-regular", size: 13)
                        tempLabel.numberOfLines = 0
                        tempLabel.lineBreakMode = .byWordWrapping
                        tempLabel.text = self.spotObject.directions
                        tempLabel.sizeToFit()
                        self.directionsHeight = tempLabel.frame.height
                    }
                    
                    self.spotObject.tips = snapshot?.get("tips") as! String
                    if (self.spotObject.tips == "") {
                        self.cellCount = self.cellCount - 1
                    } else {
                        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 40, height: 20))
                        tempLabel.font = UIFont(name: "SFCamera-regular", size: 13)
                        tempLabel.numberOfLines = 0
                        tempLabel.lineBreakMode = .byWordWrapping
                        tempLabel.text = self.spotObject.tips
                        tempLabel.sizeToFit()
                        self.tipsHeight = tempLabel.frame.height
                    }
                    self.founderID = snapshot?.get("createdBy") as? String
                    
                    self.getPrivacyData()
                    
                    self.listener5 = self.db.collection("spots").document(self.spotID).collection("events").addSnapshotListener({ (eventsSnap, err) in
                        var eventIndex = 0
                        if eventsSnap?.documents.count != 0 {
                            self.cellCount = self.cellCount + 1
                            for event in eventsSnap!.documents {
                                let eventID = event.documentID
                                var rawTimeStamp = Timestamp()
                                rawTimeStamp = event.get("timestamp") as! Timestamp
                                let seconds = rawTimeStamp.seconds
                                
                                let timestamp = NSDate().timeIntervalSince1970 as Double
                                let i = Int64(timestamp)
                                //checking if the event has already happened (2 hour grace period)
                                if i < seconds + 7200 {
                                    var active = false
                                    if i < seconds + 7200 && i > seconds {
                                        active = true
                                    }
                                    let date = rawTimeStamp.dateValue()
                                    let imageURL = event.get("imageURL") as! String
                                    let eventName = event.get("eventName") as! String
                                    let price = event.get("price") as! Int
                                    let description = event.get("description") as! String
                                    
                                    if !self.eventsList.contains(where: {$0.eventID == eventID}) {
                                        let newEvent = (Event(spotID: self.spotID, eventID: eventID, time: seconds, date: date, imageURL: imageURL, eventImage: UIImage(), spotName: spotN, eventName: eventName, spotLat: spotLatitude, spotLong: spotLongitude, active: active, price: price, description: description))
                                        self.eventsList.append(newEvent)
                                    }
                                }
                                eventIndex = eventIndex + 1
                                if eventIndex == eventsSnap?.documents.count {
                                    if (self.eventsList.isEmpty) {
                                        self.cellCount = self.cellCount - 1
                                        self.eventFetched = true
                                        if self.dataFetched {
                                            self.tableView.reloadData()
                                            self.removeListeners()
                                            self.listener5.remove()
                                        }
                                        return
                                    } else {
                                        self.getEventImages()
                                        return
                                    }
                                }
                            }
                        } else {
                            self.eventFetched = true
                        }
                    })
                }
            }
        }
    }
    
    func getPrivacyData() {
        self.listener2 = self.db.collection("users").document(self.founderID!).addSnapshotListener { (founderSnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                //   let founder = founderSnapshot?.get("username") as! String
                self.spotObject.username = founderSnapshot?.get("username") as! String
                self.profilePicURL = founderSnapshot?.get("imageURL") as? String
            }
            if (self.privacyLevel == "invite") {
                var x = 0
                
                for invite in self.inviteList {
                    
                    self.listener4 = self.db.collection("users").document(invite).addSnapshotListener { (urlSnap, err) in
                        
                        if let err = err {
                            print("Error getting documents: \(err)")
                        } else {
                            let dup = self.invitePics.contains(where: {$0.id == invite})
                            if (!dup) {
                                let url = urlSnap?.get("imageURL") as! String
                                self.invitePics.append((id: invite, imageURL: url, image: UIImage()))
                            }
                            
                            x = x + 1
                            if (x == self.inviteList.count) {
                                self.getInvitePics()
                            }
                        }
                    }
                }
            } else {
                self.listener3 = self.db.collection("users").document(self.uid).addSnapshotListener { (userSnap, err) in
                    
                    if let err = err {
                        print("Error getting documents: \(err)")
                    } else {
                        self.friendsList = userSnap?.get("friendsList") as! [String]
                        self.userImageURL = (userSnap?.get("imageURL") as! String)
                        switch self.privacyLevel {
                        case "friends":
                            self.labelType = "friends"
                        default:
                            self.labelType = "public"
                        }
                        self.friendsList.append(self.uid)
                        if (!self.visitorList.isEmpty) {
                            var x = 0
                            for visitor in self.visitorList {
                                if self.friendsList.contains(visitor) && visitor !=  "T4KMLe3XlQaPBJvtZVArqXQvaNT2" {
                                    if (self.labelType == "public") {
                                        self.labelType = "publicFriends"
                                    }
                                    
                                    self.db.collection("users").document(visitor).getDocument { (urlSnap, err) in
                                        
                                        if let err = err {
                                            print("Error getting documents: \(err)")
                                        } else{
                                            let visitorURL = urlSnap?.get("imageURL") as! String
                                            let dup = self.visitedFriends.contains(where: {$0.id == visitor})
                                            if (!dup) {
                                                self.visitedFriends.append((id: visitor, imageURL: visitorURL, image: UIImage()))
                                            }
                                            x = x + 1
                                            if (x == self.visitorList.count) {
                                                self.getFriendVisitors(refresh: false)
                                            }
                                        }
                                    }
                                } else {
                                    x = x + 1
                                    if (x == self.visitorList.count) {
                                        self.getFriendVisitors(refresh: false)
                                    }
                                }
                            }
                        } else {
                            self.getSpotImages()
                        }
                    }
                    
                }
            }
            
        }
    }
    
    
    func getInvitePics() {
        for index in 0...self.invitePics.count - 1 {
            let ref = Storage.storage().reference(forURL: self.invitePics[index].imageURL)
            ref.getData(maxSize: 1 * 2048 * 2048) { data, error in
                if error != nil {
                    print("error occured")
                } else {
                    let image = UIImage(data: data!)
                    self.invitePics[index].image = image!
                    if (index == self.invitePics.count - 1) {
                        self.getSpotImages()
                    }
                }
            }
        }
    }
    
    func getFriendVisitors(refresh: Bool) {
        if (!visitedFriends.isEmpty) {
            for index in 0...self.visitedFriends.count - 1 {
                let ref = Storage.storage().reference(forURL: self.visitedFriends[index].imageURL)
                ref.getData(maxSize: 1 * 2048 * 2048) { data, error in
                    if error != nil {
                        print("error occured")
                    } else {
                        let image = UIImage(data: data!)
                        self.visitedFriends[index].image = image!
                        if (index == self.visitedFriends.count - 1) {
                            if (refresh) {
                                let indexPath = IndexPath(row: 1, section: 0)
                                self.tableView.reloadRows(at: [indexPath], with: .none)
                                self.checkInButton.isHidden = true
                                return
                            } else {
                                self.getSpotImages()
                            }
                        }
                    }
                }
            }
        } else {
            self.getSpotImages()
        }
    }
    
    func getSpotImages() {
        var gotImages = false
        var gotProfile = false
        print("get spot images called")
        
        for url in self.imageURLs {
            let gsReference = Storage.storage().reference(forURL: url)
            gsReference.getData(maxSize: 1 * 2048 * 2048) { data, error in
                if error != nil {
                    print("error occured")
                } else {
                    let image = UIImage(data: data!)
                    
                    let aspect = image!.size.height / image!.size.width
                    
                    if Int(UIScreen.main.bounds.width * aspect) > self.imageHeight {
                        self.imageHeight = Int(UIScreen.main.bounds.width * aspect)
                    }
                    
                    self.spotImages.append(image!)
                    self.spotObject.spotImage = image!
                    
                    gotImages = true
                    if (self.eventFetched && gotProfile) {
                        self.dataFetched = true
                        self.tableView.reloadData()
                        print("reloaded data")
                        self.removeListeners()
                    }
                    print("got image")
                }
            }
        }
        
        let profileReference = Storage.storage().reference(forURL: self.profilePicURL)
        profileReference.getData(maxSize: 1 * 2048 * 2048) { data, error in
            if error != nil {
                print("error occured")
            } else {
                let image = UIImage(data: data!)
                let diff = CFAbsoluteTimeGetCurrent() - self.start
                Analytics.logEvent("aboutSpotLoadTime", parameters: ["time" : diff])
                self.spotObject.userImage = image!
                
                gotProfile = true
                if (self.eventFetched && gotImages) {
                    self.dataFetched = true
                    print("reloaded data")
                    self.tableView.reloadData()
                    self.removeListeners()
                }
            }
        }
        
    }
    
    
    func getEventImages() {
        self.eventsList = self.eventsList.sorted(by: {$0.time < $1.time})
        var counter = 0
        for i in 0 ... eventsList.count - 1 {
            let ref = Storage.storage().reference(forURL: eventsList[i].imageURL)
            ref.getData(maxSize: 1 * 2048 * 2048) { data, error in
                if error != nil {
                    return
                } else {
                    let image = UIImage(data: data!)!
                    self.eventsList[i].eventImage = image
                    
                    counter = counter + 1
                    if counter == self.eventsList.count {
                        self.eventFetched = true
                        if self.dataFetched {
                            self.tableView.reloadData()
                            self.removeListeners()
                        }
                    }
                }
            }
        }
    }
    
    
    // Do any additional setup after loading the view.
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        Analytics.logEvent("aboutSpotAppeared", parameters: nil)
        
        if (self.checkedInHere) {
            self.checkInButton.isHidden = true
            self.checkInButton.removeFromSuperview()
            
            if visitedFriends.count != 0 {
                for i in 0...visitedFriends.count - 1 {
                    if (visitedFriends[i].id == self.uid) {
                        return
                    }
                }
            }
            if (!visitorList.contains(self.uid))  {
                visitorList.append(self.uid)
            }
            
            if (self.privacyLevel == "friends") {
                visitedFriends.append((id: self.uid, imageURL: self.userImageURL, image: UIImage()))
                self.getFriendVisitors(refresh: true)
            }
            else if (self.privacyLevel == "public") {
                self.labelType = "publicFriends"
                visitedFriends.append((id: self.uid, imageURL: self.userImageURL, image: UIImage()))
                self.getFriendVisitors(refresh: true)
            } else {
                return
            }
            
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(false)
    }
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkLocation()
        }
    }
    //this  should be more of an active listener on didChangeLocations, fix in future iteration
    func checkLocation() {
        if (!self.visitorList.contains(self.uid)) {
            self.checkInHidden = false
            var yOffset: CGFloat = 0
            if largeScreen {yOffset = 15}
            self.checkInButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 140, y: 82 + yOffset, width: 135, height: 54))
            self.picToCheckInButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 173, y: 75 + yOffset, width: 150, height: 60))
            
            if CLLocationManager.locationServicesEnabled() == true {
                if CLLocationManager.authorizationStatus() == .restricted ||
                    CLLocationManager.authorizationStatus() == .denied ||
                    CLLocationManager.authorizationStatus() == .notDetermined{
                    
                    locationManager.requestWhenInUseAuthorization()
                }
                locationManager.desiredAccuracy = 1.0
                locationManager.startUpdatingLocation()
                let currentLocation = locationManager.location
                if (currentLocation != nil) {
                    self.userLat = currentLocation!.coordinate.latitude
                    self.userLong = currentLocation!.coordinate.longitude
                } else {
                    self.userLat = 0
                    self.userLong = 0
                }
            }else{
                print("please turn on location services")
            }
            if ((self.userLat - self.spotLat) <  0.0005 && abs(self.userLong - self.spotLong) < 0.0005) {
                Analytics.logEvent("aboutSpotUserWithinCheckInZone", parameters: nil)
                self.checkInButton.setImage(UIImage(named: "UnlockButton"), for: UIControl.State.normal)
                self.checkInButton.addTarget(self, action: #selector(self.checkIn(_:)), for: .touchUpInside)
                self.checkInButton.contentMode = .scaleAspectFit
                self.view.addSubview(self.checkInButton)
            } else if (privacyLevel == "public") {
                Analytics.logEvent("aboutSpotUserNotWithinCheckInZone", parameters: nil)
                self.picToCheckInButton.setImage(UIImage(named: "PostToUnlockButton"), for: .normal)
                self.picToCheckInButton.addTarget(self, action: #selector(picToCheckInTap(_:)), for: .touchUpInside)
                self.picToCheckInButton.contentMode = .scaleAspectFit
                self.view.addSubview(self.picToCheckInButton)
            }
            self.startTimer()
        }
    }
    
    func removeListeners() {
        print("listeners removed")
        if self.listener1 != nil {
            self.listener1.remove()
        }
        if self.listener2 != nil {
            self.listener2.remove()
        }
        if self.listener3 != nil {
            self.listener3.remove()
        }
        if self.listener4 != nil {
            self.listener4.remove()
        }
        if self.listener5 != nil {
            self.listener5.remove()
        }
    }
    
    func constraintWithIdentifier(_ identifier: String) -> NSLayoutConstraint? {
        return view.constraints.first { $0.identifier == identifier }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (dataFetched) {
            return cellCount
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        //set up cell heights based on height of individual cells/work in expandable views by adjusting row height
        if (indexPath.row == 0) {
            return UIScreen.main.bounds.height * 1/2
        } else if (indexPath.row == 1) {
            return 45
        } else if (indexPath.row == 2) {
            return CGFloat(spotNameHeight + 7)
        } else if (indexPath.row == 3) {
            return 30
        } else if (indexPath.row == 4) {
            return CGFloat(descriptionHeight + 15)
        } else if (indexPath.row == 5) {
            if (self.spotObject.tag1 != "") {
                return 30
                //tag cell
            } else {
                if (addressHeight < 30) {
                    return 40
                } else {
                    return addressHeight + 10
                    //address cell
                }
            }
        } else if (indexPath.row == 6) {
            if self.spotObject.tag1 != "" {
                if (addressHeight < 30) {
                    return 40
                } else {
                    return addressHeight + 10
                }
            } else if (spotObject.directions == "") {
                if (spotObject.tips == "") {
                    return 200
                }
                if (tipExpand) {
                    return CGFloat(tipsHeight + 60)
                } else {
                    return 40
                }
            } else {
                if (walkingExpand) {
                    return CGFloat(directionsHeight + 60)
                } else {
                    return 40
                }
                
            }
        } else if (indexPath.row == 7) {
            if (spotObject.directions == "" || spotObject.tag1 == "") {
                if spotObject.tips == "" {
                    return 200
                }
                if (tipExpand) {
                    return CGFloat(tipsHeight + 60)
                } else {
                    return 40
                }
            } else {
                if (walkingExpand) {
                    return CGFloat(directionsHeight + 60)
                } else {
                    return 40
                }
            }
            
        } else if (indexPath.row == 8) {
            if self.spotObject.tips == "" || spotObject.directions == "" || spotObject.tag1 == "" {
                return 200
            }
            if (tipExpand) {
                return CGFloat(tipsHeight + 60)
            } else {
                return 40
            }
        } else if indexPath.row == 9 {
            return 200
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if (indexPath.row == 0) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotImageCell") as! SpotImageCell
            // spotImgView = UIImageView(frame: CGRect(x: 0, y: 15, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3)))
            
            cell.setUp()
            
            var imHeight : CGFloat = 0
            let image = spotImages[selectedImageIndex]
            
            let aspect = image.size.height / image.size.width
            
            imHeight = UIScreen.main.bounds.width * aspect
            
            if imHeight < UIScreen.main.bounds.height * 1/2 {
                let yp = ((UIScreen.main.bounds.height * 1/2) - imHeight) / 2
                print("y coordinate", yp)
                let frame = CGRect(x: 0, y: yp, width: UIScreen.main.bounds.width, height: imHeight)
                cell.spotImgView.frame = frame
                cell.spotImgView.contentMode = .scaleAspectFit
            }
                /*  else if CGFloat(imageHeight) < UIScreen.main.bounds.height * 2/3 {
                 let frame = CGRect(x: 0, y: 25, width: UIScreen.main.bounds.width, height: CGFloat(imageHeight))
                 cell.spotImgView.frame = frame
                 cell.spotImgView.contentMode = .scaleAspectFit
                 heightIndex = 2
             } */else {
                cell.spotImgView.contentMode = .scaleAspectFill
            }
            cell.spotImgView.image = spotImages[selectedImageIndex]
            cell.spotImgView.isUserInteractionEnabled = true
            
            if self.spotImages.count > 1 {
                let swipe = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
                swipe.cancelsTouchesInView = false
                swipe.delegate = self
                cell.spotImgView.addGestureRecognizer(swipe)
            }
            
            if selectedImageIndex != 0 {
                cell.setUpPrevious()
                
                let previousImage = spotImages[selectedImageIndex - 1]
                cell.spotImgViewPrevious.image = previousImage
                
                let previousAspect = previousImage.size.height / previousImage.size.width
                let previousHeight = UIScreen.main.bounds.width * previousAspect
                
                if previousHeight < UIScreen.main.bounds.height * 1/2 {
                    let yp = ((UIScreen.main.bounds.height * 1/2) - previousHeight) / 2
                    print("y coordinate", yp)
                    let previousFrame = CGRect(x: 0, y: yp, width: UIScreen.main.bounds.width, height: previousHeight)
                    cell.spotImgViewPrevious.frame = previousFrame
                    cell.spotImgViewNext.contentMode = .scaleAspectFit
                }
                
            } else {
                if cell.spotImgViewPrevious != nil {cell.spotImgViewPrevious.image = UIImage()}
            }
            if selectedImageIndex != spotImages.count - 1 {
                cell.setUpNext()
                let nextImage = spotImages[selectedImageIndex + 1]
                cell.spotImgViewNext.image = nextImage
                
                let nextAspect = nextImage.size.height / nextImage.size.width
                let nextHeight = UIScreen.main.bounds.width * nextAspect
                
                if nextHeight < UIScreen.main.bounds.height * 1/2 {
                    let yp = ((UIScreen.main.bounds.height * 1/2) - nextHeight) / 2
                    print("y coordinate", yp)
                    let nextFrame = CGRect(x: 0, y: yp, width: UIScreen.main.bounds.width, height: nextHeight)
                    cell.spotImgViewNext.frame = nextFrame
                    cell.spotImgViewNext.contentMode = .scaleAspectFit
                }
                
            } else {
                if cell.spotImgViewNext != nil {cell.spotImgViewNext.image = UIImage()}
            }
            print("selected index", selectedImageIndex)
            return cell
            
        } else if (indexPath.row == 1) {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell") as! LabelCell
            
            
            cell.setUp()
            var offset:CGFloat = 0
            
            switch labelType {
            case "invite":
                
                let typeLabel = UIImageView(frame: CGRect(x: 17, y: 5, width: 60, height: 20))
                typeLabel.image = UIImage(named: "PrivateLabel")
                typeLabel.backgroundColor = nil
                cell.scrollView.addSubview(typeLabel)
                
                offset = offset + 87
                
                for i in 1...self.invitePics.count {
                    let view = UIView(frame:CGRect(x: offset, y: 0, width: 30, height: 30))
                    view.backgroundColor = UIColor(named: "SpotBlack")
                    let imView = UIImageView(frame:CGRect(x: 0, y: 0, width: 30, height: 30))
                    imView.layer.cornerRadius = imView.frame.height/2
                    imView.clipsToBounds = true
                    imView.contentMode = .scaleAspectFill
                    imView.image = self.invitePics[i - 1].image
                    view.addSubview(imView)
                    cell.scrollView.addSubview(view)
                    
                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tagTap(gesture:)))
                    tapGesture.accessibilityLabel = self.invitePics[i - 1].id
                    view.addGestureRecognizer(tapGesture)
                    
                    offset = offset + 38
                    view.tag = i
                }
                cell.scrollView.contentSize = CGSize(width: offset + 10, height: cell.scrollView.frame.height)
                cell.scrollView.isScrollEnabled = true
                
            case "friends":
                let typeLabel = UIImageView(frame: CGRect(x: 17, y: 5, width: 60, height: 20))
                typeLabel.image = UIImage(named: "FriendsLabel")
                typeLabel.backgroundColor = nil
                cell.scrollView.addSubview(typeLabel)
                
                offset = offset + 87
                
                if (!visitedFriends.isEmpty) {
                    for i in 1...self.visitedFriends.count {
                        let view = UIView(frame:CGRect(x: offset, y: 0, width: 30, height: 30))
                        view.backgroundColor = UIColor(named: "SpotBlack")
                        let imView = UIImageView(frame:CGRect(x: 0, y: 0, width: 30, height: 30))
                        imView.layer.cornerRadius = imView.frame.height/2
                        imView.clipsToBounds = true
                        imView.contentMode = .scaleAspectFill
                        imView.image = self.visitedFriends[i - 1].image
                        view.addSubview(imView)
                        cell.scrollView.addSubview(view)
                        
                        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tagTap(gesture:)))
                        tapGesture.accessibilityLabel = self.visitedFriends[i - 1].id
                        view.addGestureRecognizer(tapGesture)
                        
                        offset = offset + 38
                        view.tag = i
                    }
                    cell.scrollView.contentSize = CGSize(width: offset + 10, height: cell.scrollView.frame.height)
                    cell.scrollView.isScrollEnabled = true
                    
                }
            case "public":
                let typeLabel = UIImageView(frame: CGRect(x: 17, y: 15, width: 60, height: 20))
                typeLabel.image = UIImage(named: "PublicLabel")
                typeLabel.backgroundColor = nil
                
            default:
                
                let typeLabel = UIImageView(frame: CGRect(x: 17, y: 5, width: 60, height: 20))
                typeLabel.image = UIImage(named: "PublicFriendsLabel")
                typeLabel.backgroundColor = nil
                cell.scrollView.addSubview(typeLabel)
                
                offset = offset + 87
                
                
                for i in 1...self.visitedFriends.count {
                    let view = UIView(frame:CGRect(x: offset, y: 0, width: 30, height: 30))
                    view.backgroundColor = UIColor(named: "SpotBlack")
                    let imView = UIImageView(frame:CGRect(x: 0, y: 0, width: 30, height: 30))
                    imView.layer.cornerRadius = imView.frame.height/2
                    imView.clipsToBounds = true
                    imView.contentMode = .scaleAspectFill
                    imView.image = self.visitedFriends[i - 1].image
                    view.addSubview(imView)
                    cell.scrollView.addSubview(view)
                    
                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tagTap(gesture:)))
                    tapGesture.accessibilityLabel = self.visitedFriends[i - 1].id
                    view.addGestureRecognizer(tapGesture)
                    
                    offset = offset + 38
                    view.tag = i
                    
                }
                cell.scrollView.contentSize = CGSize(width: offset + 10, height: cell.scrollView.frame.height)
                cell.scrollView.isScrollEnabled = true
                
            }
            
            
            return cell
            
        } else if (indexPath.row == 2) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotNameCell") as! SpotNameCell
            
            cell.setUp()
            cell.spotLabel.text = spotObject.spotName
            
            cell.spotLabel.sizeToFit()
            
            return cell
            
        } else if (indexPath.row == 3) {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "FounderCell")! as! FounderCell
            
            cell.setUp()
            
            let tempImage = self.spotObject.userImage as! UIImage
            cell.founderImageView.image = tempImage
            
            cell.founderButton.setTitle(spotObject.username, for: UIControl.State.normal)
            cell.founderButton.addTarget(self, action: #selector(self.founderTap), for: .touchUpInside)
            let attributedTitle = NSAttributedString(string: (cell.founderButton.titleLabel?.text)!, attributes: [NSAttributedString.Key.kern: 0.5])
            
            cell.founderButton.setAttributedTitle(attributedTitle, for: .normal)
            cell.founderButton.sizeToFit()
            
            cell.profilePicButton.addTarget(self, action: #selector(self.founderTap), for: .touchUpInside)
            
            return cell
            
            
        } else if (indexPath.row == 4) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DescriptionCell") as! DescriptionCell
            
            cell.setUp()
            
            cell.descriptionLabel.text = spotObject.description
            cell.descriptionLabel.sizeToFit()
            
            return cell
            
            
        } else if (indexPath.row == 5) {
            
            if (spotObject.tag1 == "" ) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "AddressCell")! as! AddressCell
                cell.setUp()
                
                cell.addressLabel.text = self.spotObject.address
                cell.directionsButton.addTarget(self, action: #selector(self.directions), for: .touchUpInside)
                
                cell.addressLabel.sizeToFit()
                
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "TagsCell") as! TagCell
                
                cell.setUpTag1()
                cell.tag1Label.text = spotObject.tag1
                
                if (spotObject.tag2 != "" ) {
                    cell.setUpTag2()
                    cell.tag2Label.text = spotObject.tag2
                    
                    if (spotObject.tag3 != "") {
                        cell.setUpTag3()
                        cell.tag3Label.text = spotObject.tag3
                    }
                }
                return cell
            }
            
        } else if (indexPath.row == 6) {
            
            if (spotObject.tag1 == "" ) {
                if (self.spotObject.directions == "") {
                    if (self.spotObject.tips == "") {
                        let cell = tableView.dequeueReusableCell(withIdentifier: "EventsCell")! as! SpotPageEventsCell
                        cell.setUp(events: eventsList)
                        return cell
                    }
                    let cell = tableView.dequeueReusableCell(withIdentifier: "TipsCell")! as! TipsCell
                    
                    cell.setUp()
                    
                    cell.expandedTips.text = self.spotObject.tips
                    cell.expandedTips!.sizeToFit()
                    
                    cell.expandButton.tag = indexPath.row
                    cell.expandButton.addTarget(self, action: #selector(self.tipExpand(_:)), for: .touchUpInside)
                    
                    if (tipExpand) {
                        cell.expandButton.setImage(UIImage(named: "Minimize"), for: UIControl.State.normal)
                    } else {
                        cell.expandButton.setImage(UIImage(named: "Expand"), for: UIControl.State.normal)
                    }
                    
                    
                    
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "DirectionsCell")! as! DirectionsCell
                    
                    cell.setUp()
                    cell.expandedWalking.text = self.spotObject.directions
                    cell.expandedWalking!.sizeToFit()
                    
                    cell.expandButton.tag = indexPath.row
                    cell.expandButton.addTarget(self, action: #selector(self.walkingExpand(_:)), for: .touchUpInside)
                    
                    if (walkingExpand) {
                        cell.expandButton.setImage(UIImage(named: "Minimize"), for: UIControl.State.normal)
                    } else {
                        cell.expandButton.setImage(UIImage(named: "Expand"), for: UIControl.State.normal)
                    }
                    
                    
                    return cell
                }
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "AddressCell")! as! AddressCell
                cell.setUp()
                
                cell.addressLabel.text = self.spotObject.address
                cell.directionsButton.addTarget(self, action: #selector(self.directions), for: .touchUpInside)
                
                cell.addressLabel.sizeToFit()
                
                return cell
            }
            
            
        } else if (indexPath.row == 7) {
            if (spotObject.tag1 == "" || self.spotObject.directions == "") {
                if (spotObject.tips == "") {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "EventsCell")! as! SpotPageEventsCell
                    cell.setUp(events: eventsList)
                    return cell
                }
                let cell = tableView.dequeueReusableCell(withIdentifier: "TipsCell")! as! TipsCell
                
                cell.setUp()
                
                cell.expandedTips.text = self.spotObject.tips
                cell.expandedTips!.sizeToFit()
                
                cell.expandButton.tag = indexPath.row
                cell.expandButton.addTarget(self, action: #selector(self.tipExpand(_:)), for: .touchUpInside)
                
                if (tipExpand) {
                    cell.expandButton.setImage(UIImage(named: "Minimize"), for: UIControl.State.normal)
                } else {
                    cell.expandButton.setImage(UIImage(named: "Expand"), for: UIControl.State.normal)
                }
                
                
                
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DirectionsCell")! as! DirectionsCell
                
                cell.setUp()
                
                cell.expandedWalking.text = self.spotObject.directions
                cell.expandedWalking!.sizeToFit()
                
                cell.expandButton.tag = indexPath.row
                cell.expandButton.addTarget(self, action: #selector(self.walkingExpand(_:)), for: .touchUpInside)
                
                if (walkingExpand) {
                    cell.expandButton.setImage(UIImage(named: "Minimize"), for: UIControl.State.normal)
                } else {
                    cell.expandButton.setImage(UIImage(named: "Expand"), for: UIControl.State.normal)
                }
                
                return cell
            }
            
        } else if (indexPath.row == 8) {
            if self.spotObject.tips == "" || self.spotObject.directions == "" || self.spotObject.tag1 == "" {
                let cell = tableView.dequeueReusableCell(withIdentifier: "EventsCell")! as! SpotPageEventsCell
                cell.setUp(events: eventsList)
                return cell
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "TipsCell")! as! TipsCell
            
            cell.setUp()
            
            cell.expandedTips.text = self.spotObject.tips
            cell.expandedTips!.sizeToFit()
            
            cell.expandButton.tag = indexPath.row
            cell.expandButton.addTarget(self, action: #selector(self.tipExpand(_:)), for: .touchUpInside)
            
            if (tipExpand) {
                cell.expandButton.setImage(UIImage(named: "Minimize"), for: UIControl.State.normal)
            } else {
                cell.expandButton.setImage(UIImage(named: "Expand"), for: UIControl.State.normal)
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "EventsCell")! as! SpotPageEventsCell
            cell.setUp(events: eventsList)
            return cell
        }
        
    }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 400
    }
    
    
    @objc func notifyCheckIn (_ notification:Notification) {
        print("check in about noti posted")
    }
    
    @objc func eventTap (_ notification:Notification) {
        if let dict = notification.userInfo {
            let eventID = dict["eventID"] as! String
            if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "EventsOverview") as? EventsOverviewController {
                if self.userLat != nil {
                    vc.currentLocation = CLLocation(latitude: userLat!, longitude: userLong!)
                } else {
                    vc.currentLocation = CLLocation(latitude: 0.0, longitude: 0.0)
                }
                vc.event = self.eventsList.last(where: {$0.eventID == eventID})
                vc.navigationItem.backBarButtonItem?.title = ""
                self.navigationController!.pushViewController(vc, animated: true)
            }
        }
    }
    
    @objc func imageSwipe(_ gesture: UIGestureRecognizer) {
        
        if let swipe = gesture as? UIPanGestureRecognizer {
            let direction = swipe.velocity(in: view)
            
            let translation = swipe.translation(in: self.view)
            
            if abs(translation.y) > abs(translation.x) {
                return
            }
            if direction.x < 0 {
                if self.selectedImageIndex != self.spotImages.count - 1 {
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SpotImageCell {
                        
                        let frame0 = CGRect(x: 0 + translation.x, y: cell.spotImgView!.frame.minY, width: cell.spotImgView!.frame.width, height: cell.spotImgView!.frame.height)
                        cell.spotImgView!.frame = frame0
                        
                        let frame1 = CGRect(x: cell.spotImgView!.frame.minX + cell.spotImgView!.frame.width, y: cell.spotImgViewNext!.frame.minY, width: cell.spotImgViewNext!.frame.width, height: cell.spotImgViewNext!.frame.height)
                        cell.spotImgViewNext.frame = frame1
                        
                        if swipe.state == .ended {
                            
                            if frame1.minX + direction.x < UIScreen.main.bounds.width/2 {
                                print("less than")
                                UIView.animate(withDuration: 0.3, animations: { (cell.spotImgViewNext.frame = CGRect(x: 0, y: cell.spotImgViewNext!.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3)))
                                    self.selectedImageIndex = self.selectedImageIndex + 1
                                    self.tableView.reloadData()})
                            } else {
                                print("not less than")
                                UIView.animate(withDuration: 0.3, animations: { (cell.spotImgView.frame = CGRect(x: 0, y: cell.spotImgView.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3)))
                                    cell.spotImgViewNext.frame = CGRect(x: UIScreen.main.bounds.width, y: cell.spotImgViewNext!.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3))
                                    self.tableView.reloadData()
                                })
                                
                                //    self.selectedImageIndex = self.selectedImageIndex + 1
                                //    self.tableView.reloadData()
                            }
                        }
                    }
                } else {
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SpotImageCell {
                        
                        let frame0 = CGRect(x: 0 + translation.x, y: cell.spotImgView!.frame.minY, width: cell.spotImgView!.frame.width, height: cell.spotImgView!.frame.height)
                        cell.spotImgView!.frame = frame0
                        
                        if swipe.state == .ended {
                            
                            UIView.animate(withDuration: 0.3, animations: { (cell.spotImgView.frame = CGRect(x: 0, y: cell.spotImgView.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3)))
                                self.tableView.reloadData()
                            })
                        }
                    }
                }
            } else {
                if self.selectedImageIndex != 0 {
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SpotImageCell {
                        
                        let frame0 = CGRect(x: 0 + translation.x, y: cell.spotImgView!.frame.minY, width: cell.spotImgView!.frame.width, height: cell.spotImgView!.frame.height)
                        cell.spotImgView!.frame = frame0
                        
                        let frame1 = CGRect(x: cell.spotImgView!.frame.minX - cell.spotImgView!.frame.width, y: cell.spotImgViewPrevious.frame.minY, width: cell.spotImgViewPrevious.frame.width, height: cell.spotImgViewPrevious.frame.height)
                        cell.spotImgViewPrevious.frame = frame1
                        
                        if swipe.state == .ended {
                            if frame1.maxX + direction.x > UIScreen.main.bounds.width/2 {
                                print("greater than")
                                UIView.animate(withDuration: 0.3, animations: { (cell.spotImgViewPrevious.frame = CGRect(x: 0, y: cell.spotImgViewPrevious.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3)))
                                    self.selectedImageIndex = self.selectedImageIndex - 1
                                    self.tableView.reloadData()
                                })
                            } else {
                                print("not greater than")
                                UIView.animate(withDuration: 0.3, animations: { (cell.spotImgView.frame = CGRect(x: 0, y: cell.spotImgView.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3)))
                                    cell.spotImgViewPrevious.frame = CGRect(x: -UIScreen.main.bounds.width, y: cell.spotImgViewPrevious.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3))
                                    self.tableView.reloadData()
                                })
                                
                                //    self.selectedImageIndex = self.selectedImageIndex + 1
                            }
                            
                        }
                    }
                } else {
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SpotImageCell {
                        
                        let frame0 = CGRect(x: 0 + translation.x, y: cell.spotImgView!.frame.minY, width: cell.spotImgView!.frame.width, height: cell.spotImgView!.frame.height)
                        cell.spotImgView!.frame = frame0
                        
                        if swipe.state == .ended {
                            
                            UIView.animate(withDuration: 0.3, animations: { (cell.spotImgView.frame = CGRect(x: 0, y: cell.spotImgView.frame.minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * (2/3)))
                                self.tableView.reloadData()
                            })
                        }
                    }
                }
            }
        }
    }
    
    @objc func notifyEdit (_ notification:Notification) {
        
        prepareCellsForReuse()
        
        if let dict = notification.userInfo {
            
            spotObject.spotName = dict["name"] as! String
            let nLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 34, height: 20))
            nLabel.font = UIFont(name: "SFCamera-Semibold", size: 27)
            nLabel.numberOfLines = 0
            nLabel.lineBreakMode = .byWordWrapping
            nLabel.text = spotObject.spotName
            nLabel.sizeToFit()
            self.spotNameHeight = nLabel.frame.height
            
            self.title = dict["name"] as? String
            
            if (self.parent != nil) {self.parent!.title = dict["name"] as? String}
            
            spotObject.description = dict["description"] as! String
            
            let dLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 40, height: 20))
            dLabel.font = UIFont(name: "SFCamera-regular", size: 13)
            dLabel.numberOfLines = 0
            dLabel.lineBreakMode = .byWordWrapping
            dLabel.text = self.spotObject.description
            dLabel.sizeToFit()
            self.descriptionHeight = dLabel.frame.height
            
            if ((dict["tag1"] as! String != "") && spotObject.tag1 == "") {
                cellCount = cellCount + 1
            } else if ((dict["tag1"] as! String == "") && spotObject.tag1 != "") {
                cellCount = cellCount - 1
            }
            spotObject.tag1 = dict["tag1"] as! String
            spotObject.tag2 = dict["tag2"] as! String
            spotObject.tag3 = dict["tag3"] as! String
            
            spotObject.address = dict["address"] as! String
            
            let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 220, height: 20))
            tempLabel.font = UIFont(name: "SFCamera-regular", size: 13)
            tempLabel.numberOfLines = 0
            tempLabel.lineBreakMode = .byWordWrapping
            tempLabel.text = self.spotObject.address
            tempLabel.sizeToFit()
            self.addressHeight = tempLabel.frame.height
            
            
            if spotObject.tips != "" && dict["tips"] as! String == "" {
                cellCount = cellCount - 1
            } else if spotObject.tips == "" && dict["tips"] as! String != "" {
                cellCount = cellCount + 1
            }
            
            spotObject.tips = dict["tips"] as! String
            if (spotObject.tips != "") {
                let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 40, height: 20))
                tempLabel.font = UIFont(name: "SFCamera-regular", size: 13)
                tempLabel.numberOfLines = 0
                tempLabel.lineBreakMode = .byWordWrapping
                tempLabel.text = self.spotObject.tips
                tempLabel.sizeToFit()
                self.tipsHeight = tempLabel.frame.height
            }
            
            
            let imageEdited = dict["imageWasEdited"] as! Bool
            
            if (imageEdited) {
                //    spotImgView.image = UIImage()
                let images = dict["images"] as! [UIImage]
                
                self.spotImages = images
                self.selectedImageIndex = 0
                
                for image in images {
                    
                    self.imageHeight = 0
                    
                    let aspect = image.size.height / image.size.width
                    
                    if Int(UIScreen.main.bounds.width * aspect) > self.imageHeight {
                        self.imageHeight = Int(UIScreen.main.bounds.width * aspect)
                    }
                }
                
            }
            
            let privacy = dict["privacyLevel"] as! String
            
            self.labelType = privacy
            self.privacyLevel = privacy
            //
            if (self.privacyLevel == "invite") {
                self.inviteList = dict["inviteList"] as! [String]
                
                var i = 0
                self.invitePics.removeAll()
                
                for invite in self.inviteList {
                    
                    self.db.collection("users").document(invite).getDocument { (urlSnap, err) in
                        
                        if let err = err {
                            print("Error getting documents: \(err)")
                        } else{
                            let url = urlSnap?.get("imageURL") as! String
                            let ref = Storage.storage().reference(forURL: url)
                            ref.getData(maxSize: 1 * 2048 * 2048) { data, error in
                                if error != nil {
                                    print("error occured")
                                } else {
                                    let image = UIImage(data: data!)
                                    self.invitePics.append((id: invite, imageURL: url, image: image!))
                                    i = i + 1
                                    if (i == self.inviteList.count) {
                                        self.tableView.reloadData()
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                tableView.reloadData()
            }
            //  spotLabel.sizeToFit()
            // descriptionLabel.sizeToFit()
            //  addressLabel.sizeToFit()
            
        }
    }
    func prepareCellsForReuse () {
        let cells = tableView.visibleCells
        for cell in cells {
            cell.prepareForReuse()
        }
    }
    
    @objc func directions(_ sender: UIButton) {
        
        Analytics.logEvent("aboutSpotUserClickedDirections", parameters: nil)
        
        if (UIApplication.shared.canOpenURL(URL(string:"comgooglemaps://")!)) {
            UIApplication.shared.open(URL(string: "comgooglemaps://?saddr=\(userLat!),\(userLong!)&daddr=\(spotLat!),\(spotLong!)")!)
        } else {
            UIApplication.shared.open(URL(string: "http://maps.apple.com/?saddr=\(userLat!),\(userLong!)&daddr=\(spotLat!),\(spotLong!)")!)
        }
    }
    
    @objc func walkingExpand(_ sender: UIButton) {
        if (walkingExpand) {
            walkingExpand = false
        } else {
            walkingExpand = true
        }
        let indexPath = IndexPath(item: sender.tag, section: 0)
        tableView.reloadData()
        self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        
    }
    
    @objc func tipExpand(_ sender: UIButton) {
        if (tipExpand) {
            tipExpand = false
        } else {
            tipExpand = true
        }
        tableView.reloadData()
        let newPath = IndexPath(item: cellCount-1, section: 0)
        self.tableView.scrollToRow(at: newPath, at: .bottom, animated: true)
        
    }
    
    @objc func checkIn(_ sender: UIButton) {
        
        print("check in ran")
        Analytics.logEvent("aboutSpotUserCheckedIn", parameters: nil)
        //  ref.updateData(["spotsList": FieldValue.arrayUnion([spotID!])
        //  ])
        //replace this once Geofirestore updates
        
        timer?.invalidate()
        
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        let posts: [String] = []
        
        let ref = self.db.collection("spots").document(self.spotID)
        self.db.runTransaction({ (transaction, errorPointer) -> Any? in
            let spotDoc: DocumentSnapshot
            do {
                try spotDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            self.visitorList = spotDoc.data()?["visitorList"] as! [String]
            self.visitorList.append(self.uid)
            
            transaction.updateData([
                "visitorList": self.visitorList
            ], forDocument: ref)
            
            return nil
            
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
            }
        }
        
        db.collection("users").document(self.uid).collection("spotsList").document(spotID!).setData(["spotID" : spotID!, "postsList": posts, "checkInTime" : time], merge: true)
        
        checkedInHere = true
        checkInHidden = true
        self.checkInButton.isHidden = true
        
        let infoPass = ["spotID": self.spotID!] as [String : Any]
        
        NotificationCenter.default.post(name: self.checkInNotificationName, object: nil, userInfo: infoPass)
        
        let storyboard = UIStoryboard(name: "SpotPage", bundle: nil)
        let parent = self.parent as! SpotViewController
        let sister = storyboard.instantiateViewController(withIdentifier: "SpotFeedVC") as! GuestbookViewController
        sister.spotID = self.spotID!
        parent.spotID = self.spotID
        parent.checkedInHere = self.checkedInHere
        parent.checkInHidden = self.checkInHidden
        
        parent.segmentedControl.selectedSegmentIndex = 1
        parent.segmentedControl.setEnabled(true, forSegmentAt: 1)
        parent.shadowSeg.setImage(UIImage(named: "GuestbookHighlighted"), for: UIControl.State.normal)
        parent.remove(asChildViewController: self)
        parent.add(asChildViewController: sister)
        
        
    }
    
    @objc func tagTap(gesture: UIGestureRecognizer) {
        let clickedID = gesture.accessibilityLabel!
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "ProfileMain") as? ProfileViewController {
            vc.id = clickedID
            vc.navigationItem.backBarButtonItem?.title = ""
            self.navigationController!.pushViewController(vc, animated: true)
        }
    }
    
    @objc func founderTap(_ sender:UIButton){
        let clickedID = self.founderID
        Analytics.logEvent("aboutSpotFounderClick", parameters: nil)
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "ProfileMain") as? ProfileViewController {
            vc.id = clickedID!
            vc.navigationItem.backBarButtonItem?.title = ""
            self.navigationController!.pushViewController(vc, animated: true)
        }
    }
    
    @objc func picToCheckInTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "CreatePost") as? CreatePostViewController {
            vc.spotID = self.spotID
            vc.spotName = self.spotObject.spotName
            vc.spotFounder = self.founderID
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}



class SpotPageEventsCell: UITableViewCell {
    var eventsScroll: UIScrollView!
    var eventTime: UILabel!
    var eventImage: UIImageView!
    var spotName: UILabel!
    var eventName: UILabel!
    var eventsTitle: UILabel!
    var activeDot: UIImageView!
    
    func setUp(events: [Event]) {
        
        self.selectionStyle = UITableViewCell.SelectionStyle.none
        self.backgroundColor = UIColor(named: "SpotBlack")
        
        eventsScroll = UIScrollView(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 200))
        eventsScroll.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(eventsScroll)
        
        eventsTitle = UILabel(frame: CGRect(x: 18, y: 5, width: 150, height: 13))
        eventsTitle.text = "EVENTS"
        eventsTitle.font = UIFont(name: "SFCamera-Semibold", size: 14)
        eventsTitle.textColor = UIColor.white
        eventsTitle.sizeToFit()
        self.addSubview(eventsTitle)
        
        var xOffset:CGFloat = 18
        
        for i in 0...events.count - 1 {
            let view = UIView(frame: CGRect(x: xOffset, y: 0, width: 170, height: 170))
            
            
            eventTime = UILabel(frame: CGRect(x: 0, y: 5, width: 88, height: 13))
            eventTime.lineBreakMode = .byTruncatingTail
            eventTime.textColor = UIColor.lightGray
            let rawDate = events[i].date
            
            let dateFormatter1 = DateFormatter()
            var secondsFromGMT: Int { return TimeZone.current.secondsFromGMT() }
            dateFormatter1.timeZone = TimeZone(secondsFromGMT: secondsFromGMT)
            dateFormatter1.locale = NSLocale.current
            dateFormatter1.setLocalizedDateFormatFromTemplate("h:mm a")
            
            let dateFormatter2 = DateFormatter()
            dateFormatter2.timeZone = TimeZone(secondsFromGMT: secondsFromGMT)
            dateFormatter2.locale = NSLocale.current
            
            var tString = ""
            let calendar = Calendar.current
            if calendar.isDateInToday(rawDate!) {
                tString = "Today"
            } else if calendar.isDateInTomorrow(rawDate!) {
                tString = "Tomorrow"
            }
            
            if tString == "" {
                dateFormatter2.setLocalizedDateFormatFromTemplate("MMM d")
                let temp1 = dateFormatter1.string(from: rawDate!)
                let temp2 = dateFormatter2.string(from: rawDate!)
                eventTime.text = "\(temp2) ∙ \(temp1)"
            } else {
                let temp = dateFormatter1.string(from: rawDate!)
                eventTime.text = "\(tString) ∙ \(temp)"
            }
            eventTime.font = UIFont(name: "SFCamera-Semibold", size: 13)!
            //    dateTimestamp.sizeToFit()
            eventTime.sizeToFit()
            view.addSubview(eventTime)
            
            eventImage = UIImageView(frame: CGRect(x: 0, y: 25, width: 151, height: 108))
            eventImage.image = events[i].eventImage
            eventImage.contentMode = .scaleAspectFill
            eventImage.layer.cornerRadius = 6
            eventImage.clipsToBounds = true
            view.addSubview(eventImage)
            
            let activeDot = UIImageView(frame: CGRect(x: eventImage.bounds.width - 20, y: eventImage.bounds.minY + 10, width: 35, height: 35))
            let greenActive = UIImage(named: "GreenActiveDot")
            activeDot.image = greenActive
            activeDot.contentMode = .scaleAspectFill
            
            if (events[i].active) {
                view.addSubview(activeDot)
            }
            
            let imageButton = UIButton(frame: eventImage.frame)
            imageButton.backgroundColor = nil
            imageButton.addTarget(self, action: #selector(self.tapped(_:)), for: .touchUpInside)
            imageButton.accessibilityLabel = events[i].eventID
            imageButton.isUserInteractionEnabled = true
            view.addSubview(imageButton)
            
            eventName = UILabel(frame: CGRect(x: 0, y: 140, width: 150, height: 15))
            eventName.text = events[i].eventName
            eventName.font = UIFont(name: "SFCamera-Regular", size: 14)
            eventName.textColor = UIColor.white
            eventName.sizeToFit()
            
            view.addSubview(eventName)
            eventsScroll.addSubview(view)
            
            xOffset = xOffset + CGFloat(170)
        }
        eventsScroll.contentSize = CGSize(width: xOffset, height: eventsScroll.frame.height)
    }
    override func prepareForReuse() {
        eventsScroll.removeFromSuperview()
    }
    
    @objc func tapped(_ sender: UIButton) {
        let eventTapNotificationName = Notification.Name("eventTap")
        let infoPass = ["eventID": sender.accessibilityLabel!] as [String : Any]
        NotificationCenter.default.post(name: eventTapNotificationName, object: nil, userInfo: infoPass)
    }
    
}
extension AboutSpotViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
*/
