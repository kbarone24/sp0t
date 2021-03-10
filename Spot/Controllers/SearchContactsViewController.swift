//
//  SearchContactsViewController.swift
//  Spot
//
//  Created by kbarone on 10/9/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Contacts
import Firebase
import FirebaseUI
import CoreLocation
import Mixpanel


class SearchContactsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let db: Firestore! = Firestore.firestore()
    lazy var contacts: [Contact] = []
    lazy var numbers: [String] = []
    lazy var friendsList: [String] = []
    
    var dataFetched = false
    var sentFromTutorial = false
    var uid : String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var tableView : UITableView!
    var activityIndicatorView: CustomActivityIndicator!
        
    private let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Mixpanel.mainInstance().track(event: "SearchContactsOpen")
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        //tableview height reset
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
        tableView.register(ContactHeader.self, forHeaderFooterViewReuseIdentifier: "ContactHeader")
        
        view.addSubview(tableView)
        
        checkAuth()
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ContactHeader") as? ContactHeader {
            header.setUp(onboarding: sentFromTutorial)
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (dataFetched) {
            return contacts.count
        } else {
            return 0
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactCell
        
        cell.backgroundColor = UIColor(named: "SpotBlack")
        
        if self.contacts.isEmpty {
            return cell
        }
        
        cell.setUpAll()
        cell.setUpContact(contact: self.contacts[indexPath.row])
        
        if !self.contacts[indexPath.row].friend && !self.contacts[indexPath.row].pending {
            cell.friendLabel.tag = indexPath.row
            cell.friendLabel.addTarget(self, action: #selector(self.addFriend), for: UIControl.Event.touchUpInside)
        }
        
        return cell
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(false)
    }
    
    @objc func addFriend(sender: UIButton) {
        Mixpanel.mainInstance().track(event: "SearchContactsAddFriend")
        let row = sender.tag
        
        let notiID = UUID().uuidString
        let ref = db.collection("users").document(self.contacts[row].id).collection("notifications").document(notiID)
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        let values = ["senderID" : self.uid,
                      "type" : "friendRequest",
                      "timestamp" : time,
                      "status" : "pending",
                      "seen" : false
            ] as [String : Any]
        
        ref.setData(values)
        
        self.contacts[row].pending = true
        
        tableView.reloadData()
        
        let sender = PushNotificationSender()
        var token: String!
        var senderName: String!
        
        self.db.collection("users").document(self.contacts[row].id).getDocument { [weak self] (tokenSnap, err) in
            
            guard let self = self else { return }
            
            if (tokenSnap == nil) {
                return
            } else {
                token = tokenSnap?.get("notificationToken") as? String
            }
            
            self.db.collection("users").document(self.uid).getDocument { (userSnap, err) in
                if (userSnap == nil) {
                    return
                } else {
                    senderName = userSnap?.get("username") as? String
                    if (token != nil && token != "") {
                        sender.sendPushNotification(token: token, title: "", body: "\(senderName ?? "someone") sent you a friend request")
                    }
                }
            }
        }
        
    }
    
    func checkAuth() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .denied, .notDetermined:
            CNContactStore().requestAccess(for: CNEntityType.contacts) { [weak self] (access, accessError) in
                guard let self = self else { return }
                
                if access {
                    self.getContacts()
                } else {
                    if CNContactStore.authorizationStatus(for: .contacts) == .denied {
                        let alert = UIAlertController(title: "Allow contacts access to add friends", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                            switch action.style {
                            case .default:
                                
                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                                
                            case .cancel:
                                print("cancel")
                            case .destructive:
                                print("destruct")
                            @unknown default:
                                fatalError()
                            }}))
                        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                            switch action.style {
                            case .default:
                                guard let controllers = self.navigationController?.viewControllers else { return }
                                if let profileFriends = controllers[safe: controllers.count - 2] as? ProfileViewController {
                                    self.navigationController?.popToViewController(profileFriends, animated: false)
                                } else if let _ = UIStoryboard(name: "TabBar", bundle: nil).instantiateViewController(withIdentifier: "TabBarMain") as? CustomTabBar
                                    
                                {
                                    let sb = UIStoryboard(name: "TabBar", bundle: nil)
                                    let vc = sb.instantiateViewController(withIdentifier: "TabBarMain") as! CustomTabBar
                                    vc.modalPresentationStyle = .fullScreen
                                    DispatchQueue.main.async {
                                        self.getTopMostViewController()!.present(vc, animated: true, completion: nil)
                                    }
                                } 
                            case .cancel:
                                print("cancel")
                            case .destructive:
                                print("destruct")
                            @unknown default:
                                fatalError()
                            }}))
                        DispatchQueue.main.async {
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                }
            }
            break
            
        case .authorized:
            getContacts()
            
        case .restricted:
            getContacts()
            
        @unknown default:
            fatalError()
        }
    }
    
    
    func getContacts() {
        // get all of a users contact's phone numbers
        
        let store = CNContactStore()
        
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        var message = ""
        do {
            try store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) {
                (contact, cursor) -> Void in
                if (!contact.phoneNumbers.isEmpty) {
                    
                    for phoneNumber in contact.phoneNumbers {
                        
                        let phoneNumberStruct = phoneNumber.value as CNPhoneNumber
                        
                        let phoneNumberString = phoneNumberStruct.stringValue
                        var number = phoneNumberString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        
                        if number.count > 0 {
                            let index = number.index(number.startIndex, offsetBy: 1)
                            if String(number.prefix(upTo: index)) == "1" {
                                number = String(number.suffix(from: index))
                            }
                            self.numbers.append(number)
                        }
                    }
                }
                
            }
        } catch {
            message = "Unable to fetch contacts"
        }
        if message == "" {
            db.collection("users").document(self.uid).getDocument { [weak self] (userSnap, err) in
                guard let self = self else { return }
                if let friends = userSnap!.get("friendsList") as? [String] {
                    self.friendsList = friends
                    self.getContactInfo()
                }
            }
        } else {
            self.navigationController?.popToRootViewController(animated: false)
            
            let alert  = UIAlertController(title: "Error", message: "There was an issue accessing your contacts.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func getContactInfo() {
        // loop through all users in DB to see if users contact phone numbers contains phone number from DB
        
        activityIndicatorView = CustomActivityIndicator(frame: CGRect(x: 0, y: UIScreen.main.bounds.minX + 40, width: UIScreen.main.bounds.width, height: 30))
        tableView.addSubview(activityIndicatorView)
        DispatchQueue.main.async {
            self.activityIndicatorView.startAnimating()
        }
        
        self.db.collection("users").getDocuments { [weak self]
            (querysnapshot, err) in
            
            guard let self = self else { return }
            
            var i = 0
            if querysnapshot?.documents.count == 0 {
                self.setUpEmptyState()
            }
            for document in querysnapshot!.documents {
                if document.documentID == self.uid {
                    continue
                }
                if var number = document.get("phone") as? String {
                    number = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    let index = number.index(number.startIndex, offsetBy: 1)
                    if String(number.prefix(upTo: index)) == "1" {
                        number = String(number.suffix(from: index))
                    }
                    if (self.numbers.contains(number)) {
                        let id = document.documentID
                        if let username = document.get("username") as? String {
                            i = i + 1
                            
                            let profilePicURL = document.get("imageURL") as! String
                            let number = document.get("phone") as! String
                            let name = document.get("name") as! String
                            
                            let notiRef = self.db.collection("users").document(id).collection("notifications")
                            let friendRequestQuery = notiRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending").whereField("senderID", isEqualTo: self.uid)
                            
                            /// check if theres already a friend request pending to this contact
                            friendRequestQuery.getDocuments { [weak self] (fSnap, err) in
                                
                                guard let self = self else { return }
                                
                                if self.friendsList.contains(id) {
                                    self.getContactPictures(contact: Contact(id: id, username: username, name: name, profilePicURL: profilePicURL, profileImage: UIImage(), number: number, friend: true, pending: false))
                                    
                                } else if fSnap?.documents.count != 0 {
                                    self.getContactPictures(contact: Contact(id: id, username: username, name: name, profilePicURL: profilePicURL, profileImage: UIImage(), number: number, friend: false, pending: true))
                                    
                                } else {
                                    self.getContactPictures(contact: Contact(id: id, username: username, name: name, profilePicURL: profilePicURL, profileImage: UIImage(), number: number, friend: false, pending: false))
                                }
                                
                            }
                        } else {
                            i = i + 1
                        }
                    }
                } else {
                    i = i + 1
                }
            }
        }
        
    }
    
    /// not fetching images here anymore with sd_web framework 
    func getContactPictures(contact: Contact) {
        
            let dup = self.contacts.contains(where: {$0.id == contact.id})
            
            if !dup {
                self.contacts.append(contact)
                
                self.contacts = self.contacts.sorted(by: {$1.username > $0.username})
                self.contacts = self.contacts.sorted(by: { $1.friend && !$0.friend})
                
                self.dataFetched = true
                
                if self.activityIndicatorView.isAnimating() {self.activityIndicatorView.stopAnimating()}
                
                self.tableView.reloadData()
                
            }
        }
        
    func setUpEmptyState() {
        self.activityIndicatorView.stopAnimating()
        
        let noFriendLabel = UILabel(frame: CGRect(x: 20, y: 130, width: UIScreen.main.bounds.width - 40, height: 60))
        noFriendLabel.text = "It doesn't look like you have any contacts on sp0t yet :("
        noFriendLabel.textColor = UIColor(red:0.71, green:0.71, blue:0.71, alpha:1.0)
        noFriendLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        noFriendLabel.lineBreakMode = .byWordWrapping
        noFriendLabel.sizeToFit()
        self.view.addSubview(noFriendLabel)
    }
}

