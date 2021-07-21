//
//  NearbyViewController.swift
//  Spot
//
//  Created by kbarone on 1/28/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI
import CoreLocation
import Geofirestore
import MapKit
import Mixpanel

class NearbyViewController: UIViewController {
    
    var listener1: ListenerRegistration!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    
    var headerView: UIView!
    var mainScroll = UIScrollView()
    var shadowScroll = UIScrollView()
    
    var cityIcon: UIImageView!
    var cityName: UILabel!
    var changeCityButton: UIButton!
    
    var selectedCity: (name: String, coordinate: CLLocationCoordinate2D)! /// currently selected city
    var userCity: (name: String, coordinate: CLLocationCoordinate2D)! /// user city based on currentLocation
    
    var searchBar: UISearchBar!
    var searchBarContainer: UIView!
    var resultsTable: UITableView!
    var citiesTable: UITableView!
    var searchTextGlobal = "" /// used to compare local async search text with updated search bar text
    var searchIndicator: CustomActivityIndicator!
    var cancelButton: UIButton!
    var locationCompleter: MKLocalSearchCompleter! /// used for nearby city search
    var search: MKLocalSearch!
    
    lazy var loadingIndicator = CustomActivityIndicator()
    lazy var usersCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: LeftAlignedCollectionViewFlowLayout.init())
    lazy var tagsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: LeftAlignedCollectionViewFlowLayout.init())
    lazy var spotsTable: UITableView = UITableView(frame: CGRect.zero)
    lazy var spotsHeader: NearbySpotsHeader = NearbySpotsHeader(frame: CGRect.zero)

    lazy var queryIDs: [(id: String, score: Double)] = [] /// list of returned search items, score for ranking relevancy
    lazy var queryUsers: [UserProfile] = [] /// users returned by search query
    lazy var querySpots: [MapSpot] = [] /// spots returned by searchQuery
    lazy var queryCities = [MKLocalSearchCompletion]()
    
    var circleQuery: GFSCircleQuery?
    lazy var nearbyCityCounter = 0
    lazy var cityDuplicateCount = 0
    lazy var cityRadius: Double = 30 /// search radius for finding nearbyCities
    lazy var showQuery = false
    lazy var enteredCities: [String] = [] /// shorthand cities for duplicates before city spots fetch runs
    lazy var nearbyCities: [City] = [] /// nearbyCities to show in citiesTable

    lazy var citySpots: [(spot: MapSpot, filtered: Bool)] = [] /// spotsList for selectedCity
    lazy var cityFriends: [CityUser] = [] /// users friendsList with individual spotsList updated when city changes
    var selectedUserID: String! /// selected user filter
    lazy var sortByScore = false /// sort bool for neary spots table

    lazy var cityTags: [Tag] = [] /// tags with # of spots in selectedCity
    lazy var selectedTags: [String] = [] /// selected tag filters
    
    var sortMask: UIView!
    
    var halfScreenUserCount = 0, fullScreenUserCount = 0
    var halfScreenUserHeight: CGFloat = 0, fullScreenUserHeight: CGFloat = 0
    var expandUsers = false, usersMoreNeeded = false
    
    var halfScreenTagsCount = 0, fullScreenTagsCount = 0
    var halfScreenTagsHeight: CGFloat = 0, fullScreenTagsHeight: CGFloat = 0
    var expandTags = false, tagsMoreNeeded = false
        
    lazy var userSpots: [String] = []
    var friendsEmpty = false
    
    lazy var searchRefreshCount = 0
    
    unowned var mapVC: MapViewController!
    weak var postVC: PostViewController!
    
    var passedCamera: MKMapCamera!
        
    deinit {
        print("deinit nearby")
    }
    
    enum resultType {
        case spot
        case user
        case city
    }
    
    enum refreshStatus {
        case yesRefresh
        case refreshing
        case noRefresh
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
                
        locationCompleter = MKLocalSearchCompleter()
        locationCompleter.delegate = self
        
        addNotifications()
        
        headerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
        headerView.backgroundColor = UIColor(named: "SpotBlack")
        view.addSubview(headerView)
        
        mainScroll = UIScrollView(frame: CGRect(x: 0, y: 61, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 61))
        mainScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        mainScroll.backgroundColor = UIColor(named: "SpotBlack")
        mainScroll.isScrollEnabled = false
        mainScroll.isUserInteractionEnabled = true
        mainScroll.showsVerticalScrollIndicator = false
        view.addSubview(mainScroll)
        
        shadowScroll = UIScrollView(frame: CGRect(x: 0, y: -UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        shadowScroll.backgroundColor = nil
        shadowScroll.isScrollEnabled = false
        shadowScroll.isUserInteractionEnabled = true
        shadowScroll.showsVerticalScrollIndicator = false
        shadowScroll.delegate = self
        shadowScroll.panGestureRecognizer.delaysTouchesBegan = true
        shadowScroll.tag = 40
        
        mainScroll.removeGestureRecognizer(mainScroll.panGestureRecognizer)
        mainScroll.addGestureRecognizer(shadowScroll.panGestureRecognizer)
                
        view.backgroundColor = nil
        loadSearchBar()
        loadScrollView()
        
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        if children.count != 0 { return }

        Mixpanel.mainInstance().track(event: "SearchOpen")
        resetView()
        addIndicators()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        mapVC.hideNearbyButtons()
        mapVC.nearbyViewController = nil
        mapVC.searchBarButton.isHidden = true
        addTopRadius()
    }
    
    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditSpot(_:)), name: NSNotification.Name("EditSpot"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeleteSpot(_:)), name: NSNotification.Name("DeleteSpot"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name(("FriendsListLoad")), object: nil)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] notification in
            addIndicators()
        }
    }
    
    func addIndicators() {
        if !self.loadingIndicator.isHidden {
            DispatchQueue.main.async { self.loadingIndicator.startAnimating() }
        }
    }
    
    
    @objc func notifyEditSpot(_ notification: NSNotification) {
        if let editSpot = notification.userInfo?.first?.value as? MapSpot {
            /// update map spot
            if let anno = mapVC.nearbyAnnotations.first(where: {$0.key == editSpot.id}) {
                anno.value.coordinate = CLLocationCoordinate2D(latitude: editSpot.spotLat, longitude: editSpot.spotLong)
            }
            /// update nearby spot
            if let index = citySpots.firstIndex(where: {$0.spot.id == editSpot.id}) {
                citySpots[index].spot = editSpot
                spotsTable.reloadData()
            }
        }
    }
    
    @objc func notifyDeleteSpot(_ notification: NSNotification) {
        if let spotID = notification.userInfo?.first?.value as? String {
            /// delete map spot
            if let index = mapVC.nearbyAnnotations.firstIndex(where: {$0.key == spotID}) {
                mapVC.nearbyAnnotations.remove(at: index)
            }
            /// delete nearby spot
            if let index = citySpots.firstIndex(where: {$0.spot.id == spotID}) {
                citySpots.remove(at: index)
                spotsTable.reloadData()
            }
        }
    }
    
    @objc func notifyFriendsLoad(_ notification: NSNotification) {
        
        /// notify user friendsList load -> if user friendsList empty, run initial get functions
        if friendsEmpty {
            
            cityFriends.append(CityUser(user: mapVC.userInfo))
            for friend in mapVC.friendsList {
                if mapVC.adminIDs.contains(friend.id ?? "") { continue }
                cityFriends.append(CityUser(user: friend))
            }
            
            getUserCity()
            friendsEmpty = false
        }
    }
    
    func loadScrollView() {
        
        let pullLine = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 21.5, y: 0, width: 43, height: 14.5))
        pullLine.contentEdgeInsets = UIEdgeInsets(top: 7, left: 5, bottom: 0, right: 5)
        pullLine.setImage(UIImage(named: "PullLine"), for: .normal)
        pullLine.addTarget(self, action: #selector(lineTap(_:)), for: .touchUpInside)
        headerView.addSubview(pullLine)

        resultsTable = UITableView(frame: CGRect(x: 0, y: 25, width: UIScreen.main.bounds.width, height: 300))
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.backgroundColor = UIColor(named: "SpotBlack")
        resultsTable.separatorStyle = .none
        resultsTable.isHidden = true
        resultsTable.register(SpotSearchCell.self, forCellReuseIdentifier: "SpotSearchCell")
        resultsTable.tag = 1

        searchIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 30))
        searchIndicator.isHidden = true
        resultsTable.addSubview(searchIndicator)
        
        view.addSubview(resultsTable)
        
        citiesTable = UITableView(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 325))
        citiesTable.dataSource = self
        citiesTable.delegate = self
        citiesTable.backgroundColor = UIColor(named: "SpotBlack")
        citiesTable.separatorStyle = .none
        citiesTable.isScrollEnabled = false
        citiesTable.isHidden = true
        citiesTable.register(SpotSearchCell.self, forCellReuseIdentifier: "SpotSearchCell")
        citiesTable.register(NearbyCityCell.self, forCellReuseIdentifier: "NearbyCityCell")
        citiesTable.tag = 2
        view.addSubview(citiesTable)
                
        cityIcon = UIImageView(frame: CGRect(x: 14, y: 25, width: 15, height: 20.2))
        cityIcon.image = UIImage(named: "CityIcon")
        cityIcon.isHidden = true
        headerView.addSubview(cityIcon)
        
        cityName = UILabel(frame: CGRect(x: cityIcon.frame.maxX + 8, y: cityIcon.frame.minY + 2, width: UIScreen.main.bounds.width - 28, height: 20))
        cityName.font = UIFont(name: "SFCamera-Semibold", size: 17)
        cityName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        headerView.addSubview(self.cityName)
        
        /// button covers cityname to include it in touch area
        changeCityButton = UIButton(frame: CGRect(x: cityName.frame.minX - 4.5, y: cityName.frame.minY - 4, width: cityName.frame.width + 86, height: 30))
        changeCityButton.setTitle("CHANGE CITY", for: .normal)
        changeCityButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        changeCityButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 10.5)
        changeCityButton.contentVerticalAlignment = .center
        changeCityButton.contentHorizontalAlignment = .right
        changeCityButton.addTarget(self, action: #selector(changeCityTap(_:)), for: .touchUpInside)
        headerView.addSubview(changeCityButton)
        
          /// set up filters and spots table
        loadMainScroll()
        
        if mapVC.currentLocation == nil { return }
        
        /// map hasn't fetched friends list yet
        if !mapVC.friendsLoaded {
            friendsEmpty = true
            return
        }
        
        /// initialize city friends objects for use in first collection
        cityFriends.append(CityUser(user: mapVC.userInfo))
        for friend in mapVC.friendsList {
            if mapVC.adminIDs.contains(friend.id ?? "") { continue }
            cityFriends.append(CityUser(user: friend))
        }

        /// fetch city from users current location if available
        getUserCity()
    }
    
    func getUserCity() {
        
        getCity(completion: { [weak self] (city) in
            guard let self = self else { return}
            
            self.cityIcon.isHidden = false
            
            self.cityName.text = city
            self.cityName.sizeToFit()
            
            self.changeCityButton.frame = CGRect(x: self.cityName.frame.minX - 4.5, y: self.cityName.frame.minY - 4, width: self.cityName.frame.width + 86, height: 30)

            let userCoordinate = self.mapVC.currentLocation.coordinate
            self.selectedCity = (name: city, coordinate: userCoordinate)
            self.userCity = (name: city, coordinate: userCoordinate)
            
            var city = City(id: "", cityName: city, cityLat: userCoordinate.latitude, cityLong: userCoordinate.longitude)
            city.activeCity = true
            
            if !self.nearbyCities.contains(where: {$0.cityName == city.cityName}) { self.nearbyCities.append(city) }
            self.enteredCities.append(city.cityName)
            
            self.nearbyCityCounter += 1
            
            DispatchQueue.global(qos: .userInitiated).async { self.getSpots() } /// run nearby spots search on userInitiated background thread
            
            DispatchQueue.global(qos: .default).async {  self.getNearbyCities(radius: self.cityRadius) } /// run nearby city search on default background thread thread because cities are hidden from view before click
        })
    }
    
    func resetToUserCity() {
        
        ///called when clicking current location icon on the map
        if cityFriends.isEmpty { return }
        
        getCity(completion: { [weak self] (cityString) in
            
            guard let self = self else { return }
            if self.selectedCity != nil && cityString == self.selectedCity.name { return }
            
            self.selectedCity = (name: cityString, coordinate: CLLocationCoordinate2D(latitude: self.mapVC.currentLocation.coordinate.latitude, longitude: self.mapVC.currentLocation.coordinate.longitude))
            
            self.resetCity()
        })
    }
    
    func loadMainScroll() {
        
        let usersLayout = LeftAlignedCollectionViewFlowLayout()
        usersLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 29)
        
        usersCollection.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0)
        usersCollection.setCollectionViewLayout(usersLayout, animated: false)
        usersCollection.tag = 0
        usersCollection.delegate = self
        usersCollection.dataSource = self
        usersCollection.isScrollEnabled = false
        usersCollection.backgroundColor = nil
        usersCollection.contentInset = UIEdgeInsets(top: 0, left: 11, bottom: 0, right: 11)
        usersCollection.register(NearbyUserCell.self, forCellWithReuseIdentifier: "NearbyUserCell")
        usersCollection.register(MoreCell.self, forCellWithReuseIdentifier: "MoreCell")
        usersCollection.register(NearbyUsersHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "NearbyUserHeader")
        usersCollection.register(NearbyEmptyCell.self, forCellWithReuseIdentifier: "NearbyEmptyCell")
        usersCollection.removeGestureRecognizer(usersCollection.panGestureRecognizer)
        mainScroll.addSubview(usersCollection)
        
        loadingIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 70, width: UIScreen.main.bounds.width, height: 30))
        loadingIndicator.startAnimating()
        mainScroll.addSubview(loadingIndicator)
        
        let tagsLayout = LeftAlignedCollectionViewFlowLayout()
        tagsLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 29)
        
        /// estimated frame size to smooth animation
        tagsCollection.frame = CGRect(x: 0, y: 150, width: UIScreen.main.bounds.width, height: 0)
        tagsCollection.setCollectionViewLayout(tagsLayout, animated: false)
        tagsCollection.tag = 1
        tagsCollection.delegate = self
        tagsCollection.dataSource = self
        tagsCollection.isScrollEnabled = false
        tagsCollection.backgroundColor = nil
        tagsCollection.register(NearbyTagCell.self, forCellWithReuseIdentifier: "NearbyTagCell")
        tagsCollection.register(MoreCell.self, forCellWithReuseIdentifier: "MoreCell")
        tagsCollection.register(NearbyTagsHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "NearbyTagsHeader")
        tagsCollection.contentInset = UIEdgeInsets(top: 0, left: 11, bottom: 0, right: 11)
        tagsCollection.removeGestureRecognizer(tagsCollection.panGestureRecognizer)
        mainScroll.addSubview(tagsCollection)
        
        spotsHeader.frame = CGRect(x: 0, y: 400, width: UIScreen.main.bounds.width, height: 0)
        spotsHeader.isUserInteractionEnabled = true
        mainScroll.addSubview(spotsHeader)
        
        spotsTable.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        spotsTable.tag = 0
        spotsTable.delegate = self
        spotsTable.dataSource = self
        spotsTable.isScrollEnabled = false
        spotsTable.backgroundColor = nil
        spotsTable.allowsSelection = true
        spotsTable.delaysContentTouches = false
        spotsTable.separatorStyle = .none
        spotsTable.register(NearbySpotCell.self, forCellReuseIdentifier: "NearbySpotCell")
        spotsTable.removeGestureRecognizer(spotsTable.panGestureRecognizer)
        mainScroll.addSubview(spotsTable)
    }
    
    func loadSearchBar() {
        
        // search bar hidden until interacted with
        searchBarContainer = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
        searchBarContainer.backgroundColor = UIColor(named: "SpotBlack")
        searchBarContainer.alpha = 0.0
        view.addSubview(searchBarContainer)
        
        let searchBarY: CGFloat = mapVC.largeScreen ? 66 : 36
        searchBar = UISearchBar(frame: CGRect(x: 14, y: searchBarY, width: UIScreen.main.bounds.width - 85, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.barTintColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.placeholder = ""
        searchBar.searchTextField.font = UIFont(name: "SFCamera-Regular", size: 13)
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.searchTextField.clipsToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8

        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: searchBarY + 2, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.00), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        searchBarContainer.addSubview(cancelButton)
    }
    
        
    func getMoreWidth(extraCount: Int) -> CGFloat {

        let moreLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 16))
        moreLabel.font = UIFont(name: "SFCamera-Regular", size: 11.5)
        moreLabel.text = "+ \(extraCount) more"
        moreLabel.sizeToFit()
        
        return moreLabel.frame.width + 15
    }
    
    @objc func lineTap(_ sender: UIButton) {
        mapVC.animateToFullScreen()
    }
            
    @objc func changeCityTap(_ sender: UITapGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "SearchChangeCityTap")
        citiesTable.isHidden = false
        searchBar.becomeFirstResponder()
    }

    
    func resetCollectionValues() {
        
        /// reset collection values to 0 for empty state
        
        usersCollection.frame = CGRect(x: usersCollection.frame.minX, y: usersCollection.frame.minY, width: usersCollection.frame.width, height: 0)
        halfScreenUserHeight = 0
        fullScreenUserCount = 0
        
        tagsCollection.frame = CGRect(x: tagsCollection.frame.minX, y: tagsCollection.frame.minY, width: tagsCollection.frame.width, height: 0)
        halfScreenTagsHeight = 0
        fullScreenTagsHeight = 0
        
        spotsHeader.frame = CGRect(x: spotsHeader.frame.minX, y: spotsTable.frame.minY, width: spotsTable.frame.width, height: 0)
        spotsTable.frame = CGRect(x: spotsTable.frame.minX, y: spotsTable.frame.minY, width: spotsTable.frame.width, height: 0)
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        /// so scroll doesnt scroll before being full screen
        if let tabBar = parent?.parent as? CustomTabBar {
            if tabBar.view.frame.minY > 0 {
                DispatchQueue.main.async { self.mainScroll.contentOffset.y = 0 }
                return
            }
        }
        
        if !resultsTable.isHidden { return }
        
        setOffsets(scrollView: scrollView)
    }
    
    func setOffsets(scrollView: UIScrollView) {
        /// so no scrolls get stuck
        let yOffset = scrollView.contentOffset.y

        if yOffset < 0 {
            DispatchQueue.main.async { scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: false) }
        }
        
        if scrollView.tag != 40 { return }
        let offset: CGFloat = 32
        let sec0Height = spotsTable.frame.minY - offset
        let grayZone = sec0Height - 40
        
        DispatchQueue.main.async {
            
            if scrollView.contentOffset.y < sec0Height {
                /// scrollView offset hasn't hit the posts collection yet so offset the mainScroll
                self.mainScroll.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y), animated: false)
                /// set spots table offset
                self.spotsTable.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
                
                /// dim the header to look like a navigation bar as it approaches the top
                if scrollView.contentOffset.y > grayZone {
                    let level = sec0Height - scrollView.contentOffset.y
                    self.dimHeader(level: level)
                } else { self.dimHeader(level: 40) }

            } else {
                /// offset posts collection
                self.mainScroll.setContentOffset(CGPoint(x: 0, y: sec0Height), animated: false)
                /// set spots table offset
                self.spotsTable.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - sec0Height), animated: false)
                self.dimHeader(level: 0)
            }
        }
    }
    
    func dimHeader(level: CGFloat) {
        if spotsHeader.topView == nil { return }
        
        let backgroundAlpha: CGFloat = 1 - 2.5 * level/100
        spotsHeader.topView.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(backgroundAlpha)
        
        let lineAlpha = 0.025 * level
        spotsHeader.topLine.alpha = lineAlpha
    }
    
    func removeLoadingIndicator() {
        DispatchQueue.main.async { self.loadingIndicator.stopAnimating() }
    }
    
    func getWidth(name: String, spotCount: Int) -> CGFloat {

        var width: CGFloat = 49
        
        let username = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 16))
        username.text = name
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.sizeToFit()
        width += username.frame.width
        
        let spotsCount = UILabel(frame: CGRect(x: username.frame.maxX + 5, y: 9, width: 20, height: 14))
        spotsCount.text = String(spotCount)
        spotsCount.font = UIFont(name: "SFCamera-Semibold", size: 11.5)
        spotsCount.sizeToFit()
        width += spotsCount.frame.width
        
        return width
    }
}

