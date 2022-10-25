//
//  EventsViewController.swift
//  Spot
//
//  Created by kbarone on 11/14/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import Foundation
import Geofirestore
import UIKit

class EventsViewController: UIViewController, UIGestureRecognizerDelegate, UITabBarControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var locationOfFirstTap: CGFloat!
    var listener1, listener2, listener3, listener4, listener5, listener6, listener7, listener8, listener9: ListenerRegistration!
    var region: CLCircularRegion!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    var friendsList: [String] = []

    var mainScroll: UIScrollView!

    let eventsScroll: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    let eventsLayout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()

    var popularScroll: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    var botPicksScroll: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    var simpleLayout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()

    var noEventsLabel: UILabel!
    var noPopularLabel: UILabel!
    var noPicksLabel: UILabel!

    var cityName: UILabel!

    var eventsList: [Event] = []
    var popularSpots: [SpotSimple] = []
    var botPicks: [SpotSimple] = []
    var loaded = false

    var startingLocation: CLLocation = CLLocation(latitude: 0.0, longitude: 0.0)
    var currentLocation: CLLocation!

    let locationManager: CLLocationManager = CLLocationManager()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tabBarController?.delegate = self

        if self.view.frame.minY != 85 && self.view.frame.minY != 60 {
            UIView.animate(withDuration: 0.3) { [weak self] in
                let frame = self?.view.frame
                var yComponent: CGFloat = 0
                if UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792 {
                    yComponent = UIScreen.main.bounds.height - 300 - (self?.tabBarController?.tabBar.bounds.height ?? 80)
                } else {
                    yComponent = UIScreen.main.bounds.height - 270 - (self?.tabBarController?.tabBar.bounds.height ?? 80)
                }
                self?.view.frame = CGRect(x: 0, y: yComponent, width: frame!.width, height: frame!.height)
                if self?.mainScroll != nil {
                    self?.mainScroll.setContentOffset(CGPoint(x: self!.mainScroll.contentOffset.x, y: 0), animated: false)
                }

                self?.loaded = true
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mainScroll = UIScrollView(frame: view.frame)
        //     mainScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: 1000)
        mainScroll.backgroundColor = UIColor(named: "SpotBlack")
        mainScroll.isScrollEnabled = true
        mainScroll.isUserInteractionEnabled = true
        mainScroll.showsVerticalScrollIndicator = false
        view.addSubview(mainScroll)

        //     prepareBackgroundView()
        view.backgroundColor = .clear
        loadScrollViews()

        let gesture = UIPanGestureRecognizer(target: self, action: #selector(EventsViewController.panGesture))
        gesture.delegate = self
        view.addGestureRecognizer(gesture)

        if CLLocationManager.locationServicesEnabled() == true {
            if CLLocationManager.authorizationStatus() == .restricted ||
                CLLocationManager.authorizationStatus() == .denied ||
                CLLocationManager.authorizationStatus() == .notDetermined {

                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.desiredAccuracy = 1.0
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
            if let loc = locationManager.location {
                startingLocation = loc
            }
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.removeListeners1()
        self.removeListeners2()
        self.removeListeners3()
        locationManager.stopUpdatingLocation()
    }
    // not called right now
    func prepareBackgroundView() {
        let blurEffect = UIBlurEffect(style: .dark)
        let visualEffect = UIVisualEffectView(effect: blurEffect)
        let bluredView = UIVisualEffectView(effect: blurEffect)
        bluredView.contentView.addSubview(visualEffect)

        visualEffect.frame = UIScreen.main.bounds
        bluredView.frame = UIScreen.main.bounds

        mainScroll.insertSubview(bluredView, at: 0)
    }

    @objc func panGesture(recognizer: UIPanGestureRecognizer) {

        let translation = recognizer.translation(in: self.view)
        let y = self.view.frame.minY

        if recognizer.state == .began {
            locationOfFirstTap = recognizer.location(in: view.superview).y
        }
        let direction = recognizer.velocity(in: view)

        self.view.frame = CGRect(x: 0, y: y + translation.y, width: view.frame.width, height: view.frame.height)

        if recognizer.state == .ended {
            if direction.y < 0 {
                if UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792 {
                    UIView.animate(withDuration: 0.15, animations: { self.view.frame = CGRect(x: 0, y: 85, width: self.view.frame.width, height: self.view.frame.height) })
                    mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                    Analytics.logEvent("EventsPageOpened", parameters: nil)
                } else {
                    UIView.animate(withDuration: 0.15, animations: { self.view.frame = CGRect(x: 0, y: 60, width: self.view.frame.width, height: self.view.frame.height) })
                    mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                    Analytics.logEvent("EventsPageOpened", parameters: nil)
                }
            } else {
                if UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792 {
                    UIView.animate(withDuration: 0.15, animations: { self.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 300, width: self.view.frame.width, height: self.view.frame.height) })
                    mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                    Analytics.logEvent("EventsPageClosed", parameters: nil)

                } else {
                    UIView.animate(withDuration: 0.15, animations: { self.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 270, width: self.view.frame.width, height: self.view.frame.height) })
                    mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                    Analytics.logEvent("EventsPageClosed", parameters: nil)

                }
            }
        }
        recognizer.setTranslation(.zero, in: self.view)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let gesture = (gestureRecognizer as! UIPanGestureRecognizer)
        let direction = gesture.velocity(in: view).y
        var fullView: CGFloat = 0
        var partialView: CGFloat = 0

        let y = view.frame.minY

        if UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792 {
            fullView = 85
            partialView = UIScreen.main.bounds.height - CGFloat(300)
        } else {
            fullView = 60
            partialView = UIScreen.main.bounds.height - CGFloat(270)
        }

        if (y == fullView && mainScroll.contentOffset.y <= 50 && direction > 0) || (y == partialView) {
            mainScroll.isScrollEnabled = false
        } else {
            mainScroll.isScrollEnabled = true
        }

        return false
    }

    func loadScrollViews() {

        let pullLine = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 13, y: 11, width: 26, height: 4))
        pullLine.image = UIImage(named: "PullLine")
        mainScroll.addSubview(pullLine)

        cityName = UILabel(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 80, y: 18.5, width: 160, height: 21))
        cityName.textColor = UIColor.lightGray
        cityName.font = UIFont(name: "SFCamera-Semibold", size: 15)
        self.mainScroll.addSubview(self.cityName)

        let touchArea = UIButton(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 150, y: 10, width: 300, height: 35))
        touchArea.addTarget(self, action: #selector(cityTap(_:)), for: .touchUpInside)
        mainScroll.addSubview(touchArea)

        let experiencesLabel = UILabel(frame: CGRect(x: 20, y: 56, width: 100, height: 20))
        experiencesLabel.text = "EVENTS"
        experiencesLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        experiencesLabel.textColor = UIColor.white

        let attTtitleE = NSAttributedString(string: (experiencesLabel.text!), attributes: [NSAttributedString.Key.kern: 1])
        experiencesLabel.attributedText = attTtitleE

        experiencesLabel.sizeToFit()
        mainScroll.addSubview(experiencesLabel)

        eventsLayout.scrollDirection = .horizontal
        eventsLayout.itemSize = CGSize(width: 160, height: 170)

        eventsScroll.setCollectionViewLayout(eventsLayout, animated: true)
        eventsScroll.delegate = self
        eventsScroll.dataSource = self
        eventsScroll.frame = CGRect(x: 0, y: 70, width: UIScreen.main.bounds.width, height: 200)
        eventsScroll.showsHorizontalScrollIndicator = false
        eventsScroll.backgroundColor = nil
        mainScroll.addSubview(eventsScroll)
        eventsScroll.register(EventPageEventsCell.self, forCellWithReuseIdentifier: "eventCell")
        eventsScroll.accessibilityLabel = "event"

        noEventsLabel = UILabel(frame: CGRect(x: 20, y: 50, width: UIScreen.main.bounds.width - 20, height: 20))
        noEventsLabel.text = "It doesn't look like there are any events in your area :("
        noEventsLabel.numberOfLines = 0
        noEventsLabel.lineBreakMode = .byWordWrapping
        noEventsLabel.font = UIFont(name: "SFCamera-regular", size: 16)
        noEventsLabel.textColor = UIColor.lightGray
        noEventsLabel.sizeToFit()
        self.eventsScroll.addSubview(noEventsLabel)

        let popularLabel = UILabel(frame: CGRect(x: 20, y: 297, width: 100, height: 20))
        popularLabel.text = "FOR YOU"
        popularLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        popularLabel.textColor = UIColor.white

        let attTtitleP = NSAttributedString(string: (popularLabel.text!), attributes: [NSAttributedString.Key.kern: 1])
        popularLabel.attributedText = attTtitleP

        popularLabel.sizeToFit()
        mainScroll.addSubview(popularLabel)

        simpleLayout.scrollDirection = .horizontal
        simpleLayout.itemSize = CGSize(width: 120, height: 220)

        popularScroll.setCollectionViewLayout(simpleLayout, animated: true)
        popularScroll.delegate = self
        popularScroll.dataSource = self
        popularScroll.frame = CGRect(x: 0, y: 320, width: UIScreen.main.bounds.width, height: 230)
        popularScroll.showsHorizontalScrollIndicator = false
        popularScroll.backgroundColor = nil
        mainScroll.addSubview(popularScroll)
        popularScroll.register(SimpleCell.self, forCellWithReuseIdentifier: "simpleCell")
        popularScroll.accessibilityLabel = "popular"

        noPopularLabel = UILabel(frame: CGRect(x: 20, y: 50, width: UIScreen.main.bounds.width - 30, height: 20))
        noPopularLabel.text = "It doesn't look like there are any popular spots in your area. Upload a spot and it could be featured on this page!"
        noPopularLabel.numberOfLines = 0
        noPopularLabel.lineBreakMode = .byWordWrapping
        noPopularLabel.font = UIFont(name: "SFCamera-regular", size: 16)
        noPopularLabel.textColor = UIColor.lightGray
        noPopularLabel.sizeToFit()
        noPopularLabel.isHidden = true
        self.popularScroll.addSubview(noPopularLabel)

        let botPicksLabel = UILabel(frame: CGRect(x: 20, y: 582, width: 100, height: 20))
        botPicksLabel.text = "SP0TB0T PICKS"
        botPicksLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        botPicksLabel.textColor = UIColor.white

        let attTtitleB = NSAttributedString(string: (botPicksLabel.text!), attributes: [NSAttributedString.Key.kern: 1])
        botPicksLabel.attributedText = attTtitleB

        botPicksLabel.sizeToFit()
        mainScroll.addSubview(botPicksLabel)

        let botPicksImage = UIImageView(frame: CGRect(x: 142, y: 573, width: 26.4, height: 30))
        botPicksImage.image = UIImage(named: "TheB0t")
        botPicksImage.contentMode = .scaleAspectFill
        mainScroll.addSubview(botPicksImage)

        botPicksScroll.setCollectionViewLayout(simpleLayout, animated: true)
        botPicksScroll.delegate = self
        botPicksScroll.dataSource = self
        botPicksScroll.frame = CGRect(x: 0, y: 610, width: UIScreen.main.bounds.width, height: 230)
        botPicksScroll.showsHorizontalScrollIndicator = false
        botPicksScroll.backgroundColor = nil
        mainScroll.addSubview(botPicksScroll)
        botPicksScroll.register(SimpleCell.self, forCellWithReuseIdentifier: "simpleCell")
        botPicksScroll.accessibilityLabel = "bot"

        noPicksLabel = UILabel(frame: CGRect(x: 20, y: 50, width: UIScreen.main.bounds.width - 30, height: 20))
        noPicksLabel.text = "The Sp0tb0t hasn't touched down in your city yet... Once they do, you'll see a curated selection of nearby spots here."
        noPicksLabel.numberOfLines = 0
        noPicksLabel.lineBreakMode = .byWordWrapping
        noPicksLabel.font = UIFont(name: "SFCamera-regular", size: 16)
        noPicksLabel.textColor = UIColor.lightGray
        noPicksLabel.sizeToFit()
        self.botPicksScroll.addSubview(noPicksLabel)

        mainScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: 1_000)

        getUserInfo()
    }

    func getUserInfo() {
        DispatchQueue.global().async {
            self.listener1 = self.db.collection("users").document(self.uid).addSnapshotListener { (snapshot, err) in

                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    if let friends = snapshot?.get("friendsList") as? [String] {
                        self.friendsList = friends
                        if self.currentLocation != nil {
                            self.loadAllEvents()
                            self.loadPopular()
                            self.loadBotPicks()
                        }
                    }
                }
            }
        }
    }

    func loadAllEvents() {
        self.listener2 = self.db.collection("spots").addSnapshotListener({ (spotSnapshot, _) in

            docLoop: for doc in spotSnapshot!.documents {
                if let privacyLevel = doc.get("privacyLevel") as? String {
                    if privacyLevel == "friends" {
                        let creatorID = doc.get("createdBy") as! String
                        if !self.friendsList.contains(creatorID) && creatorID != self.uid {

                            continue docLoop

                        }
                    } else if privacyLevel == "invite" {
                        if let inviteList = doc.get("inviteList") as? [String] {
                            if !inviteList.contains(self.uid) {

                                continue docLoop
                            }
                        } else {

                            continue docLoop
                        }
                    }
                    let spotID = doc.documentID

                    let arrayLocation = doc.get("l") as! [NSNumber]
                    let spotLat = arrayLocation[0] as! Double
                    let spotLong = arrayLocation[1] as! Double

                    if self.region.contains(CLLocationCoordinate2D(latitude: spotLat, longitude: spotLong)) {

                        self.listener3 = self.db.collection("spots").document(doc.documentID).collection("events").addSnapshotListener({ (eventsSnap, _) in
                            if eventsSnap?.documents.count != 0 {

                                for event in eventsSnap!.documents {
                                    self.noEventsLabel.isHidden = true

                                    let eventID = event.documentID
                                    var rawTimeStamp = Timestamp()
                                    rawTimeStamp = event.get("timestamp") as! Timestamp
                                    let seconds = rawTimeStamp.seconds

                                        let timestamp = NSDate().timeIntervalSince1970 as Double
                                        let i = Int64(timestamp)
                                        // checking if the event has already happened (2 hour grace period)
                                        if i < seconds + 7_200 {
                                            var active = false
                                            if i < seconds + 7_200 && i > seconds {
                                                active = true
                                            }
                                            let date = rawTimeStamp.dateValue()
                                            let imageURL = event.get("imageURL") as! String
                                            let spotName = doc.get("spotName") as! String
                                            let eventName = event.get("eventName") as! String
                                            let arrayLocation = doc.get("l") as! [NSNumber]

                                            let price = event.get("price") as! Int
                                            let description = event.get("description") as! String

                                            let spotLat = arrayLocation[0] as! Double
                                            let spotLong = arrayLocation[1] as! Double

                                            if !self.eventsList.contains(where: { $0.eventID == eventID }) {
                                                let newEvent = (Event(spotID: spotID, eventID: eventID, time: seconds, date: date, imageURL: imageURL, eventImage: UIImage(), spotName: spotName, eventName: eventName, spotLat: spotLat, spotLong: spotLong, active: active, price: price, description: description))
                                                self.eventsList.append(newEvent)
                                                self.getEventImages(event: newEvent)
                                            }
                                        }

                                }
                            }
                        })
                    }
                }

            }
        })
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView.accessibilityLabel == "event" {
            return(CGSize(width: 160, height: 170))
        } else {
            return(CGSize(width: 120, height: 220))
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 15, bottom: 5, right: 15)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.accessibilityLabel == "event" {
            if !eventsList.isEmpty {
                if eventsList.count < 10 {
                    return eventsList.count
                } else {
                    return 10
                }
            } else {
                return 0
            }
        } else if collectionView.accessibilityLabel == "bot" {
                if !botPicks.isEmpty {
                    if botPicks.count < 7 {
                        return botPicks.count
                    } else {
                        return 7
                    }
                }
        } else {
            if !popularSpots.isEmpty {
                if popularSpots.count < 5 {
                    return popularSpots.count
                } else {
                    return 5
                }
            }
        }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if collectionView.accessibilityLabel == "event" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "eventCell", for: indexPath) as! EventPageEventsCell

            if self.eventsList.isEmpty {
                return cell
            }
            // initialize new spot cell
            cell.setUp(event: eventsList[indexPath.row])

            let imageButton = UIButton(frame: cell.eventImage.frame)
            imageButton.backgroundColor = nil
            imageButton.addTarget(self, action: #selector(spotTapped(_:)), for: .touchUpInside)
            imageButton.tag = indexPath.row
            imageButton.accessibilityLabel = "event"
            cell.addSubview(imageButton)

            let spotNameButton = UIButton(frame: cell.spotName.frame)
            spotNameButton.tag = indexPath.row
            spotNameButton.accessibilityLabel = "event"
            spotNameButton.addTarget(self, action: #selector(spotTapped(_:)), for: .touchUpInside)
            cell.addSubview(spotNameButton)

            cell.backgroundColor = UIColor(named: "SpotBlack")

            return(cell)
        } else if collectionView.accessibilityLabel == "popular" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "simpleCell", for: indexPath) as! SimpleCell
            if self.popularSpots.isEmpty {return cell}
            cell.setUp(spot: popularSpots[indexPath.row])

            let imageButton = UIButton(frame: cell.spotimage.frame)
           imageButton.backgroundColor = nil
           imageButton.addTarget(self, action: #selector(self.spotTapped(_:)), for: .touchUpInside)
            imageButton.tag = indexPath.row
           imageButton.accessibilityLabel = "popular"
           imageButton.isUserInteractionEnabled = true
           cell.addSubview(imageButton)

           let spotNameButton = UIButton(frame: cell.spotName.frame)
           spotNameButton.tag = indexPath.row
           spotNameButton.accessibilityLabel = "popular"
           spotNameButton.addTarget(self, action: #selector(self.spotTapped(_:)), for: .touchUpInside)
           cell.addSubview(spotNameButton)

            return(cell)
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "simpleCell", for: indexPath) as! SimpleCell

            if self.botPicks.isEmpty {return cell}
            cell.setUp(spot: botPicks[indexPath.row])

            let imageButton = UIButton(frame: cell.spotimage.frame)
              imageButton.backgroundColor = nil
              imageButton.addTarget(self, action: #selector(self.spotTapped(_:)), for: .touchUpInside)
              imageButton.tag = indexPath.row
              imageButton.accessibilityLabel = "bot"
              cell.addSubview(imageButton)
              self.mainScroll.isUserInteractionEnabled = true

              let spotNameButton = UIButton(frame: cell.spotName.frame)
            spotNameButton.tag = indexPath.row
              spotNameButton.accessibilityLabel = "bot"
              cell.addSubview(spotNameButton)

            return(cell)
        }

    }

    /* func loadEventScrollData() {
        var xOffset:CGFloat = 21
        var x = 9
        if (eventsList.count < 10) {
            x = eventsList.count - 1
        }
        for i in 0 ... x {
            let view = EventView(frame: CGRect(x: xOffset, y: 5, width: 170, height: 170))
            view.setUp(event: eventsList[i])
            
            let imageButton = UIButton(frame: view.eventImage.frame)
            imageButton.backgroundColor = nil
            imageButton.addTarget(self, action: #selector(spotTapped(_:)), for: .touchUpInside)
            imageButton.tag = i
            imageButton.accessibilityLabel = "event"
            view.addSubview(imageButton)
            mainScroll.isUserInteractionEnabled = true
            
            let spotNameButton = UIButton(frame: view.spotName.frame)
            spotNameButton.tag = i
            spotNameButton.accessibilityLabel = "event"
            spotNameButton.addTarget(self, action: #selector(spotTapped(_:)), for: .touchUpInside)
            view.addSubview(spotNameButton)
            
            xOffset = xOffset + CGFloat(170)
            
            eventsScroll.addSubview(view)
            ;
        }
        eventsScroll.contentSize = CGSize(width: xOffset, height: eventsScroll.frame.height)
    } */

    func getEventImages(event: Event) {
        print("get event images called")

            let ref = Storage.storage().reference(forURL: event.imageURL)
            ref.getData(maxSize: 1 * 2_048 * 2_048) { data, error in
                if error != nil {
                    return
                } else {
                    let image = UIImage(data: data!)!

                    if let temp = self.eventsList.last(where: { $0.eventID == event.eventID }) {
                        temp.eventImage = image
                        self.eventsList = self.eventsList.sorted(by: { $0.time < $1.time })
                        self.eventsScroll.reloadData()
                    }
                }
            }
    }

    func addNoEventsLabel() {
        let label = UILabel(frame: CGRect(x: 20, y: 50, width: UIScreen.main.bounds.width - 20, height: 20))
        label.text = "It doesn't look like there are any events in your area :("
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = UIFont(name: "SFCamera-regular", size: 16)
        label.textColor = UIColor.lightGray
        label.sizeToFit()
        self.eventsScroll.addSubview(label)
    }

    @objc func spotTapped(_ sender: UIButton) {
        Analytics.logEvent("eventsSpotImageTapped", parameters: nil)

        let storyboard = UIStoryboard(name: "SpotPage", bundle: nil)

        if sender.accessibilityLabel == "event" {
            if let vc = storyboard.instantiateViewController(withIdentifier: "EventsOverview") as? EventsOverviewController {
                if self.currentLocation != nil {
                    vc.currentLocation = self.currentLocation
                } else {
                    vc.currentLocation = CLLocation(latitude: 0.0, longitude: 0.0)
                }
                vc.event = eventsList[sender.tag]
                vc.navigationItem.backBarButtonItem?.title = ""
                self.navigationController!.pushViewController(vc, animated: true)

            }
        } else {

            if let vc = storyboard.instantiateViewController(withIdentifier: "SpotPage") as? SpotViewController {

                if sender.accessibilityLabel == "popular" {
                    vc.spotLat = popularSpots[sender.tag].spotLat
                    vc.spotLong = popularSpots[sender.tag].spotLong
                    vc.spotID = popularSpots[sender.tag].spotID
                } else {
                    vc.spotLat = botPicks[sender.tag].spotLat
                    vc.spotLong = botPicks[sender.tag].spotLong
                    vc.spotID = botPicks[sender.tag].spotID
                }

                vc.navigationItem.backBarButtonItem?.title = ""
                self.navigationController!.pushViewController(vc, animated: true)
            }
        }
    }

    func loadPopular() {
        self.listener4 = db.collection("spots").addSnapshotListener({ (spotSnap, _) in
            docLoop: for doc in spotSnap!.documents {
                if let privacyLevel = doc.get("privacyLevel") as? String {
                    if privacyLevel == "friends" {
                        let creatorID = doc.get("createdBy") as! String
                        if !self.friendsList.contains(creatorID) && creatorID != self.uid {
                            continue docLoop
                        }

                    } else if privacyLevel == "invite" {
                        if let inviteList = doc.get("inviteList") as? [String] {
                            if !inviteList.contains(self.uid) {
                                continue docLoop
                            }
                        } else {
                            continue docLoop
                        }
                    }

                    let spotID = doc.documentID
                    if let spotPicURL = doc.get("imageURL") as? String {

                        let arrayLocation = doc.get("l") as! [NSNumber]
                        let spotLat = arrayLocation[0] as! Double
                        let spotLong = arrayLocation[1] as! Double

                        if self.region.contains(CLLocationCoordinate2D(latitude: spotLat, longitude: spotLong)) {

                            let range: TimeInterval = 1_209_600
                            let start = NSDate().timeIntervalSince1970
                            let minSeconds = start - range
                            let min = Date(timeIntervalSince1970: (minSeconds))

                            let query = self.db.collection("spots").document(doc.documentID).collection("feedPost").whereField("timestamp", isGreaterThanOrEqualTo: min)

                            self.listener5 = query.addSnapshotListener({ (feedSnap, _) in
                                if feedSnap?.documents.count != 0 {

                                    var totalTime: Int64 = 0
                                    let spotName = doc.get("spotName") as! String

                                    let arrayLocation = doc.get("l") as! [NSNumber]
                                    let spotLat = arrayLocation[0] as! Double
                                    let spotLong = arrayLocation[1] as! Double

                                    var postIndex = 0
                                    for post in feedSnap!.documents {
                                        let rawTimeStamp = post.get("timestamp") as! Timestamp
                                        let seconds = rawTimeStamp.seconds
                                        let rawSeconds = seconds - Int64(minSeconds)
                                        var hours = rawSeconds / 3_600
                                        hours = hours * Int64((postIndex + 1))
                                        totalTime = hours + totalTime

                                        postIndex = postIndex + 1
                                        if postIndex == feedSnap!.documents.count {

                                            if !self.popularSpots.contains(where: { $0.spotID == spotID }) {
                                                let temp = SpotSimple(spotID: spotID, spotName: spotName, spotPicURL: spotPicURL, spotImage: UIImage(), spotLat: spotLat, spotLong: spotLong, time: totalTime, userPostID: "", founderID: "", privacyLevel: privacyLevel)
                                                self.popularSpots.append(temp)
                                                self.getPopularPictures(spot: temp)
                                                self.noPopularLabel.isHidden = true
                                            }
                                        }
                                    }
                                }
                            })

                    }
                }

            }
            }
        })
    }

    func getPopularPictures(spot: SpotSimple) {

        let ref = Storage.storage().reference(forURL: spot.spotPicURL)
            ref.getData(maxSize: 1 * 2_048 * 2_048) { data, error in
                if error != nil {
                    return
                } else {
                    let image = UIImage(data: data!)!
                    let newSpot = spot
                    newSpot.spotImage = image

                    if let temp = self.popularSpots.last(where: { $0.spotID == spot.spotID }) {
                        temp.spotImage = image
                        self.popularSpots = self.popularSpots.sorted(by: { $0.time > $1.time })
                        self.popularScroll.reloadData()
                    }
                }
            }
    }
 /*
    func loadFinalPopularScroll(x: Int) {
        
        var xOffset:CGFloat = 21
        self.popularSpots = self.popularSpots.sorted(by: {$0.time > $1.time})
        
        for i in 0...x {
            
            let view = SpotSimpleView(frame: CGRect(x: xOffset, y: 5, width: 120, height: 220))
            view.setUp(spot: self.popularSpots[i])
            
            let imageButton = UIButton(frame: view.spotimage.frame)
            imageButton.backgroundColor = nil
            imageButton.addTarget(self, action: #selector(self.spotTapped(_:)), for: .touchUpInside)
            imageButton.tag = i
            imageButton.accessibilityLabel = "popular"
            imageButton.isUserInteractionEnabled = true
            view.addSubview(imageButton)
            
            let spotNameButton = UIButton(frame: view.spotName.frame)
            spotNameButton.tag = i
            spotNameButton.accessibilityLabel = "popular"
            spotNameButton.addTarget(self, action: #selector(self.spotTapped(_:)), for: .touchUpInside)
            view.addSubview(spotNameButton)
            
            mainScroll.isUserInteractionEnabled = true
            
            xOffset = xOffset + CGFloat(132)
            
            self.popularScroll.addSubview(view)
            
            self.popularScroll.contentSize = CGSize(width: xOffset, height: self.popularScroll.frame.height)
        }
        
    }
    */

    func loadBotPicks() {
        var botList: [String] = []
        self.listener7 = db.collection("botpicks").addSnapshotListener({ (botSnap, _) in
            var count = 0
            if botSnap?.documents.count != 0 {
                for pick in botSnap!.documents {
                    count = count + 1
                    botList.append(pick.documentID)
                    if count == botSnap?.documents.count {
                        self.getBotInfo(bots: botList)
                    }
                }
            }
        })
    }

    func getBotInfo(bots: [String]) {
        for bot in bots {
            self.listener8 = db.collection("spots").document(bot).addSnapshotListener { (snapshot, _) in

                if let spotName = snapshot!.get("spotName") as? String {

                    let spotID = snapshot!.documentID
                    let arrayLocation = snapshot!.get("l") as! [NSNumber]
                    let spotLat = arrayLocation[0] as! Double
                    let spotLong = arrayLocation[1] as! Double

                    if self.region.contains(CLLocationCoordinate2D(latitude: spotLat, longitude: spotLong)) {
                        let spotPicURL = snapshot!.get("imageURL") as! String

                        if !self.botPicks.contains(where: { $0.spotID == spotID }) {
                            let temp = SpotSimple(spotID: spotID, spotName: spotName, spotPicURL: spotPicURL, spotImage: UIImage(), spotLat: spotLat, spotLong: spotLong, time: 0, userPostID: "", founderID: "", privacyLevel: "")
                            self.botPicks.append(temp)
                            self.getBotPictures(pick: temp)
                            self.noPicksLabel.isHidden = true
                        }
                }
            }
            }
    }
    }

    func getBotPictures(pick: SpotSimple) {

            let ref = Storage.storage().reference(forURL: pick.spotPicURL)
            ref.getData(maxSize: 1 * 2_048 * 2_048) { data, error in
                if error != nil {
                    return
                } else {
                    let image = UIImage(data: data!)!
                    if let temp = self.botPicks.last(where: { $0.spotID == pick.spotID }) {
                        temp.spotImage = image
                        self.botPicksScroll.reloadData()
                    }
            }
            }
    }

    func removeListeners1() {
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
    }
    func removeListeners2() {
        if self.listener4 != nil {
            self.listener4.remove()
        }
        if self.listener5 != nil {
            self.listener5.remove()
        }
        if self.listener6 != nil {
            self.listener6.remove()
        }
    }
    func removeListeners3() {
        if self.listener7 != nil {
            self.listener7.remove()
        }
        if self.listener9 != nil {
            self.listener8.remove()
        }
        if self.listener9 != nil {
            self.listener9.remove()
        }
    }

    func getCity() {

        CLGeocoder().reverseGeocodeLocation(self.currentLocation) { placemarks, _ in // 6
            guard let placemark = placemarks?.first else { return } // 7

            var addressString: String = ""

            if placemark.locality != nil {
                addressString = addressString + placemark.locality!
            }

            addressString = addressString.uppercased()

            self.cityName.text = addressString

            let attTtitle = NSAttributedString(string: (self.cityName.text!), attributes: [NSAttributedString.Key.kern: 1])
            self.cityName.attributedText = attTtitle

            self.cityName.sizeToFit()
            let frame = CGRect(x: UIScreen.main.bounds.width / 2 - self.cityName.frame.width / 2, y: 18.5, width: self.cityName.frame.width, height: self.cityName.frame.height)
            self.cityName.frame = frame
        }
    }

    @objc func cityTap(_ sender: UIButton) {
        let y = self.view.frame.minY

        if UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792 {
            if y == 85 {
                UIView.animate(withDuration: 0.3, animations: { self.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 300, width: self.view.frame.width, height: self.view.frame.height) })
                mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                Analytics.logEvent("EventsPageClosed", parameters: nil)

            } else if y == UIScreen.main.bounds.height - 300 {
                UIView.animate(withDuration: 0.3, animations: { self.view.frame = CGRect(x: 0, y: 85, width: self.view.frame.width, height: self.view.frame.height) })
                mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                Analytics.logEvent("EventsPageClosed", parameters: nil)
            }
        } else {
            if y == 60 {
                UIView.animate(withDuration: 0.3, animations: { self.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 270, width: self.view.frame.width, height: self.view.frame.height) })
                mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                Analytics.logEvent("EventsPageOpened", parameters: nil)
            } else if y == UIScreen.main.bounds.height - 270 {
                UIView.animate(withDuration: 0.3, animations: { self.view.frame = CGRect(x: 0, y: 60, width: self.view.frame.width, height: self.view.frame.height) })
                mainScroll.setContentOffset(CGPoint(x: mainScroll.contentOffset.x, y: 0), animated: false)

                Analytics.logEvent("EventsPageOpened", parameters: nil)
            }
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {

        let tabBarIndex = tabBarController.selectedIndex
        if tabBarIndex == 0 {
            let y = self.view.frame.minY
            if UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792 {
                if y == 85 {
                    UIView.animate(withDuration: 0.3, animations: { self.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 300, width: self.view.frame.width, height: self.view.frame.height) })
                    self.mainScroll.setContentOffset(CGPoint(x: self.mainScroll.contentOffset.x, y: 0), animated: false)

                    Analytics.logEvent("EventsPageClosed", parameters: nil)
                }
            } else {
                if y == 60 {
                    UIView.animate(withDuration: 0.3, animations: { self.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 270, width: self.view.frame.width, height: self.view.frame.height) })
                    self.mainScroll.setContentOffset(CGPoint(x: self.mainScroll.contentOffset.x, y: 0), animated: false)

                    Analytics.logEvent("EventsPageClosed", parameters: nil)
                }
            }
        }
    }
}