class ContactCell: UITableViewCell {
    
    var name: UILabel!
    var username: UILabel!
    var profilePic: UIImageView!
    var friendLabel: UIButton!
    var bottomLine: UIView!
        
    func setUpAll() {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.isUserInteractionEnabled = true
        self.selectionStyle = .none
        
        resetCell()
                
        profilePic = UIImageView(frame: CGRect(x: 18, y: 10, width: 36, height: 36))
        profilePic.layer.cornerRadius = 18
        profilePic.clipsToBounds = true
        profilePic.contentMode = .scaleAspectFill
        self.addSubview(profilePic)
        
        name = UILabel(frame: CGRect(x: 61, y: 12, width: UIScreen.main.bounds.width - 70, height: 17))
        name.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        name.font = UIFont(name: "SFCamera-Semibold", size: 13)
        self.addSubview(name)
        
        username = UILabel(frame: CGRect(x: 61, y: name.frame.maxY + 1, width: UIScreen.main.bounds.width - 70, height: 20))
        username.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1)
        username.font = UIFont(name: "SFCamera-Regular", size: 13)
        self.addSubview(username)
        
        bottomLine = UIView(frame: CGRect(x: 18, y: self.bounds.height - 0.25, width: UIScreen.main.bounds.width - 28, height: 0.25))
        bottomLine.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
        self.addSubview(bottomLine)
    }
    
    func setUpContact(contact: Contact) {
        friendLabel = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 130, y: 7, width: 120, height: 42))
        friendLabel.setTitleColor(UIColor.white, for: UIControl.State.normal)
        friendLabel.isHidden = false
        friendLabel.imageView?.contentMode = .scaleAspectFit
        self.addSubview(friendLabel)
        
        username.text = contact.username
        username.sizeToFit()
        
        name.text = contact.name
        name.sizeToFit()
        
        if contact.friend {
            name.alpha = 0.6
            username.alpha = 0.6
            friendLabel.setImage(UIImage(named: "ContactsFriends"), for: UIControl.State.normal)
            friendLabel.isUserInteractionEnabled = false
        } else if contact.pending {
            name.alpha = 0.6
            username.alpha = 0.6
            friendLabel.setImage(UIImage(named: "ContactsPending"), for: UIControl.State.normal)
            friendLabel.isUserInteractionEnabled = false
        } else {
            friendLabel.setImage(UIImage(named: "ContactsAddFriend"), for: UIControl.State.normal)
            friendLabel.isUserInteractionEnabled = true
        }
        
        let url = contact.profilePicURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
    }
    
    func setUpFriend(friend: Friend) {
        username.text = friend.username
        username.sizeToFit()
        
        name.text = friend.name
        name.sizeToFit()
        
        let url = friend.profilePicURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
    }
    
    func resetCell() {
        if username != nil { username.isHidden = true}
        if profilePic != nil { profilePic.isHidden = true}
        if friendLabel != nil {friendLabel.isHidden = true}
        if name != nil {name.isHidden = true}
        if bottomLine != nil { bottomLine.isHidden = true }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
        self.isUserInteractionEnabled = false
    }
}