extension NearbyViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if collectionView.tag == 0 {

            if indexPath.row == 0 && halfScreenUserCount == 0 {
                /// empty state cell. Add room for add  friends button if user has <15 friends
                let lowFriends = !cityFriends.contains(where: {!$0.spotsList.isEmpty}) && mapVC.friendIDs.count < 15
                let emptyHeight: CGFloat = lowFriends ? 110 : 50
                
                return CGSize(width: UIScreen.main.bounds.width, height: emptyHeight)
                
            } else if indexPath.row == halfScreenUserCount - 1 && usersMoreNeeded && !expandUsers {
                /// add +more button if users aren't going to fit on 2 lines for this section, and hasn't already been expanded
                let moreWidth = getMoreWidth(extraCount: fullScreenUserCount - halfScreenUserCount)
                return CGSize(width: moreWidth, height: 34)
            }
            
            guard let user = cityFriends[safe: indexPath.row] else { return CGSize(width: 0, height: 0) }
            let width = getWidth(name: user.user.username, spotCount: user.spotsList.count)
            
            return CGSize(width: width, height: 34)
            
        } else {
            
            if indexPath.row == halfScreenTagsCount - 1 && tagsMoreNeeded && !expandTags {
                /// add +more button if tags aren't going to fit on 3 lines for this section, and hasn't already been expanded
                let moreWidth = getMoreWidth(extraCount: fullScreenUserCount - halfScreenUserCount)
                return CGSize(width: moreWidth, height: 34)
            }

            guard let tag = cityTags[safe: indexPath.row] else { return (CGSize(width: 100, height: 34)) }
            let width = getWidth(name: tag.name, spotCount: tag.spotCount)
            return CGSize(width: width, height: 34)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
        
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        /// return userCount if all users showing or userCount + 1 if adding the +more button
        if collectionView.tag == 0 {
            if halfScreenUserCount == 0 && !cityFriends.contains(where: {!$0.spotsList.isEmpty}) && mapVC.friendIDs.count < 15 { return 1 } /// add empty state
            return expandUsers ? fullScreenUserCount : halfScreenUserCount
        } else {
            return expandTags ? fullScreenTagsCount : halfScreenTagsCount
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if collectionView.tag == 0 {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "NearbyUserHeader", for: indexPath) as? NearbyUsersHeader else { return UICollectionReusableView() }
            return header
            
        } else {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "NearbyTagsHeader", for: indexPath) as? NearbyTagsHeader else { return UICollectionReusableView() }
            return header
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if collectionView.tag == 0 {
            
            if indexPath.row == 0 && halfScreenUserCount == 0 {
                /// emptyView cell
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NearbyEmptyCell", for: indexPath) as? NearbyEmptyCell else { return UICollectionViewCell() }
                cell.setUp(lowFriends: !cityFriends.contains(where: {!$0.spotsList.isEmpty}) && mapVC.friendIDs.count < 15)
                return cell
                
            } else if indexPath.row == halfScreenUserCount - 1 && usersMoreNeeded && !expandUsers {
                /// add more button for halfscreen view with user overflow
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MoreCell", for: indexPath) as? MoreCell else { return UICollectionViewCell() }
                let trueHalf = usersMoreNeeded ? halfScreenUserCount - 1 : halfScreenUserCount
                cell.setUp(count: fullScreenUserCount - trueHalf, spotPage: false)
                return cell
            }
            /// regular user cell
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NearbyUserCell", for: indexPath) as? NearbyUserCell else { return UICollectionViewCell() }
            guard let user = cityFriends[safe: indexPath.row] else { return cell }
            cell.isSelected = user.selected
            cell.setUp(user: user.user, count: user.filteredCount)
            return cell
            
        } else {
            /// add more button for halfscreen view with tags overflow
            if indexPath.row == halfScreenTagsCount - 1 && tagsMoreNeeded && !expandTags {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MoreCell", for: indexPath) as? MoreCell else { return UICollectionViewCell() }
                let trueHalf = tagsMoreNeeded ? halfScreenTagsCount - 1 : halfScreenTagsCount
                cell.setUp(count: fullScreenTagsCount - trueHalf, spotPage: false)
                return cell
            }
            /// tag cell
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NearbyTagCell", for: indexPath) as? NearbyTagCell else { return UICollectionViewCell() }
            guard let tag = cityTags[safe: indexPath.row] else { return cell}
            cell.isSelected = tag.selected
            cell.setUp(tag: tag, count: tag.spotCount)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        passedCamera = MKMapCamera(lookingAtCenter: mapVC.mapView.centerCoordinate, fromDistance: mapVC.mapView.camera.centerCoordinateDistance, pitch: mapVC.mapView.camera.pitch, heading: mapVC.mapView.camera.heading)
        
        switch collectionView.tag {
        
        case 0:
            
            if collectionView.cellForItem(at: indexPath) is NearbyUserCell {

                /// remove currently selected user
                if selectedUserID != nil  {
                    guard let index = cityFriends.firstIndex(where: {$0.user.id == selectedUserID}) else { return }
                    cityFriends[index].selected = false
                }
                
                /// select tapped cell if not already deselected
                let user = cityFriends[indexPath.row]
                if selectedUserID != user.user.id {
                    selectedUserID = user.user.id!
                    cityFriends[indexPath.row].selected = true
                    
                    Mixpanel.mainInstance().track(event: "SearchFilterByFriend")
                    /// animate inserting cell at 0
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.25) {
                            guard let cell = collectionView.cellForItem(at: indexPath) as? NearbyUserCell else { return }
                            cell.layer.borderColor = UIColor(named: "SpotGreen")!.cgColor
                            collectionView.moveItem(at: indexPath, to:  IndexPath(item: 0, section: 0))
                        }
                    }
                    
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) { self.filter() }

                    /// deselect user
                } else { selectedUserID = nil; DispatchQueue.global().async { self.filter() } }
                                
            } else {
                /// animate to full on more tap to show all user cells
                expandUsers = true
                animateToFull()
            }
            
        case 1:
            if collectionView.cellForItem(at: indexPath) is NearbyTagCell {

                let tag = cityTags[indexPath.row]
                
                ///remove / add tags
                let initiallySelected = tag.selected
                tag.selected ? selectedTags.removeAll(where: {$0 == tag.name}) : selectedTags.append(tag.name)
                cityTags[indexPath.row].selected = !tag.selected
                
                /// animate inserting newly selected tag
                if !initiallySelected {
                    
                    Mixpanel.mainInstance().track(event: "SearchFilterByTag")

                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.25) {
                            guard let cell = collectionView.cellForItem(at: indexPath) as? NearbyTagCell else { return }
                            cell.layer.borderColor = UIColor(named: "SpotGreen")!.cgColor
                            collectionView.moveItem(at: indexPath, to:  IndexPath(item: self.selectedTags.count - 1, section: 0))
                        }
                    }
                    
                    /// run filter on delay to show some of the first cell animation first
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) { self.filter() }
                    
                    /// deselect tag with no delay for animation
                } else { DispatchQueue.global().async { self.filter() } }
            } else {
                /// animate to full and show all tag cells
                expandTags = true
                animateToFull()
            }
        default:
            return
        }
    }
    
    func deselectUserFromMap() {
        /// x clicked on map filter view
        guard let index = cityFriends.firstIndex(where: {$0.user.id == selectedUserID}) else { return }
        cityFriends[index].selected = false
        selectedUserID = nil
        DispatchQueue.global().async { self.filter() }
    }
    
    func deselectTagFromMap(tag: String) {
        /// x clicked on map filter view
        guard let index = cityTags.firstIndex(where: {$0.name == tag}) else { return }
        cityTags[index].selected = false
        selectedTags.removeAll(where: {$0 == tag})
        DispatchQueue.global().async { self.filter() }
    }
    
    
    func openProfile(user: UserProfile) {
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
            
            vc.userInfo = user
            vc.mapVC = self.mapVC
            vc.id = user.id!
                        
            mapVC.nearbyViewController = nil
            mapVC.searchBarButton.isHidden = true
            addTopRadius()
            
            mapVC.customTabBar.tabBar.isHidden = true
            
            shadowScroll.isScrollEnabled = false
            
            vc.view.frame = self.view.frame
            self.addChild(vc)
            self.view.addSubview(vc.view)
            vc.didMove(toParent: self)
        }
    }
}