extension EventsViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        self.currentLocation = locations.last

        let lat = self.currentLocation.coordinate.latitude
        let long = self.currentLocation.coordinate.longitude

        self.region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: long), radius: 20_000, identifier: "region")

        getCity()
        locationManager.pausesLocationUpdatesAutomatically = true

        if eventsList.count == 0 {
            self.loadAllEvents()
            self.loadPopular()
            self.loadBotPicks()
        } else {
            if !(self.startingLocation.coordinate.latitude == 0.0) {
                let regionCheck = CLCircularRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: long), radius: 5_000, identifier: "region")
                if regionCheck.contains(CLLocationCoordinate2D(latitude: self.startingLocation.coordinate.latitude, longitude: self.startingLocation.coordinate.longitude)) {
                    return
                } else {
                    self.eventsScroll.subviews.forEach({ $0.removeFromSuperview() })
                    self.popularScroll.subviews.forEach({ $0.removeFromSuperview() })
                    self.botPicksScroll.subviews.forEach({ $0.removeFromSuperview() })
                    self.eventsList.removeAll()
                    self.popularSpots.removeAll()
                    self.botPicks.removeAll()
                    self.loadAllEvents()
                    self.loadPopular()
                    self.loadBotPicks()
                    self.startingLocation = self.currentLocation

                }
            } else {
                self.startingLocation = self.currentLocation
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Unable to access your current location")
    }
}
class EventPageEventsCell: UICollectionViewCell {
    var eventTime: UILabel!
    var eventImage: UIImageView!
    var spotName: UILabel!
    var eventName: UILabel!
    var activeDot: UIImageView!