class ContactHeader: UITableViewHeaderFooterView {
    
    var titleLabel: UILabel!
    var backButton: UIButton!
    var doneButton: UIButton!
    
    func setUp(onboarding: Bool) {
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        resetView()
        
        titleLabel = UILabel(frame: CGRect(x: 100, y: 10, width: UIScreen.main.bounds.width - 200, height: 16))
        titleLabel.text = "Search contacts"
        titleLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)
        titleLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        titleLabel.textAlignment = .center
        self.addSubview(titleLabel)
        
        /// only outlet in onboarding is the done button which launches map on tap
        if onboarding {
            doneButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 58, y: 6, width: 50, height: 26))
            doneButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            doneButton.setTitle("Done", for: .normal)
            doneButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
            doneButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
            doneButton.addTarget(self, action: #selector(done(_:)), for: .touchUpInside)
            self.addSubview(doneButton)
        } else {
            /// back button is for search contacts from user profile
            backButton = UIButton(frame: CGRect(x: 5, y: 4, width: 35, height: 35))
            backButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            backButton.setImage(UIImage(named: "BackButton"), for: .normal)
            backButton.addTarget(self, action: #selector(exit(_:)), for: .touchUpInside)
            self.addSubview(backButton)
        }
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func resetView() {
        if titleLabel != nil { titleLabel.text = "" }
        if backButton != nil { backButton.setImage(UIImage(), for: .normal) }
        if doneButton != nil { doneButton.setImage(UIImage(), for: .normal) }
    }
    
    @objc func exit(_ sender: UIButton) {
        if let contactsVC = viewContainingController() as? SearchContactsViewController {
            contactsVC.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func done(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "TabBar", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapView") as! MapViewController
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        keyWindow?.rootViewController = navController
    }
}