extension NearbyViewController: UISearchBarDelegate {
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        /// don't want to animate to half on search select
         if children.count == 0 { animateToHalf() }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        startEditing()
    }
    
    func startEditing() {
        
        /// open search, hide main view, show search table
        Mixpanel.mainInstance().track(event: "SearchBegan")
        animateToFull()
        
        searchBar.placeholder = citiesTable.isHidden ? " Search for spots and friends" : " Search cities"
        let selectedTable = citiesTable.isHidden ? resultsTable! : citiesTable!
        if citiesTable.isHidden && !selectedTable.isHidden { return } /// don't want to show animation when search bar editing already began
        
        selectedTable.alpha = 0.0
        selectedTable.isHidden = false
        searchBarContainer.alpha = 0.0
        searchBarContainer.isHidden = false
        
        UIView.animate(withDuration: 0.2) {
            self.headerView.alpha = 0.0
            self.usersCollection.alpha = 0.0
            self.tagsCollection.alpha = 0.0
            self.spotsHeader.alpha = 0.0
            self.spotsTable.alpha = 0.0
            self.searchBarContainer.alpha = 1.0
            selectedTable.alpha = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.headerView.isHidden = true
            self.headerView.alpha = 1.0
            self.usersCollection.isHidden = true
            self.usersCollection.alpha = 1.0
            self.tagsCollection.isHidden = true
            self.tagsCollection.alpha = 1.0
            self.spotsHeader.isHidden = true
            self.spotsHeader.alpha = 1.0
            self.spotsTable.isHidden = true
            self.spotsTable.alpha = 1.0
            self.searchIndicator.isHidden = true
        }
    }
    
    @objc func searchCancelTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "SearchCancel")
        animateToHalf()
    }
    
    func animateToFull() {

        UIView.animate(withDuration: 0.2) {
            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: UIScreen.main.bounds.height)
            self.resultsTable.frame = CGRect(x: 0, y: self.searchBarContainer.frame.maxY + 10, width: UIScreen.main.bounds.width, height: 300)
            self.citiesTable.frame = CGRect(x: 0, y: self.searchBarContainer.frame.maxY + 15, width: UIScreen.main.bounds.width, height: 325)
            self.offsetCityName(position: 2)
        }
        
        if !mapVC.largeScreen { removeTopRadius() }
        
        mapVC.prePanY = 0
        
        DispatchQueue.main.async { self.resizeUsers(refresh: true) }
        DispatchQueue.main.async { self.resizeTags(refresh: true) }
        
        self.shadowScroll.isScrollEnabled = true
    }
    
    func closeSearch() {
        
        /// animate users/tags/spots collections back in if hidden
        if usersCollection.isHidden {
            headerView.alpha = 0.0
            headerView.isHidden = false
            usersCollection.alpha = 0.0
            usersCollection.isHidden = false
            tagsCollection.alpha = 0.0
            tagsCollection.isHidden = false
            spotsHeader.alpha = 0.0
            spotsHeader.isHidden = false
            spotsTable.alpha = 0.0
            spotsTable.isHidden = false
        }

        UIView.animate(withDuration: 0.2) {
            self.headerView.alpha = 1.0
            self.usersCollection.alpha = 1.0
            self.tagsCollection.alpha = 1.0
            self.spotsHeader.alpha = 1.0
            self.spotsTable.alpha = 1.0
            self.spotsTable.alpha = 1.0
            self.searchBarContainer.alpha = 0.0
            
            self.offsetCityName(position: 1)
            self.mainScroll.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.searchBarContainer.isHidden = true
        }
        
        if !mapVC.largeScreen { addTopRadius() }
        
        shadowScroll.isScrollEnabled = false
        //hide results view
        searchBar.text = ""
        searchBar.placeholder = ""
        emptyQueries()
        
        resultsTable.reloadData()
        resultsTable.isHidden = true
        resultsTable.alpha = 1.0
        
        citiesTable.reloadData()
        citiesTable.isHidden = true
        citiesTable.alpha = 1.0
        showQuery = false
        
        searchBar.endEditing(true)
        searchBar.resignFirstResponder()
        
        expandUsers = false
        expandTags = false
        
        resizeUsers(refresh: true)
        resizeTags(refresh: true)
    }
    
    func animateToHalf() {
        
        UIView.animate(withDuration: 0.2) {
            self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: self.mapVC.halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - self.mapVC.halfScreenY)
        }
        
        mapVC.prePanY = mapVC.halfScreenY
        if searchBarContainer != nil { closeSearch() }
    }
    
    // top radius used bc can't set corner radius for entire drawer or else bottom corners will show on iPhone8-
    func removeTopRadius() {
        mapVC.customTabBar.view.layer.mask = nil
    }
    
    func addTopRadius() {
        mapVC.customTabBar.view.layer.mask = mapVC.tabBarLayer
    }
    
    func resetMap() {
        
        let annotations = mapVC.mapView.annotations
        mapVC.mapView.removeAnnotations(annotations)
        mapVC.postsList.removeAll()
        
        mapVC.searchBarButton.isHidden = false
        
        mapVC.nearbyViewController = self
        mapVC.profileViewController = nil
        mapVC.spotViewController = nil
        
        userSpots = mapVC.userSpots
        
        let minY: CGFloat = shadowScroll.contentOffset.y == 0 ? mapVC.halfScreenY : 0
        mapVC.prePanY = minY
        
        if minY == mapVC.halfScreenY && selectedCity != nil {
            /// animate to half func will reset offsets on return to screen
            animateToHalf()
        } else {
            /// run non-function animation to restore user scroll on reset offsets -> set offset back to 0 to allow for drawer to close if scroll isn't enabled
            if shadowScroll.contentOffset.y == 1 { shadowScroll.setContentOffset(CGPoint(x: shadowScroll.contentOffset.x, y: 0), animated: false)}
            UIView.animate(withDuration: 0.2) {
                self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - minY) }
            shadowScroll.isScrollEnabled = true
        }
        
        if passedCamera != nil {
            self.mapVC.mapView.setCamera(passedCamera, animated: false)
            passedCamera = nil
        } else { mapVC.animateToUserLocation(animated: false) }
        
        if mapVC.currentLocation != nil {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: {
                self.mapVC.loadNearbySpots()
            })
        }
    }
    
    func resetView() {
        /// reappear from spot page / edit address / image picker
        postVC = nil
        mapVC.setUpNavBar()
        mapVC.customTabBar.tabBar.isHidden = false
        mapVC.nearbyViewController = self
        mapVC.removeBottomBar()
        resetMap()
        setOffsets(scrollView: shadowScroll) /// reset offset to where it was before
    }
    
    func resetOffsets() {
        
        ///scroll to top on nearby tab bar button click
        
        DispatchQueue.main.async {
            
            /// don't need to run before load
            if self.mainScroll.frame.height == 0 { return }
            
            UIView.animate(withDuration: 0.2) {
                self.spotsTable.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                
                UIView.animate(withDuration: 0.1, delay: 0.0, options: [], animations: {
                   self.mainScroll.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
                    
                }, completion: { [weak self] (completed) in
                    guard let self = self else { return }
                    self.shadowScroll.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
                })
            }
        }
    }
    
    func offsetCityName(position: Int) {
        
        /// position: 0 = closed, 1 = half, 2 = full

        let minY: CGFloat = position != 2 ? 25 : self.mapVC.largeScreen ? 60 : 35
        let cityOffset: CGFloat = position == 0 ? 5 : 0
        let scrollOffset: CGFloat = position == 0 ? 35 : position == 2 ? 17 : 14

        if cityName == nil { return }

        cityIcon.frame = CGRect(x: 14, y: minY + cityOffset, width: 15, height: 20.2)
        cityName.frame = CGRect(x: cityIcon.frame.maxX + 8, y: cityIcon.frame.minY + 2, width: UIScreen.main.bounds.width - 28, height: 20)
        cityName.sizeToFit()
        changeCityButton.frame = CGRect(x: cityName.frame.minX - 4.5, y: cityName.frame.minY - 4, width: cityName.frame.width + 86, height: 30)

        /// offset mainScroll to the bottom of cityName
        mainScroll.frame = CGRect(x: mainScroll.frame.minX, y: minY + 22 + scrollOffset, width: mainScroll.frame.width, height: mainScroll.frame.height)
    }
        
    func emptyQueries() {
        /// reset search values
        searchRefreshCount = 0
        self.queryIDs.removeAll()
        self.querySpots.removeAll()
        self.queryUsers.removeAll()
        self.queryCities.removeAll()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // run query for spots, users
        
        self.searchTextGlobal = searchText
        emptyQueries()
        
        /// run main search
        if self.citiesTable.isHidden {
            
            self.resultsTable.reloadData()
            if searchBar.text?.count == 0 { return }
            if !self.searchIndicator.isAnimating() { self.searchIndicator.startAnimating() }
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.runQuery), object: nil)
            self.perform(#selector(self.runQuery), with: nil, afterDelay: 0.65)
            
            /// run city search
        } else {
            /// show nearby cities if text empty
            showQuery = searchBar.text?.count != 0
            citiesTable.reloadData()
            if searchBar.text?.count == 0 { return }
            
            showQuery = true
            citiesTable.reloadData()
            
            locationCompleter.queryFragment = searchTextGlobal
            locationCompleter.resultTypes = .address
        }
    }
    
    @objc func runQuery() {
        // sorting based on spot score + if user is friends with userresult
        emptyQueries()
        resultsTable.reloadData()
                
        DispatchQueue.global(qos: .userInitiated).async {
            self.runSpotsQuery(searchText: self.searchTextGlobal)
            self.runNameQuery(searchText: self.searchTextGlobal)
            self.runUsernameQuery(searchText: self.searchTextGlobal)
        }
    }
    
    func reloadResultsTable() {
        
        let searchTextLocal = searchTextGlobal /// check for last minute text change
        
        searchRefreshCount += 1
        if searchRefreshCount < 3 { return }
        
        if resultsTable.isHidden { return }
        if queryIDs.count == 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.searchIndicator.stopAnimating()
                return
            }
        }
        
        // run sort
        queryIDs.sort(by: {$0.score > $1.score})
        
        /// check if post fetches needed for querySpots
        let topIDs = queryIDs.prefix(5)
        var counter = 0
        
        for id in topIDs {
            
            if let i = self.querySpots.firstIndex(where: {$0.id == id.id}) {
                /// fetch friend image / description for spot on search
                let spot = self.querySpots[i]
                
                if spot.friendImage { counter += 1; if counter == topIDs.count { finishResultsLoad(); return } }
                
                if spot.postFetchID != "" {
                    var newSpot = spot
                    self.db.collection("posts").document(spot.postFetchID).getDocument { [weak self] (doc, err) in

                        guard let self = self else { return }
                        
                        do {
                            
                            if searchTextLocal != self.searchTextGlobal { return }
                            let postInfo = try doc?.data(as: MapPost.self)
                            guard let info = postInfo else { counter += 1; if counter == topIDs.count { self.finishResultsLoad() }; return }
                            
                            newSpot.spotDescription = info.caption
                            newSpot.imageURL = info.imageURLs.first ?? ""
                            self.querySpots[i] = newSpot
                            counter += 1; if counter == topIDs.count { self.finishResultsLoad(); return }
                            
                        } catch { counter += 1; if counter == topIDs.count { self.finishResultsLoad(); return } }
                    }
                }
                
            } else {
                counter += 1; if counter == topIDs.count { finishResultsLoad() }
            }
        }
    }
    
    func finishResultsLoad() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.stopAnimating()
            self.resultsTable.reloadData()
        }
    }
    
    func queryValid(searchText: String) -> Bool {
        return searchText == searchTextGlobal && searchText != ""
    }

    func runSpotsQuery(searchText: String) {
        
        let spotsRef = db.collection("spots")
        let spotsQuery = spotsRef.whereField("searchKeywords", arrayContains: searchText.lowercased()).limit(to: 10)
        
        spotsQuery.getDocuments{ [weak self] (snap, err) in
            
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { return }
            
            if docs.count == 0 { self.reloadResultsTable() }
            var distanceSpots: [MapSpot] = []

            for doc in docs {
                
                do {
                    
                    let spotInfo = try doc.data(as: MapSpot.self)
                    guard var info = spotInfo else { if doc == docs.last {
                        self.getSpotScores(distanceSpots: distanceSpots, searchText: searchText) }; return }
                    info.id = doc.documentID
                    
                    if self.hasSpotAccess(spot: info, mapVC: self.mapVC) {
                                                    
                        let location = CLLocation(latitude: info.spotLat, longitude: info.spotLong)
                        let distanceFromCity = location.distance(from: CLLocation(latitude: self.selectedCity.coordinate.latitude, longitude: self.selectedCity.coordinate.longitude))
                        info.distance = distanceFromCity
                        distanceSpots.append(info)
                    }
                    
                    if doc == docs.last {
                        distanceSpots.sort(by: {$0.distance < $1.distance})
                        self.getSpotScores(distanceSpots: distanceSpots, searchText: searchText)
                    }
                    
                } catch { if doc == docs.last {
                    self.getSpotScores(distanceSpots: distanceSpots, searchText: searchText) }; return }
            }
        }
    }
    
    func getSpotScores(distanceSpots: [MapSpot], searchText: String) {
        
        if !self.queryValid(searchText: searchText) { return }
        let topSpots = distanceSpots.count > 10 ? Array(distanceSpots.prefix(10)) : distanceSpots
        
        for spot in topSpots {
            
            var newSpot = spot
            
            var scoreMultiplier: Double = 1000
            
            let friendVisitors = self.getFriendVisitors(visitorList: spot.visitorList)
            if friendVisitors > 0 { scoreMultiplier += Double((2000 + friendVisitors * 100)) }
            
            let friendImageFromFounder = spot.privacyLevel != "public" || isFriends(id: spot.founderID)
            var friendImage = friendImageFromFounder
            var postFetchID = ""
            var accessToOnePost = false
            
            /// exception handling for failed spot transaction on upload 
            if spot.postIDs.count != 0 && spot.postPrivacies.count == spot.postIDs.count {
                
                for i in 0 ... spot.postIDs.count - 1 {
                                        
                    let isFriend = self.isFriends(id: spot.posterIDs[safe: i] ?? "xxxxx") /// is this a friend or a public stranger post
                    let postPrivacy = spot.postPrivacies[safe: i] ?? "friends"
                    
                    if postPrivacy == "public" || isFriend {
                        accessToOnePost = true
                        
                        scoreMultiplier += 100
                        
                        if postFetchID == "" {
                            /// set postFetchID for first visible post
                            postFetchID = spot.postIDs[i]
                            friendImage = isFriend
                            
                        } else if !friendImage && isFriend {
                            /// always show first friend image if possible
                            postFetchID = spot.postIDs[i]
                            friendImage = true
                        }
                    }
                }
                
            }
            
            newSpot.friendImage = friendImageFromFounder /// do we need to run post fetch?
            newSpot.postFetchID = postFetchID
            
            if accessToOnePost { /// access to one post should always be true here because hasSpotAccess checks for user access already
                
                querySpots.append(newSpot)
                queryIDs.append((id: spot.id!, score: scoreMultiplier/spot.distance))
            }
        }
        
        reloadResultsTable()
    }
    
    func runNameQuery(searchText: String) {
        /// query names for matches
        let userRef = db.collection("users")
        let nameQuery = userRef.whereField("nameKeywords", arrayContains: searchText.lowercased()).limit(to: 5)
        
        nameQuery.getDocuments{ [weak self] (snap, err) in
            
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { return }
            
            if docs.count == 0 { self.reloadResultsTable() }
            
            for doc in docs {
                do {
                    
                    let userInfo = try doc.data(as: UserProfile.self)
                    guard var info = userInfo else { if doc == docs.last { self.reloadResultsTable() }; return }
                    info.id = doc.documentID
                    
                    if !self.queryIDs.contains(where: {$0.id == info.id}) {
                        
                        if !self.queryValid(searchText: searchText) { return }
                        
                        let score: Double = self.isFriends(id: doc.documentID) ? 1 : 0.1
                        self.queryUsers.append(info)
                        self.queryIDs.append((id: info.id!, score: score))

                    }
                    
                    if doc == docs.last { self.reloadResultsTable() }
                    
                } catch { if doc == docs.last { self.reloadResultsTable() } }
            }
        }
    }
    
    func runUsernameQuery(searchText: String) {
        ///query usernames for matches
        let userRef = db.collection("users")
        let usernameQuery = userRef.whereField("usernameKeywords", arrayContains: searchText.lowercased()).limit(to: 5)

        usernameQuery.getDocuments { [weak self] (snap, err) in
            
            guard let self = self else { return }
            guard let docs = snap?.documents else { self.reloadResultsTable(); return }
            if !self.queryValid(searchText: searchText) { return }
            
            if docs.count == 0 { self.reloadResultsTable() }

            for doc in docs {
                do {
                    
                    let userInfo = try doc.data(as: UserProfile.self)
                    guard var info = userInfo else { if doc == docs.last { self.reloadResultsTable() }; return }
                    info.id = doc.documentID
                    
                    if !self.queryIDs.contains(where: {$0.id == info.id}) {
                        
                        if !self.queryValid(searchText: searchText) { return }
                        
                        let score: Double = self.isFriends(id: doc.documentID) ? 1 : 0.1
                        self.queryUsers.append(info)
                        self.queryIDs.append((id: info.id!, score: score))

                    }
                    
                    if doc == docs.last { self.reloadResultsTable() }
                    
                } catch { if doc == docs.last { self.reloadResultsTable() } }
            }
        }
    }
}