    func setUp(event: Event) {
        eventTime = UILabel(frame: CGRect(x: 0, y: 5, width: 88, height: 13))
        eventTime.lineBreakMode = .byTruncatingTail
        eventTime.textColor = UIColor.lightGray
        let rawDate = event.date

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
        self.addSubview(eventTime)

        eventImage = UIImageView(frame: CGRect(x: 0, y: 25, width: 151, height: 108))
        eventImage.image = event.eventImage
        eventImage.contentMode = .scaleAspectFill
        eventImage.layer.cornerRadius = 6
        eventImage.clipsToBounds = true
        self.addSubview(eventImage)

        activeDot = UIImageView(frame: CGRect(x: eventImage.bounds.width - 20, y: eventImage.bounds.minY + 10, width: 35, height: 35))
        let greenActive = UIImage(named: "GreenActiveDot")
        activeDot.image = greenActive
        activeDot.contentMode = .scaleAspectFill

        if event.active {
            self.addSubview(activeDot)
        }

        spotName = UILabel(frame: CGRect(x: 0, y: 140, width: 150, height: 15))
        spotName.text = event.spotName
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 14)
        spotName.textColor = .lightGray
        spotName.numberOfLines = 0
        spotName.lineBreakMode = .byWordWrapping
        let attTitle = NSAttributedString(string: (spotName.text)!, attributes: [NSAttributedString.Key.kern: 0.5])
        spotName.attributedText = attTitle
        spotName.sizeToFit()
        self.addSubview(spotName)

        eventName = UILabel(frame: CGRect(x: 0, y: spotName.frame.maxY + 2, width: 150, height: 15))
        eventName.text = event.eventName
        eventName.font = UIFont(name: "SFCamera-Regular", size: 14)
        eventName.textColor = UIColor.white
        eventName.clipsToBounds = true
        eventName.lineBreakMode = .byWordWrapping
        eventName.numberOfLines = 0

        eventName.sizeToFit()

        self.accessibilityLabel = event.eventID
        self.addSubview(eventName)
    }
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func prepareForReuse() {
        eventName.text = ""
        spotName.text = ""
        eventTime.text = ""
        eventImage.image = UIImage()
        activeDot.image = UIImage()
    }
}