extension NearbyViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 0:
            let unfiltered = citySpots.prefix(while: {!$0.filtered})
            return unfiltered.count
        case 1:
            return queryIDs.count > 5 ? 5 : queryIDs.count
        default:
            return showQuery ? queryCities.count > 5 ? 5 : queryCities.count : nearbyCities.count > 5 ? 5 : nearbyCities.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch tableView.tag {
        
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "NearbySpotCell") as? NearbySpotCell else { return UITableViewCell() }
            cell.setUp(spot: citySpots[indexPath.row].spot)
            return cell
            
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotSearchCell") as? SpotSearchCell else { return UITableViewCell() }
            if self.queryIDs.count > indexPath.row {
                let id = self.queryIDs[indexPath.row]
                
                if let spot = self.querySpots.first(where: {$0.id == id.id}) {
                    cell.setUp(spot: spot)
                    
                } else if let user = self.queryUsers.first(where: {$0.id == id.id}) {
                    cell.setUpUser(user: user)
                }
            }
            return cell
            
        default:
            /// set up city cell
            if showQuery {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotSearchCell") as? SpotSearchCell else { return UITableViewCell() }
                print("city", queryCities[indexPath.row])
                let city = queryCities[indexPath.row].cityFormatter()
                cell.setUpCity(cityName: city)
                return cell
                
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "NearbyCityCell") as? NearbyCityCell else { return UITableViewCell() }
                print("city", nearbyCities[indexPath.row])
                let city = nearbyCities[indexPath.row]
                cell.setUp(city: city)
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        switch tableView.tag {
        case 0:
            return 98
        case 1:
            return 60
        default:
            return 65
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        
        switch tableView.tag {
        
        case 0:
            /// offset shadow scroll offset by 1 so that drawer animates back to full screen after returning from spot page - if offset == 0 it'll animate to half
            if shadowScroll.contentOffset.y == 0 { shadowScroll.setContentOffset(CGPoint(x: 0, y: 1), animated: false)}
            guard let spot = self.citySpots[safe: indexPath.row] else { return }
            mapVC.selectFromSearch(spot: spot.spot)
            
            searchBar.resignFirstResponder()
            
        case 1:
            if shadowScroll.contentOffset.y == 0 { shadowScroll.setContentOffset(CGPoint(x: 0, y: 1), animated: false)}
            
            guard let selectedID = queryIDs[safe: indexPath.row] else { return }
            
            if let spot = querySpots.first(where: {$0.id == selectedID.id}) {
                mapVC.selectFromSearch(spot: spot)
                
            } else if let user = queryUsers.first(where: {$0.id == selectedID.id}) {
                Mixpanel.mainInstance().track(event: "SearchProfileSelect")
                openProfile(user: user)
            }
            
            searchBar.resignFirstResponder()
            
        default:
            
            if showQuery {
                /// select from search
                
                guard let completion = queryCities[safe: indexPath.row] else { return }
                let queryString = completion.cityFormatter()
                let searchRequest = MKLocalSearch.Request(completion: completion)
                let search = MKLocalSearch(request: searchRequest)
                
                search.start { [weak self] (response, error) in
                    
                    guard let self = self else { return }
                    guard let placemark = response?.mapItems[0].placemark else { return }
                    
                    let coordinate = placemark.coordinate
                    let adjustedCoordinate = CLLocationCoordinate2D(latitude: coordinate.latitude - 0.02333, longitude: coordinate.longitude)
                    
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""
                    let country = placemark.country ?? ""
                    let secondString = country == "United States" ? state : country
                    
                    /// use same logic as upload to ensure city matches with cityname for spots. In case placemark fails just use original query string
                    let cityString = (city != "" && secondString != "") ? city + ", " + secondString : queryString
                    
                    self.mapVC.mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 7000, longitudinalMeters: 7000), animated: true)
                    self.selectedCity = (name: cityString, coordinate: adjustedCoordinate)
                    
                    self.resetCity(); self.emptyQueries(); self.animateToHalf()
                }

            } else {
                /// select from nearby
                guard let city = nearbyCities[safe: indexPath.row] else { return }
                
                let coordinate = CLLocationCoordinate2D(latitude: city.cityLat, longitude: city.cityLong)
                let adjustedCoordinate = CLLocationCoordinate2D(latitude: coordinate.latitude - 0.02333, longitude: coordinate.longitude)
                
                self.mapVC.mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 7000, longitudinalMeters: 7000), animated: true)
                self.selectedCity = (name: city.cityName, coordinate: adjustedCoordinate)
                self.resetCity(); self.emptyQueries(); self.animateToHalf()
            }
        }
    }
    
    func checkForCityChange() {
        
        if selectedCity == nil { return }
        let coordinate = mapVC.mapView.centerCoordinate
        
        reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { [weak self] cityString in
            
            guard let self = self else { return }
            
            if cityString != self.selectedCity.name {
                /// this isn't the perfect coordinate representing the city center, but it only impacts spotscores so this is acceptable
                self.db.collection("cities").whereField("cityName", isEqualTo: cityString).getDocuments { snap, err in
                    
                    if let doc = snap?.documents.first {

                        guard let l = doc.get("l") as? [Double] else { print("no l"); return }
                        let cityCenter = CLLocationCoordinate2D(latitude: l[0], longitude: l[1])
                        
                        /// check that city hasn't changed again during fetch
                        self.selectedCity = (name: cityString, coordinate: cityCenter)
                        self.resetCity()
                    }

                    self.mapVC.shouldUpdateCity = true
                }
                
            } 
        }
    }
    
    
    func resetCity() {
        
        // sort by score if viewing another city
        sortByScore = userCity != nil && userCity.name != selectedCity.name
        
        cityIcon.frame = CGRect(x: 14, y: 25, width: 15, height: 20.2)
        cityName.frame = CGRect(x: cityIcon.frame.maxX + 8, y: cityIcon.frame.minY + 2, width: UIScreen.main.bounds.width - 28, height: 20)
        cityName.text = selectedCity.name
        cityName.sizeToFit()
        
        self.changeCityButton.frame = CGRect(x: self.cityName.frame.minX - 4.5, y: self.cityName.frame.minY - 4, width: cityName.frame.width + 86, height: changeCityButton.frame.height)
        
        if !nearbyCities.isEmpty {
            for i in 0...nearbyCities.count - 1 { nearbyCities[i].activeCity = false }
        }
        
        // if chosen from existing cities, set to active, otherwise add new city
        if let i = nearbyCities.firstIndex(where: {$0.cityName == selectedCity.name}) {
            nearbyCities[i].activeCity = true
            
        } else {
            var city = City(id: "", cityName: selectedCity.name, cityLat: selectedCity.coordinate.latitude, cityLong: selectedCity.coordinate.longitude)
            city.activeCity = true
            
            self.enteredCities.append(city.cityName)
            self.nearbyCities.append(city)
            self.nearbyCityCounter += 1
        }
        
        /// resort/reload cities table
        reloadCities()
       
        /// remove city spots from each friend object
        if cityFriends.count > 0 {
            for i in 0...cityFriends.count - 1 {
                cityFriends[i].spotsList.removeAll()
                cityFriends[i].filteredCount = 0
    //            cityFriends[i].selected = false
            }
        }
        
        /// remove city spots from each tag object except for selected tag
        if cityTags.count > 0 { for i in 0...cityTags.count - 1 { cityTags[i].spotCount = 0 } }
        cityTags.removeAll(where: {!$0.selected})
        
        /// remove filters
//        selectedUserID = nil
//        selectedTags.removeAll()
        
        /// reset map filters
//        mapVC.filterUser = nil
//        mapVC.filterTags.removeAll()
//        mapVC.addSelectedFilters()
        mapVC.filterSpots(refresh: false)
        
        citySpots.removeAll()
        
        usersCollection.reloadData()
        loadingIndicator.startAnimating()

        DispatchQueue.global(qos: .userInitiated).async { self.getSpots() }
    }
    
    @objc func headerTap(_ sender: UIButton) {
        
        /// bring up sort mask to allow user to change the sort for the spots table
        
        sortMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        sortMask.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        sortMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeSortMask(_:))))
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(sortMask)
        
        let pickerView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 269, width: UIScreen.main.bounds.width, height: 269))
        pickerView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.0)
        sortMask.addSubview(pickerView)
        
        let titleLabel = UILabel(frame: CGRect(x: 17, y: 14, width: 100, height: 20))
        titleLabel.text = "Sort spots by"
        titleLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        titleLabel.textAlignment = .left
        pickerView.addSubview(titleLabel)

        let line = UIView(frame: CGRect(x: 0, y: titleLabel.frame.maxY + 14, width: UIScreen.main.bounds.width, height: 1))
        line.backgroundColor = UIColor(red: 0.171, green: 0.171, blue: 0.171, alpha: 1)
        pickerView.addSubview(line)
        
        let grayTint = UIColor(red: 0.467, green: 0.465, blue: 0.465, alpha: 1)
        let whiteTint = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        
        let locationIcon = UIImageView(frame: CGRect(x: 20, y: line.frame.maxY + 20, width: 14, height: 20))
        locationIcon.image = UIImage(named: "LocationIcon")
        pickerView.addSubview(locationIcon)
        
        let locationLabel = UILabel(frame: CGRect(x: locationIcon.frame.maxX + 15.5, y: locationIcon.frame.minY + 1, width: 60, height: 20))
        locationLabel.text = "Nearest"
        locationLabel.textColor = sortByScore ? grayTint : whiteTint
        locationLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        pickerView.addSubview(locationLabel)
        
        let topIcon = UIImageView(frame: CGRect(x: 17, y: locationLabel.frame.maxY + 25, width: 19, height: 18.5))
        topIcon.image = UIImage(named: "TopIcon")
        pickerView.addSubview(topIcon)
        
        let topLabel = UILabel(frame: CGRect(x: topIcon.frame.maxX + 15, y: topIcon.frame.minY + 1, width: 40, height: 20))
        topLabel.text = "Top"
        topLabel.textColor = sortByScore ? whiteTint : grayTint
        topLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        pickerView.addSubview(topLabel)

        if sortByScore { locationIcon.image = UIImage(named: "LocationIcon")?.withTintColor(grayTint) } else { topIcon.image = UIImage(named: "TopIcon")?.withTintColor(grayTint) }
        
        let locationButton = UIButton(frame: CGRect(x: 0, y: line.frame.maxY + 5, width: 200, height: 50))
        locationButton.addTarget(self, action: #selector(sortTap(_:)), for: .touchUpInside)
        locationButton.tag = 0
        pickerView.addSubview(locationButton)
        
        let topButton = UIButton(frame: CGRect(x: 0, y: locationButton.frame.maxY, width: 200, height: 50))
        topButton.addTarget(self, action: #selector(sortTap(_:)), for: .touchUpInside)
        topButton.tag = 1
        pickerView.addSubview(topButton)
    }
    
    @objc func closeSortMask(_ sender: UITapGestureRecognizer) {
        closeSortMask()
    }
    
    @objc func sortTap(_ sender: UIButton) {
        
        Mixpanel.mainInstance().track(event: "SearchSortSpotsTable", properties: ["sortIndex": sender.tag])

        switch sender.tag {
        
        /// sort by distance
        case 0:
            sortByScore = false
            citySpots.sort(by: {!$0.filtered && !$1.filtered ? $0.spot.distance < $1.spot.distance : !$0.filtered && $1.filtered})
            
        /// sort by spot score  (TOP)
        case 1:
            sortByScore = true
            citySpots.sort(by: {!$0.filtered && !$1.filtered ? $0.spot.spotScore > $1.spot.spotScore : !$0.filtered && $1.filtered})
            
        default: return
        }
        
        /// scroll spotsTable to top after filter tap
        DispatchQueue.main.async {
            
            let offset: CGFloat = self.mapVC.largeScreen ? 65 : 40
            let sec0Height = self.spotsTable.frame.minY - offset
            
            if self.shadowScroll.contentOffset.y > sec0Height {
                self.mainScroll.setContentOffset(CGPoint(x: 0, y: sec0Height), animated: false)
                self.spotsTable.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
                self.shadowScroll.setContentOffset(CGPoint(x: 0, y: sec0Height), animated: false)
            }
            
            self.reloadSpotsTable()
            self.closeSortMask()
        }
    }
    
    func closeSortMask() {
        for subview in sortMask.subviews { subview.removeFromSuperview() }
        sortMask.removeFromSuperview()
    }
}


class NearbyUserCell: UICollectionViewCell {
    
    var profilePic: UIImageView!
    var username: UILabel!
    var spotsCount: UILabel!
    
    func setUp(user: UserProfile, count: Int) {
        
        backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        layer.cornerRadius = 7.5
        layer.borderWidth = 1
        layer.borderColor = isSelected ? UIColor(named: "SpotGreen")?.cgColor : UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.00).cgColor
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale

        resetCell()
        
        profilePic = UIImageView(frame: CGRect(x: 7, y: 6, width: 22, height: 22))
        profilePic.layer.cornerRadius = 11
        profilePic.layer.masksToBounds = true
        profilePic.contentMode = .scaleAspectFill
        self.addSubview(profilePic)
        
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 5, y: 9, width: self.bounds.width, height: 16))
        username.text = user.username
        username.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        username.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        username.sizeToFit()
        self.addSubview(username)
        
        spotsCount = UILabel(frame: CGRect(x: username.frame.maxX + 5, y: 10, width: 20, height: 14))
        spotsCount.text = String(count)
        spotsCount.font = UIFont(name: "SFCamera-Semibold", size: 11.5)
        spotsCount.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1)
        spotsCount.sizeToFit()
        self.addSubview(spotsCount)
    }
    
    func resetCell() {
        if profilePic != nil {profilePic.image = UIImage()}
        if username != nil {username.text = ""}
        if spotsCount != nil {spotsCount.text = ""}
    }
    
    override func prepareForReuse() {
        /// cancel image fetch when cell leaves screen
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
        isSelected = false
    }
}

class NearbyUsersHeader: UICollectionReusableView {
    
    var label: UILabel!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 3, y: 3, width: 100, height: 16))
        label.text = "Filter by friend"
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 13)
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class NearbyTagCell: UICollectionViewCell {
    
    var tagPic: UIImageView!
    var tagName: UILabel!
    var spotsCount: UILabel!
    
    func setUp(tag: Tag, count: Int) {
        
        backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        layer.cornerRadius = 7.5
        layer.borderWidth = 1
        layer.borderColor = isSelected ? UIColor(named: "SpotGreen")?.cgColor : UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.00).cgColor
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale

        resetCell()
        
        tagPic = UIImageView(frame: CGRect(x: 7, y: 6, width: 22, height: 22))
        tagPic.layer.masksToBounds = true
        tagPic.contentMode = .scaleAspectFit
        tagPic.image = tag.image
        
        /// fetch tag image from database
        if tagPic.image == UIImage() && tag.imageURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            tagPic.sd_setImage(with: URL(string: tag.imageURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        addSubview(tagPic)

        tagName = UILabel(frame: CGRect(x: tagPic.frame.maxX + 5, y: 9, width: self.bounds.width, height: 16))
        tagName.text = tag.name
        tagName.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        tagName.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        tagName.sizeToFit()
        self.addSubview(tagName)
        
        spotsCount = UILabel(frame: CGRect(x: tagName.frame.maxX + 5, y: 10, width: 20, height: 14))
        spotsCount.text = String(count)
        spotsCount.font = UIFont(name: "SFCamera-Semibold", size: 11.5)
        spotsCount.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1)
        spotsCount.sizeToFit()
        self.addSubview(spotsCount)
    }
    
    func resetCell() {
        if tagPic != nil {tagPic.image = UIImage()}
        if tagName != nil {tagName.text = ""}
        if spotsCount != nil {spotsCount.text = ""}
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isSelected = false
        if tagPic != nil { tagPic.sd_cancelCurrentImageLoad() }
    }
}

class NearbyTagsHeader: UICollectionReusableView {
    
    var label: UILabel!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 3, y: 3, width: 100, height: 16))
        label.text = "Filter by tag"
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 13)
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class MoreCell: UICollectionViewCell {
    
    var label: UILabel!
    
    func setUp(count: Int, spotPage: Bool) {
        backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.0)
        layer.cornerRadius = 7.5
        
        if label != nil { label.text = "" }
        
        let labelY = spotPage ? 6.5 : 9
        label = UILabel(frame: CGRect(x: 7, y: labelY, width: 100, height: 16))
        label.font = UIFont(name: "SFCamera-Regular", size: 11.5)
        label.text = "+ \(count) more"
        label.textColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
        label.sizeToFit()
        addSubview(label)
    }
}


class LeftAlignedCollectionViewFlowLayout: UICollectionViewFlowLayout {

    required override init() {super.init(); common()}
    required init?(coder aDecoder: NSCoder) {super.init(coder: aDecoder); common()}
    
    private func common() {
        estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        minimumLineSpacing = 10
        minimumInteritemSpacing = 11
    }
    
    override func layoutAttributesForElements(
                    in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        guard let att = super.layoutAttributesForElements(in:rect) else {return []}
        var x: CGFloat = sectionInset.left
        var y: CGFloat = -1.0
        
        for a in att {

            if a.representedElementCategory != .cell { continue }
            
            if a.frame.origin.y >= y { x = sectionInset.left }
            a.frame.origin.x = x
            x += a.frame.width + minimumInteritemSpacing
            y = a.frame.maxY
        }
        
        return att
    }

}
///https://stackoverflow.com/questions/22539979/left-align-cells-in-uicollectionview

class NearbySpotCell: UITableViewCell {
    
    var spotObject: MapSpot!
    
    var topLine: UIView!
    var spotImage: UIImageView!
    var friendCount: UILabel!
    var friendIcon: UIImageView!
    var spotName: UILabel!
    var spotDescription: UILabel!
    var locationIcon: UIImageView!
    var distanceLabel: UILabel!
    
    /// only used for public review
    var acceptButton: UIButton!
    var rejectButton: UIButton!
    
    func setUp(spot: MapSpot) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        contentView.isUserInteractionEnabled = false 
        spotObject = spot
        
        resetCell()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1)
        addSubview(topLine)
        
        spotImage = UIImageView(frame: CGRect(x: 14, y: 16, width: 66, height: 66))
        spotImage.layer.cornerRadius = 7.5
        spotImage.layer.masksToBounds = true
        spotImage.clipsToBounds = true
        spotImage.contentMode = .scaleAspectFill
        addSubview(spotImage)
        
        let url = spot.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            spotImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        if spot.friendVisitors > 0 {
            friendCount = UILabel(frame: CGRect(x: spotImage.frame.maxX + 10, y: 14, width: 30, height: 16))
            friendCount.text = String(spot.friendVisitors)
            friendCount.textColor = UIColor(named: "SpotGreen")
            friendCount.font = UIFont(name: "SFCamera-Semibold", size: 13)
            friendCount.sizeToFit()
            addSubview(friendCount)
            
            friendIcon = UIImageView(frame: CGRect(x: friendCount.frame.maxX + 3, y: 17.5, width: 10.8, height: 9))
            friendIcon.image = UIImage(named: "FriendCountIcon")
            addSubview(friendIcon)
        }
        
        let nameY: CGFloat = spot.friendVisitors == 0 ? 24 : friendCount.frame.maxY + 2
            
        spotName = UILabel(frame: CGRect(x: spotImage.frame.maxX + 10, y: nameY, width: UIScreen.main.bounds.width - (spotImage.frame.maxX + 10) - 66, height: 16))
        spotName.text = spot.spotName
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 15)
        spotName.lineBreakMode = .byTruncatingTail
        spotName.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        addSubview(spotName)
        
        spotDescription = UILabel(frame: CGRect(x: spotImage.frame.maxX + 10, y: spotName.frame.maxY + 2, width: UIScreen.main.bounds.width - 103, height: 29))
        spotDescription.text = spot.spotDescription
        spotDescription.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        spotDescription.textColor = UIColor(red: 0.773, green: 0.773, blue: 0.773, alpha: 1)
        let descriptionHeight = getDescriptonHeight(spotDescription: spot.spotDescription)
        spotDescription.numberOfLines = descriptionHeight > 17 ? 2 : 1
        spotDescription.lineBreakMode = .byTruncatingTail
        spotDescription.sizeToFit()
        addSubview(spotDescription)
        
        /// adjust based on number of desription lines
        let adjustY: CGFloat = descriptionHeight > 17 ? 0 : descriptionHeight > 5 ? 4.5 : 9
        if adjustY > 0 {
            if friendCount != nil { friendCount.frame = CGRect(x: friendCount.frame.minX, y: friendCount.frame.minY + adjustY, width: friendCount.frame.width, height: friendCount.frame.height )}
            if friendIcon != nil { friendIcon.frame = CGRect(x: friendIcon.frame.minX, y: friendIcon.frame.minY + adjustY, width: friendIcon.frame.width, height: friendIcon.frame.height)}
            spotName.frame = CGRect(x: spotName.frame.minX, y: spotName.frame.minY + adjustY, width: spotName.frame.width, height: spotName.frame.height)
            spotDescription.frame = CGRect(x: spotDescription.frame.minX, y: spotDescription.frame.minY + adjustY, width: spotDescription.frame.width, height: spotDescription.frame.height)
        }
        
        distanceLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 45, y: 17, width: 70, height: 15))
        distanceLabel.text = spot.distance.getLocationString()
        distanceLabel.textColor = UIColor(red: 0.688, green: 0.688, blue: 0.688, alpha: 1)
        distanceLabel.font = UIFont(name: "SFCamera-Regular", size: 10.5)
        distanceLabel.sizeToFit()
        distanceLabel.frame = CGRect(x: UIScreen.main.bounds.width - distanceLabel.frame.width - 10, y: 17, width: distanceLabel.frame.width, height: distanceLabel.frame.height)
        addSubview(distanceLabel)
        
        locationIcon = UIImageView(frame: CGRect(x: distanceLabel.frame.minX - 10, y: 18.5, width: 6, height: 8.5))
        locationIcon.image = UIImage(named: "DistanceIcon")
        self.addSubview(locationIcon)
    }
    
    func setUpPublicReview() {
        if acceptButton != nil { acceptButton.setTitle("", for: .normal) }
        if rejectButton != nil { rejectButton.setTitle("", for: .normal) }

        acceptButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 110, y: 100, width: 100, height: 25))
        acceptButton.setTitle("Accept", for: .normal)
        acceptButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        acceptButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        acceptButton.contentVerticalAlignment = .center
        acceptButton.contentHorizontalAlignment = .center
        acceptButton.addTarget(self, action: #selector(acceptPublicSpot(_:)), for: .touchUpInside)
        addSubview(acceptButton)
        
        rejectButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 + 10, y: 100, width: 100, height: 25))
        rejectButton.setTitle("Reject", for: .normal)
        rejectButton.setTitleColor(UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1), for: .normal)
        rejectButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        rejectButton.contentVerticalAlignment = .center
        rejectButton.contentHorizontalAlignment = .center
        rejectButton.addTarget(self, action: #selector(rejectPublicSpot(_:)), for: .touchUpInside)
        addSubview(rejectButton)
    }
    
    @objc func acceptPublicSpot(_ sender: UIButton) {
        sendAcceptPublicNotification(spot: spotObject)
        if let reviewPublic = viewContainingController() as? ReviewPublicController {
            reviewPublic.pendingSpots.removeAll(where: {$0.id == spotObject.id})
            reviewPublic.spotsTable.reloadData()
        }
    }
    
    @objc func rejectPublicSpot(_ sender: UIButton) {
        
      ///  sendRejectPublicNotification(spot: spotObject) -> don't really think this is even necessary
        let db = Firestore.firestore()
        db.collection("submissions").document(spotObject.id!).delete() /// deleting here now that not deleting from noti send
        
        if let reviewPublic = viewContainingController() as? ReviewPublicController {
            reviewPublic.pendingSpots.removeAll(where: {$0.id == spotObject.id})
            reviewPublic.spotsTable.reloadData()
        }
    }
    
    func getDescriptonHeight(spotDescription: String) -> CGFloat {
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 103, height: 29))
        tempLabel.text = spotDescription
        tempLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()
        return tempLabel.frame.height
    }
    
    func resetCell() {
        if topLine != nil { topLine.backgroundColor = nil }
        if spotImage != nil { spotImage.image = UIImage() }
        if friendCount != nil { friendCount.text = "" }
        if friendIcon != nil { friendIcon.image = UIImage() }
        if spotName != nil { spotName.text = "" }
        if spotDescription != nil { spotDescription.text = "" }
        if locationIcon != nil { locationIcon.image = UIImage() }
        if distanceLabel != nil { distanceLabel.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if spotImage != nil { spotImage.sd_cancelCurrentImageLoad() }
    }
}

class NearbySpotsHeader: UIView {
    
    var topView: UIView!
    var topLine: UIView!
    var sortLabel: UILabel!
    var sortBy: UILabel!
    var arrow: UIImageView!
    var filterButton: UIButton!
    var filterView: UIView!
    
    func setUp(spotCount: Int, sortType: String, filterTags: [Tag], selectedUser: CityUser) {
                
        backgroundColor = nil
        
        if topView != nil { topView.backgroundColor = nil }
        topView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 20))
        topView.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.0)
        addSubview(topView)
        
        let titleView = UIView(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 35))
        titleView.backgroundColor = UIColor(red: 0.011, green: 0.011, blue: 0.011, alpha: 1.0)
        addSubview(titleView)
        
        if topLine != nil { topLine = nil }
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1)
        titleView.addSubview(topLine)
        
        if sortLabel != nil { sortLabel = nil }
        sortLabel = UILabel(frame: CGRect(x: 14, y: 10.5, width: 130, height: 19))
        sortLabel.text = "Sort \(spotCount) spot"
        if spotCount != 1 { sortLabel.text = sortLabel.text! + "s"}
        sortLabel.text = sortLabel.text! + " by"
        sortLabel.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        sortLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        sortLabel.sizeToFit()
        titleView.addSubview(sortLabel)
        
        if sortBy != nil { sortBy = nil }
        sortBy = UILabel(frame: CGRect(x: sortLabel.frame.maxX + 5, y: 11, width: 50, height: 23))
        sortBy.text = sortType
        sortBy.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        sortBy.font = UIFont(name: "SFCamera-Semibold", size: 12)
        sortBy.sizeToFit()
        titleView.addSubview(sortBy)
        
        if arrow != nil { arrow = nil }
        arrow = UIImageView(frame: CGRect(x: sortBy.frame.maxX + 6, y: 15, width: 12.5, height: 7))
        arrow.contentMode = .scaleAspectFit
        arrow.image = UIImage(named: "ActionArrow")
        arrow.isUserInteractionEnabled = false
        titleView.addSubview(arrow)
        
        let filterWidth = arrow.frame.maxX - sortBy.frame.minX + 20
        filterButton = UIButton(frame: CGRect(x: sortBy.frame.minX - 10, y: 2.5, width: filterWidth, height: 30))
        filterButton.backgroundColor = nil
        titleView.addSubview(filterButton)
        
        /// add selected tags and user if applicable
        if filterView != nil { for sub in filterView.subviews { sub.removeFromSuperview() }}
        let filterView = UIView(frame: CGRect(x: UIScreen.main.bounds.width - 132, y: 0, width: 132, height: 35))
        filterView.backgroundColor = nil
        titleView.addSubview(filterView)
       
        /// left align selected tags
        var minX: CGFloat = 96
        for tag in filterTags {
            let tagView = HeaderFilterView(frame: CGRect(x: minX, y: 6.5, width: 22, height: 22))
            tagView.image = tag.image
            minX -= 32
            filterView.addSubview(tagView)
            
            /// load image from DB
            if tagView.image == UIImage() && tag.imageURL != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
                tagView.sd_setImage(with: URL(string: tag.imageURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
        }
     
        if selectedUser.user.imageURL != "" {
            let userView = HeaderFilterView(frame: CGRect(x: minX, y: 6.5, width: 22, height: 22))
            userView.setUp(imageURL: selectedUser.user.imageURL)
            filterView.addSubview(userView)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class HeaderFilterView: UIImageView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFill
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(imageURL: String) {
        
        layer.cornerRadius = 11
        layer.masksToBounds = true

        if imageURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 50, height: 50), scaleMode: .aspectFill)
            sd_setImage(with: URL(string: imageURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
    }
}

class NearbyCityCell: UITableViewCell {
    
    var currentLabel: UILabel!
    var cityLabel: UILabel!
    var friendsLabel: UILabel!
    var separatorView: UIView!
    var spotsLabel: UILabel!
    var bottomLine: UIView!
    
    func setUp(city: City) {

        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        resetCell()
        
        if city.activeCity {
            currentLabel = UILabel(frame: CGRect(x: 14, y: 0, width: 100, height: 16))
            currentLabel.text = "Current"
            currentLabel.textColor = UIColor(named: "SpotGreen")
            currentLabel.font = UIFont(name: "SFCamera-Regular", size: 11)
            addSubview(currentLabel)
        }
        
        cityLabel = UILabel(frame: CGRect(x: 14, y: 16, width: 300, height: 18))
        cityLabel.text = city.cityName
        cityLabel.textColor = city.activeCity ? UIColor(named: "SpotGreen") : UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        cityLabel.font = UIFont(name: "SFCamera-Semibold", size: 15)
        cityLabel.sizeToFit()
        addSubview(cityLabel)
        
        if city.friends.count > 0 {
            friendsLabel = UILabel(frame: CGRect(x: 14, y: cityLabel.frame.maxY + 1, width: 100, height: 16))
            friendsLabel.text = "\(city.friends.count) friend"
            if city.friends.count != 1 { friendsLabel.text! += "s" }
            friendsLabel.textColor = UIColor(red: 0.773, green: 0.773, blue: 0.773, alpha: 1)
            friendsLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
            friendsLabel.sizeToFit()
            addSubview(friendsLabel)
            
            separatorView = UIView(frame: CGRect(x: friendsLabel.frame.maxX + 10, y: friendsLabel.frame.midY - 0.5, width: 5, height: 2))
            separatorView.backgroundColor = UIColor(red: 0.773, green: 0.773, blue: 0.773, alpha: 1)
            separatorView.layer.cornerRadius = 0.5
            addSubview(separatorView)
        }
        
        let minX = city.friends.count > 0 ? separatorView.frame.maxX + 10 : 14
            
        spotsLabel = UILabel(frame: CGRect(x: minX, y: cityLabel.frame.maxY + 1, width: 100, height: 16))
        spotsLabel.text = "\(city.spotCount) spot"
        if city.spotCount != 1 { spotsLabel.text! += "s" }
        spotsLabel.textColor = UIColor(red: 0.773, green: 0.773, blue: 0.773, alpha: 1)
        spotsLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        spotsLabel.sizeToFit()
        addSubview(spotsLabel)
        
        bottomLine = UIView(frame: CGRect(x: 0, y: 64, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1)
        addSubview(bottomLine)
    }
    
    
    func resetCell() {
        if currentLabel != nil { currentLabel.text = "" }
        if cityLabel != nil { cityLabel.text = "" }
        if friendsLabel != nil { friendsLabel.text = "" }
        if separatorView != nil { separatorView.backgroundColor = nil }
        if spotsLabel != nil { spotsLabel.text = "" }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
}

// empty state added to usersCollection
class NearbyEmptyCell: UICollectionViewCell {
    
    var label: UILabel!
    var addFriendsButton: UIButton!
    
    func setUp(lowFriends: Bool) {
        backgroundColor = UIColor(named: "SpotBlack")
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 3, y: 0, width: 150, height: 16))
        label.text = "No friends in this city yet"
        label.textColor = UIColor(red: 0.479, green: 0.479, blue: 0.479, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 12)
        addSubview(label)
        
        if lowFriends {
            if addFriendsButton != nil { addFriendsButton.setImage(UIImage(), for: .normal)}
            addFriendsButton = UIButton(frame: CGRect(x: 3, y: label.frame.maxY + 10, width: 156, height: 41.4))
            addFriendsButton.setImage(UIImage(named: "NearbyAddFriends"), for: .normal)
            addFriendsButton.addTarget(self, action: #selector(addFriendsTap(_:)), for: .touchUpInside)
            addSubview(addFriendsButton)
        }
    }
    
    @objc func addFriendsTap(_ sender: UIButton) {
        if let nearbyVC = viewContainingController() as? NearbyViewController {
            if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "FindFriends") as? FindFriendsController {
                vc.mapVC = nearbyVC.mapVC
                nearbyVC.present(vc, animated: true, completion: nil)
            }
        }
    }
}

// all fetch functions
extension NearbyViewController {
    
    func getCity(completion: @escaping (_ city: String) -> Void) {
        if mapVC.currentLocation == nil { completion(""); return }
        reverseGeocodeFromCoordinate(numberOfFields: 2, location: mapVC.currentLocation) {  city in
            completion(city)
        }
    }
    
    func getNearbyCities(radius: Double) {
        
        let geoFire = GeoFirestore(collectionRef: Firestore.firestore().collection("cities"))
        
        circleQuery = geoFire.query(withCenter: GeoPoint(latitude: self.mapVC.currentLocation.coordinate.latitude, longitude: self.mapVC.currentLocation.coordinate.longitude), radius: radius)
        let _ = circleQuery?.observe(.documentEntered, with: loadCityFromDB)
    }
    
    func loadCityFromDB(key: String?, location: CLLocation?) {
        
        if nearbyCities.contains(where: {$0.id == key}) || selectedCity.name == key { return }
        guard let cityKey = key else { return }
        guard let coordinate = location?.coordinate else { return }
        
        nearbyCityCounter += 1
        
        let ref = db.collection("cities").document(cityKey)
        ref.getDocument { [weak self] (citySnap, err) in
           
           guard let self = self else { return }
           guard let doc = citySnap else { return}
            
            do {
                
                let info = try doc.data(as: City.self)
                guard var cityInfo = info else { self.cityDuplicateCount += 1; if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter {  self.reloadCities() }; return }
                
                cityInfo.cityLat = coordinate.latitude
                cityInfo.cityLong = coordinate.longitude
                
                /// duplicate cities for re-running the query
                if self.enteredCities.contains(where: {$0 == cityInfo.cityName}) {
                    /// user city already added
                    self.cityDuplicateCount += 1
                    if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter {
                        self.reloadCities()
                    }
                    return
                }
                
                self.enteredCities.append(cityInfo.cityName)
                self.getSpotsForCity(city: cityInfo)
                
            } catch { self.cityDuplicateCount += 1; if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter {  self.reloadCities() }; return }
        }
    }
    
    func getSpotsForCity(city: City) {

        var cityInfo = city
        let query = self.db.collection("spots").whereField("city", isEqualTo: cityInfo.cityName)
        query.getDocuments { (spotSnap, err) in
            
            if spotSnap?.documents.count ?? 0 == 0 {
                self.cityDuplicateCount += 1
                if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter {
                    self.reloadCities()
                }
            }
            
            var spotIndex = 0
            
            spotLoop: for spot in spotSnap!.documents {
                
                do {
                    
                    let info = try spot.data(as: MapSpot.self)
                    guard let spotInfo = info else { spotIndex += 1; if spotIndex == spotSnap?.documents.count { self.nearbyCities.append(cityInfo); if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter { self.reloadCities() }; }; continue spotLoop }
                    
                    /// check for 0
                    if spotInfo.postIDs.count == 0 {
                        spotIndex += 1
                        if spotIndex == spotSnap?.documents.count {
                            self.nearbyCities.append(cityInfo)
                            if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter {
                                self.reloadCities()
                            }
                        }
                        continue spotLoop
                    }

                    /// check for user access, increment friend visitors to cityFriends
                    if self.hasSpotAccess(spot: spotInfo, mapVC: self.mapVC) {
                        
                        for visitor in spotInfo.visitorList {
                            if self.isFriends(id: visitor) && !cityInfo.friends.contains(visitor) {
                                cityInfo.friends.append(visitor)
                            }
                        }
                        cityInfo.spotCount += 1
                    }
                    
                    spotIndex += 1
                    if spotIndex == spotSnap?.documents.count {
                        self.nearbyCities.append(cityInfo)
                        if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter {
                            self.reloadCities()
                        }
                    }
                    
                } catch {
                    spotIndex += 1; if spotIndex == spotSnap?.documents.count {
                        self.nearbyCities.append(cityInfo)
                        if self.cityDuplicateCount + self.nearbyCities.count == self.nearbyCityCounter {
                            self.reloadCities()
                        }
                    }
                    continue spotLoop
                }
            }
        }
    }
    
    func reloadCities() {
        /// give cities scores based on 1) location 2) spots 3) friends. if less than 5 with no spots then rerun with larger radius
        if nearbyCities.count < 6 {
            cityRadius = cityRadius * 3
            getNearbyCities(radius: cityRadius)
            return
        }
        
        for i in 0...nearbyCities.count - 1 {
            let city = nearbyCities[i]
            let cityLocation = CLLocation(latitude: city.cityLat, longitude: city.cityLong)
            let distanceFromUser = cityLocation.distance(from: mapVC.currentLocation)
            nearbyCities[i].score = (100000/distanceFromUser) * (5 * Double(city.friends.count) + 2 * Double(city.spotCount))
        }
        
        nearbyCities.sort(by: {(!$0.activeCity && !$1.activeCity) ? $0.score > $1.score : $0.activeCity && !$1.activeCity})
        DispatchQueue.main.async { print("reload data"); self.citiesTable.reloadData() }
        nearbyCityCounter = 0
    }
    
    func getSpots() {

        let query = db.collection("spots").whereField("city", isEqualTo: selectedCity.name)
        let localCity = selectedCity.name
        
        listener1 = query.addSnapshotListener(includeMetadataChanges: true, listener: ({ [weak self] (snap, err) in
            
            guard let self = self else { return }
            guard let snap = snap else { return }
            
            var spotCount = 0
            if snap.documents.count == 0 { self.getUsersSize(); self.getTagsSize(); self.getSpotScores() }
            
            for spot in snap.documents {
                
                do {
                    
                    let spotInfo = try spot.data(as: MapSpot.self)
                    guard var info = spotInfo else { spotCount += 1; if spotCount == snap.documents.count { self.getUsersSize(); self.getTagsSize(); self.getSpotScores() }; continue }
                    
                    /// rare case where this load isn't finished running before cities are changed
                    if self.selectedCity.name != localCity { return }
                    
                    /// should update doc on add from cache but doesnt seem to usually fire
                    if self.citySpots.contains(where: {$0.spot.id == spot.documentID}) { return }
                    
                    info.id = spot.documentID
                    
                    if self.hasSpotAccess(spot: info, mapVC: self.mapVC) {
                        
                        /// only way a spot will be filtered here is typically if already filtered on reset city
                        var filtered = self.selectedUserID != nil && !info.visitorList.contains(where: {$0 == self.selectedUserID})
                        for tag in self.selectedTags { if !info.tags.contains(tag) { filtered = true }}

                        /// check for friend visitors
                        for visitor in info.visitorList {
                            if let index = self.cityFriends.firstIndex(where: {$0.user.id! == visitor}) {
                                self.cityFriends[index].spotsList.append((info, filtered: filtered))
                                self.cityFriends[index].filteredCount += filtered ? 0 : 1
                            }
                        }
                        
                        /// check for tags
                        for tag in info.tags {
                            if let index = self.cityTags.firstIndex(where: {$0.name == tag}) {
                                if !filtered { self.cityTags[index].spotCount += 1 }
                            } else {
                                let newTag = Tag(name: tag)
                                if !filtered { newTag.spotCount = 1 }
                                self.cityTags.append(newTag)
                            }
                        }
                                                
                        let spotLocation = CLLocation(latitude: info.spotLat, longitude: info.spotLong)
                        let distanceFromImage = spotLocation.distance(from: self.mapVC.currentLocation)
                        info.distance = distanceFromImage
                        
                        info.friendVisitors = self.getFriendVisitors(visitorList: info.visitorList)
                        
                        self.citySpots.append((spot: info, filtered: filtered))
                        /// check for last then reload collections
                    }
                    
                    spotCount += 1
                    if spotCount == snap.documents.count {
                        self.checkForBlankTagImages()
                    }
                    
                } catch {
                    
                    spotCount += 1
                    if spotCount == snap.documents.count {
                        self.checkForBlankTagImages()
                    }
                }
            }
        }))
    }
    
    /// check if need to load tag URL from database
    func checkForBlankTagImages() {

        if cityTags.count == 0 { getUsersSize(); getTagsSize(); getSpotScores(); return }
        var tagCount = 0

        for i in 0...cityTags.count - 1 {
            
            let tag = cityTags[i]
            
            if tag.image == UIImage() {
                tag.getImageURL { [weak self] url in
                    guard let self = self else { return }
                    self.cityTags[i].imageURL = url
                    tagCount += 1; if tagCount == self.cityTags.count { self.getUsersSize(); self.getTagsSize(); self.getSpotScores() }
                }
                
            } else {
                tagCount += 1
                if tagCount == cityTags.count {
                    self.getUsersSize()
                    self.getTagsSize()
                    self.getSpotScores()
                }
            }
        }
    }
    
    func getFriendVisitors(visitorList: [String]) -> Int {
        var friendCount = 0
        for visitor in visitorList {
            if self.mapVC.friendIDs.contains(visitor) && !mapVC.adminIDs.contains(visitor) || visitor == uid { friendCount += 1 }
        }
        return friendCount
    }
    
    func isFriends(id: String) -> Bool {
        if id == uid || (mapVC.friendIDs.contains(where: {$0 == id}) && !(mapVC.adminIDs.contains(id))) { return true }
        return false
    }
    
    func getUsersSize() {
        /// reset usersCollection values on resize
        usersMoreNeeded = false
        removeLoadingIndicator()
        
        halfScreenUserCount = 0
        fullScreenUserCount = 0
        halfScreenUserHeight = 0
        fullScreenUserHeight = 0
        
        var stopIncrementingHalf = false
        var stopIncrementingFull = false
                
        var numberOfRows = 0
        var lineWidth: CGFloat = 11
        
        /// selected user goes first, then sort by filtered count
        cityFriends.sort(by: {!$0.selected && !$1.selected ? $0.filteredCount > $1.filteredCount : $0.selected && !$1.selected})
        let above0 = cityFriends.prefix(while: {$0.filteredCount > 0 || $0.selected})
        if above0.count == 0 { resizeUsers(refresh: false) }
        
        for friend in above0 {
            
            if friend.filteredCount > 0 {
                let userWidth = getWidth(name: friend.user.username, spotCount: friend.filteredCount)
                if lineWidth + userWidth + 11 > UIScreen.main.bounds.width || fullScreenUserCount == 0 {
                    
                    /// new row
                    numberOfRows += 1
                    
                    if numberOfRows == 3 {
                        /// if this is the 3rd row, stop incrementing half screen size and half screen users and check if there will be room for the + more cell on half screen
                        let extraCount = above0.count - halfScreenUserCount
                        let moreWidth = getMoreWidth(extraCount: extraCount)
                        usersMoreNeeded = true
                        
                        /// room for an extra user cell if more won't cause line overflow
                        if lineWidth + moreWidth + 11 < UIScreen.main.bounds.width {
                            halfScreenUserCount += 1
                            
                        } else {
                            /// another user cell would have fit, but the more cell won't fit. -2 because the user that we're replacing is the one that is an additional user back from where the current user would be
                            guard let previousUser = above0[safe: halfScreenUserCount - 2] else { return }
                            let previousWidth = getWidth(name: previousUser.user.username, spotCount: previousUser.filteredCount)
                            if lineWidth - previousWidth + moreWidth + 11 > UIScreen.main.bounds.width {
                                halfScreenUserCount -= 1
                            }
                        }
                        
                        stopIncrementingHalf = true
                    }
                    
                    /// resize users collection, max height is 264 (6 rows)
                    lineWidth = 11
                    /// rowheightX + headerHeight
                    let rowHeight = CGFloat(numberOfRows * 44) + 29
                    
                    if rowHeight > 294 {
                        stopIncrementingFull = true
                    } else {
                        fullScreenUserHeight = rowHeight
                        if !stopIncrementingHalf { halfScreenUserHeight = fullScreenUserHeight }
                    }
                }
                
                /// increment number of users in section
                lineWidth += userWidth + 10
                if !stopIncrementingFull { fullScreenUserCount += 1 }
                if !stopIncrementingHalf { halfScreenUserCount = fullScreenUserCount }
                
                if friend.user.id == above0.last?.user.id  || stopIncrementingFull {
                    resizeUsers(refresh: false)
                }
            }
        }
    }
    
    func resizeUsers(refresh: Bool) {
        
        /// 0.25 on drawer animations, 0.35 otherwise
     
        /// adjust halfScreenUserHeight to accomodate empty state
        if halfScreenUserHeight == 0 { halfScreenUserHeight = (!cityFriends.contains(where: {!$0.spotsList.isEmpty}) && mapVC.friendIDs.count < 15) ? 110 : 50 }
        
        let speed: TimeInterval = refresh ? 0.25 : 0.35

        DispatchQueue.main.async {
            /// resize users section to show all users or 2 rows
            UIView.animate(withDuration: speed) { [weak self] in
                guard let self = self else { return }
                let height = self.expandUsers ? self.fullScreenUserHeight : self.halfScreenUserHeight
                print("half screen height", self.halfScreenUserHeight)
                self.usersCollection.frame = CGRect(x: self.usersCollection.frame.minX, y: 0, width: self.usersCollection.frame.width, height: height)
                
                let indexSet: IndexSet = IndexSet(0...0)
                self.usersCollection.performBatchUpdates { self.usersCollection.reloadSections(indexSet) }
            }
        }
    }
    
    func getTagsSize() {

        /// tags will always be fully expanded for now
        tagsMoreNeeded = false

        halfScreenTagsCount = 0
        fullScreenTagsCount = 0
        halfScreenTagsHeight = 0
        fullScreenTagsHeight = 0
        
        var stopIncrementingHalf = false

        var numberOfRows = 0
        var lineWidth: CGFloat = 11
        
        self.cityTags.sort(by: {!$0.selected && !$1.selected ? $0.spotCount > $1.spotCount : $0.selected && !$1.selected})
        let above0 = cityTags.prefix(while: {$0.spotCount > 0 || $0.selected})
        
        if above0.count == 0 { self.resizeTags(refresh: false) }
        
        for tag in above0 {
            
            let userWidth = getWidth(name: tag.name, spotCount: tag.spotCount)
            if lineWidth + userWidth + 11 > UIScreen.main.bounds.width || tag.name == above0.first?.name {
               
                /// new row
                numberOfRows += 1
                
                if numberOfRows == 4 {
                    /// if this is the 4th row, stop incrementing half screen size and half screen tags and check if there will be room for the + more cell on half screen
                    let extraCount = above0.count - halfScreenTagsCount
                    let moreWidth = getMoreWidth(extraCount: extraCount)
                    tagsMoreNeeded = true
                    
                    if lineWidth + moreWidth + 11 < UIScreen.main.bounds.width {
                        halfScreenTagsCount += 1
                        
                    } else {
                        /// another tag cell would have fit, but the more cell won't fit. -2 because the tag that we're replacing is the one that is an additional tag back from where the current tag would be
                        guard let previousTag = above0[safe: halfScreenTagsCount - 2] else { return }
                        let previousWidth = getWidth(name: previousTag.name, spotCount: previousTag.spotCount)
                        if lineWidth - previousWidth + moreWidth + 11 > UIScreen.main.bounds.width {
                            halfScreenTagsCount -= 1
                        }
                    }
                    
                    
                    stopIncrementingHalf = true
                }

                lineWidth = 11
                /// rowHeightX + header height
                let rowHeight = CGFloat(numberOfRows * 44) + 29
                fullScreenTagsHeight = rowHeight
                if !stopIncrementingHalf { halfScreenTagsHeight = fullScreenTagsHeight }
            }
            
            /// increment number of tags in section
            lineWidth += userWidth + 10
            fullScreenTagsCount += 1
            if !stopIncrementingHalf { halfScreenTagsCount = fullScreenTagsCount }
            
            if tag.name == above0.last?.name {
                self.resizeTags(refresh: false)
            }
        }
    }
    
    func resizeTags(refresh: Bool) {
        
        /// 0.25 on drawer animations, 0.35 otherwise
        let speed: TimeInterval = refresh ? 0.25 : 0.35
        
        /// call resize spots here to ensure that tags height has already been fetched
        resizeSpots()
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: speed) { [weak self] in
                guard let self = self else { return }
                
                let minPosts: CGFloat = 0
                let minY: CGFloat = self.expandUsers ? minPosts + self.fullScreenUserHeight + 2 : minPosts + self.halfScreenUserHeight + 2
                let height = self.expandTags ? self.fullScreenTagsHeight : self.halfScreenTagsHeight
                self.tagsCollection.frame = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: height)
                
                let indexSet: IndexSet = IndexSet(0...0)
                self.tagsCollection.performBatchUpdates { self.tagsCollection.reloadSections(indexSet) }
            }
        }
    }
    
    func resizeSpots() {

        if sortByScore {
            /// filter by spot score
            self.citySpots.sort(by: {!$0.filtered && !$1.filtered ? $0.spot.spotScore > $1.spot.spotScore : !$0.filtered && $1.filtered})
        } else {
            /// filter by spots distance from user
            self.citySpots.sort(by: {!$0.filtered && !$1.filtered ? $0.spot.distance < $1.spot.distance : !$0.filtered && $1.filtered})
        }
        
        let spotsEmpty = self.citySpots.count == 0
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.4) { [weak self] in
                guard let self = self else { return }
                
                let minPosts: CGFloat = 0
                let usersHeight = self.expandUsers ? self.fullScreenUserHeight : self.halfScreenUserHeight
                let tagsHeight = self.expandTags ? self.fullScreenTagsHeight : self.halfScreenTagsHeight
                let minY: CGFloat = minPosts + usersHeight + tagsHeight - 8
                                
                self.spotsHeader.isHidden = spotsEmpty || !self.resultsTable.isHidden || !self.citiesTable.isHidden
                self.spotsHeader.frame = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: 55)
                self.spotsTable.frame = CGRect(x: 0, y: self.spotsHeader.frame.maxY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                self.reloadSpotsTable()
                
                /// size of shadow scroll reflects the total number of cells in the tableview - all unfiltered spots
                let unfiltered = self.citySpots.prefix(while: {!$0.filtered})
                let height = CGFloat(unfiltered.count) * 98
                self.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: minY + height + 250)
            }
        }
    }
    
    func reloadSpotsTable() {
        
        let indexSet: IndexSet = IndexSet(0...0)
        self.spotsTable.performBatchUpdates { self.spotsTable.reloadSections(indexSet, with: .fade) }

        let unfiltered = citySpots.prefix(while: {!$0.filtered})
        let sortType = sortByScore ? "TOP" : "NEAREST"

        var filterTags: [Tag] = []
        for tag in selectedTags { filterTags.append(cityTags.first(where: {$0.name == tag})!) }
        
        var selectedUser = CityUser(user: UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: ""))
        if let user = cityFriends.first(where: {$0.selected}) {
            selectedUser = user
        }
        
        spotsHeader.setUp(spotCount: unfiltered.count, sortType: sortType, filterTags: filterTags, selectedUser: selectedUser)
        spotsHeader.filterButton.addTarget(self, action: #selector(headerTap(_:)), for: .touchUpInside)
    }
    
    func getSpotScores() {
        
        /// increment current city if not refresh
        if let i = nearbyCities.firstIndex(where: {$0.cityName == selectedCity.name}) {
            if nearbyCities[i].spotCount == 0 {
                nearbyCities[i].spotCount = citySpots.count
                let activeFriends = cityFriends.prefix(while: {$0.spotsList.count > 0})
                nearbyCities[i].friends = activeFriends.map({$0.user.id!})
                if nearbyCities.count > 4 { DispatchQueue.main.async {
                    self.citiesTable.reloadData()
                }}
            }
        }
        
        /// spot score is a composite score based on a spots popularity to the user
        if citySpots.count == 0 { return }
        for i in 0...citySpots.count - 1 {
            
            let spot = citySpots[i].spot
            
            /// increment score for each friend visitor
            var score: Float = 0
            for visitor in spot.visitorList {
                score = score + 1
                if mapVC.friendIDs.contains(where: {$0 == visitor}) {
                    score = score + 1
                }
            }
            
            for j in 0 ... spot.postIDs.count - 1 {
                
                var postScore: Float = 2
                
                /// increment for each friend post
                if spot.posterIDs.count <= j { return }
                if isFriends(id: spot.posterIDs[j]) { postScore = postScore + 2 }

                let timestamp = spot.postTimestamps[j]
                let postTime = Float(timestamp.seconds)
                
                let current = NSDate().timeIntervalSince1970
                let currentTime = Float(current)
                let timeSincePost = currentTime - postTime
                
                /// add multiplier for recent posts
                var factor = min(1 + (1000000 / timeSincePost), 5)
                let multiplier = pow(1.5, factor)
                factor = multiplier
                
                postScore = postScore * factor
                score = score + postScore
                
            }
            
            self.citySpots[i].spot.spotScore = score
        }
    }
        
    func filter() {
        if let selectedUser = mapVC.friendsList.first(where: {$0.id == selectedUserID}) {
            mapVC.filterUser = selectedUser
        } else if selectedUserID == uid {
            mapVC.filterUser = mapVC.userInfo
        } else { mapVC.filterUser = nil }
        
        /// update filter view and filter map based on selected tags / user
        mapVC.filterTags = selectedTags
        mapVC.filterFromNearby()
        
        /// empty city load while filters were aleady selected, just remove filters and reload
        if citySpots.count == 0 {
            cityTags.removeAll(where: {!$0.selected})
            for i in 0...cityFriends.count - 1 { cityFriends[i].filteredCount = 0 }
            getUsersSize()
            getTagsSize()
            return
        }

        /// reset individual tag spot counts
        for i in 0...cityTags.count - 1 { cityTags[i].spotCount = 0 }
        for i in 0...cityFriends.count - 1 { cityFriends[i].filteredCount = 0 }
        
        /// filter tags and spots collection by this tag
        spotLoop: for i in 0...citySpots.count - 1 {
            let spot = citySpots[i]
            
            /// filter by user
            if selectedUserID != nil && !(spot.spot.visitorList.contains(where: {$0 == selectedUserID})) {
                citySpots[i].filtered = true
                continue spotLoop
            }
            
            /// filter by tag
            for tag in selectedTags {
                if !spot.spot.tags.contains(tag) {
                    citySpots[i].filtered = true
                    continue spotLoop
                }
            }
            
            /// not filtered if this spot contains all selected tags
            citySpots[i].filtered = false
            
            /// increment tag count for the tags of this spot
            for tag in spot.spot.tags {
                if let index = cityTags.firstIndex(where: {$0.name == tag}) {
                    cityTags[index].spotCount += 1
                }
            }
        }

        /// filter user collection by this tag
        if cityFriends.count == 0 { return }
        for i in 0...cityFriends.count - 1 {
            /// run through users spots to filter if they include all selected tags
            let friend = cityFriends[i]
            if friend.spotsList.count == 0 { continue }
            
            spotLoop: for j in 0...friend.spotsList.count - 1 {
                let spot = friend.spotsList[j]
                
                /// don't filter by user for users here because each user will still show the normal spot count even with other users selected
                /// filter by tag
                for tag in selectedTags {
                    if !spot.spot.tags.contains(tag) {
                        cityFriends[i].spotsList[j].filtered = true
                        continue spotLoop
                    }
                }
                /// not filtered if this spot contains all selected tags and selected user
                cityFriends[i].spotsList[j].filtered = false
                cityFriends[i].filteredCount += 1
            }
        }
        
        getUsersSize()
        getTagsSize()
    }
}

extension NearbyViewController: MKLocalSearchCompleterDelegate {
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        
        for result in completer.results {
            if result.isCity() {
                if !queryCities.contains(where: {$0.title == result.title && $0.subtitle == result.subtitle}) { queryCities.append(result) }
            }
        }
        
        self.citiesTable.reloadData()
    }
}

extension MKLocalSearchCompletion {
    
    func isCity() -> Bool {
        if isState() { return false }
        if subtitle.contains(",") { return false }
        if title.contains(",") || subtitle != "" { return true }
        return false
    }
    
    func cityFormatter() -> String {
        
        // return city, state in US | city, country for Int
        
        // format 1: usually US cities, occasionally non-US
        /// title = city, state, country
        /// subtitle = ""
        //format 2: some non-US cities
        /// title = city, state
        /// subtitle = country
        //format 3: some non-US cities
        /// title = city
        /// subtitle = country
        //format 4: (update): US cities
        /// title = city, state
        /// subtitle = country
        
        var cityString = ""
        var commaPositions: [Int] = []
        var index = 0
        
        for c in title {
            if c == "," { commaPositions.append(index) }
            index += 1
        }
        
        print("title", title)
        print("subtitle", subtitle)
        
        /// format 1
        if subtitle == "" {
            
            if String(title.suffix(13)) != "United States" && commaPositions.count > 1 {
                cityString = String(title.prefix(commaPositions[0])) + String(title.suffix(title.count - commaPositions[1]))
            } else {
                cityString = commaPositions.count > 1 ? String(title.prefix(commaPositions[1])) : title
            }
            
        } else if subtitle == "United States" {
            /// format 4
            cityString = title
            
        } else {
            
        /// format 2 & 3
            let city = commaPositions.isEmpty ? title : String(title.prefix(commaPositions[0]))
            cityString = city + ", " + subtitle
        }
        
        return cityString
    }
    
    func isState() -> Bool {
        
        var testString = ""
        var commaPositions: [Int] = []
        var index = 0
        
        for c in title {
            if c == "," { commaPositions.append(index) }
            index += 1
        }

        if commaPositions.count == 1 { testString = String(title.prefix(commaPositions[0])) }
        return title ==  testString + ", United States"
    }
}

