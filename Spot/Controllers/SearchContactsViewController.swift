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
    var uid : String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    lazy var contacts: [Contact] = []
    lazy var numbers: [String] = []
    lazy var friendsList: [String] = []
    
    var dataFetched = false
    var sentFromTutorial = false
    
    var emptyState: UIView!
    var tableView : UITableView!
    var activityIndicatorView: CustomActivityIndicator!
            
    override func viewDidLoad() {
        
        super.viewDidLoad()
        Mixpanel.mainInstance().track(event: "SearchContactsOpen")
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
        view.addSubview(tableView)
        
        if sentFromTutorial {
            
            navigationItem.title = "Search contacts"
            navigationController?.navigationBar.backIndicatorImage = UIImage()
            navigationController?.navigationBar.backIndicatorTransitionMaskImage = UIImage()

            let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTap(_:)))
            doneButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCompactText-Semibold", size: 15) as Any, NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any], for: .normal)
            navigationItem.setRightBarButton(doneButton, animated: true)
            self.navigationItem.rightBarButtonItem?.tintColor = nil

        } else {
            /// popover view if presented from inside the main app
            tableView.register(ContactHeader.self, forHeaderFooterViewReuseIdentifier: "ContactHeader")
        }

        checkAuth()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if activityIndicatorView != nil && contacts.count == 0 && emptyState == nil {
            /// resume indicator animation
            DispatchQueue.main.async { self.activityIndicatorView.startAnimating() }
            
        } else if tableView != nil {
            /// reload to allow user interaction
            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }
    
    @objc func doneTap(_ sender: UIButton) {
        animateToMap()
    }

    func animateToMap() {
        
        let storyboard = UIStoryboard(name: "Map", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapVC") as! MapViewController
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
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sentFromTutorial ? 0 : 50
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
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ContactHeader") as? ContactHeader {
            header.setUp()
            return header
        } else { return UITableViewHeaderFooterView() }
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
            cell.friendLabel.addTarget(self, action: #selector(self.addFriend(_:)), for: UIControl.Event.touchUpInside)
        }
        
        return cell
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(false)
    }
    
    @objc func addFriend(_ sender: UIButton) {
        
        Mixpanel.mainInstance().track(event: "SearchContactsAddFriend")
        let row = sender.tag
        
        let notiID = UUID().uuidString
        let ref = db.collection("users").document(self.contacts[row].id).collection("notifications").document(notiID)
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
                
        self.contacts[row].pending = true
        
        tableView.reloadData()
        
        /// localize variables to avoid losing self on async call
        let receiverID = self.contacts[row].id
        let uid = self.uid
        let db = Firestore.firestore()
        
        /// send notification to find friends
        let mapPass = ["receiverID": receiverID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("FriendRequest"), object: nil, userInfo: mapPass)
        
        DispatchQueue.global(qos: .utility).async {
        
            let values = ["senderID" : uid,
                          "senderUsername" : UserDataModel.shared.userInfo.username,
                          "type" : "friendRequest",
                          "timestamp" : time,
                          "status" : "pending",
                          "seen" : false
                ] as [String : Any]
            ref.setData(values)

            db.collection("users").document(uid).updateData(["pendingFriendRequests" : FieldValue.arrayUnion([receiverID])])
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
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                            switch action.style {
                            case .default:
                                print("default")
                            case .cancel:
                                if self.navigationController == nil {
                                    self.dismiss(animated: true, completion: nil)
                                } else {
                                    self.animateToMap()
                                }
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
            return
        }
    }
    
    
    func getContacts() {
       
        DispatchQueue.main.async {
            self.activityIndicatorView = CustomActivityIndicator(frame: CGRect(x: 0, y: UIScreen.main.bounds.minX + 40, width: UIScreen.main.bounds.width, height: 30))
            self.activityIndicatorView.isHidden = true
            self.tableView.addSubview(self.activityIndicatorView)
        }

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
                            number = String(number.suffix(10)) /// match based on last 10 digits to eliminate country codes and formatting from matching
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
            let alert  = UIAlertController(title: "Error", message: "There was an issue accessing your contacts.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            
            return
        }
    }
    
    func getContactInfo() {
        
        // loop through all users in DB to see if users contact phone numbers contains phone number from DB
        var localContacts: [Contact] = []
        
        DispatchQueue.global().async {
            
            self.db.collection("users").getDocuments { [weak self]
                (snap, err) in

                guard let self = self else { return }
                var index = 0
                
                for document in snap!.documents {
                    
                    do {
                        
                        let info = try document.data(as: UserProfile.self)
                        guard let userInfo = info else {
                            index += 1; if index == snap!.documents.count && self.contacts.isEmpty { self.setUpEmptyState() }; continue
                        }
                        
                        let id = document.documentID
                        if id == self.uid { index += 1; if index == snap!.documents.count && self.contacts.isEmpty { self.setUpEmptyState() }; continue }
                        
                        var number = userInfo.phone ?? ""
                        number = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        number = String(number.suffix(10))
                        
                        if self.numbers.contains(number) {
                            
                            let id = document.documentID
                            
                            let notiRef = self.db.collection("users").document(id).collection("notifications")
                            let friendRequestQuery = notiRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending").whereField("senderID", isEqualTo: self.uid)
                            
                            /// check if theres already a friend request pending to this contact
                            friendRequestQuery.getDocuments { [weak self] (fSnap, err) in
                                
                                guard let self = self else { return }
                                
                                let friend = self.friendsList.contains(id)
                                let pending = !friend && fSnap?.documents.count ?? 0 > 0
                                localContacts.append(Contact(id: id, username: userInfo.username, name: userInfo.name, profilePicURL: userInfo.imageURL, number: number, friend: friend, pending: pending))
                                
                                index += 1; if index == snap!.documents.count {
                                    self.addContactsToTable(contacts: localContacts)
                                }
                            }
                            
                        } else {
                            index += 1; if index == snap!.documents.count && self.contacts.isEmpty { self.setUpEmptyState() }
                        }
                        
                    } catch {
                        index += 1; if index == snap!.documents.count && self.contacts.isEmpty { self.setUpEmptyState() }; continue
                    }
                }
            }
        }
    }
    
    func addContactsToTable(contacts: [Contact]) {
        
        for contact in contacts {
        
            self.contacts.append(contact)
            
            if self.contacts.count == contacts.count {
                DispatchQueue.main.async {
                    
                    self.contacts = self.contacts.sorted(by: {$1.username > $0.username})
                    self.contacts = self.contacts.sorted(by: { $1.friend && !$0.friend})
                    self.dataFetched = true
                    
                    if self.activityIndicatorView.isAnimating() {self.activityIndicatorView.stopAnimating()}
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func setUpEmptyState() {
        
        self.activityIndicatorView.stopAnimating()
        
        emptyState = UIView(frame: CGRect(x: 0, y: 150, width: UIScreen.main.bounds.width, height: 300))
        emptyState.backgroundColor = nil
        view.addSubview(emptyState)
        
        let botImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 16.27, y: 0, width: 32.54, height: 43.7))
        botImage.image = UIImage(named: "OnboardB0t")
        botImage.contentMode = .scaleAspectFit
        emptyState.addSubview(botImage)
        
        let emptyLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 80, y: botImage.frame.maxY + 10, width: 160, height: 40))
        emptyLabel.text = "Looks like you don’t have any friends on sp0t yet"
        emptyLabel.textColor = UIColor(red: 0.842, green: 0.842, blue: 0.842, alpha: 1)
        emptyLabel.font = UIFont(name: "SFCompactText-Regular", size: 13)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.lineBreakMode = .byWordWrapping
        emptyLabel.sizeToFit()
        emptyState.addSubview(emptyLabel)
        
        let emptyButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: emptyLabel.frame.maxY + 5, width: 200, height: 40))
        emptyButton.setTitle("Invite Friends", for: .normal)
        emptyButton.contentHorizontalAlignment = .center
        emptyButton.addTarget(self, action: #selector(inviteFriendsTap(_:)), for: .touchUpInside)
        emptyState.addSubview(emptyButton)
    }
    
    @objc func inviteFriendsTap(_ sender: UIButton) {
        if let vc = storyboard?.instantiateViewController(identifier: "SendInvites") as? SendInvitesController {
            present(vc, animated: true, completion: nil)
        }
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
        name.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        self.addSubview(name)
        
        username = UILabel(frame: CGRect(x: 61, y: name.frame.maxY + 1, width: UIScreen.main.bounds.width - 70, height: 20))
        username.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1)
        username.font = UIFont(name: "SFCompactText-Regular", size: 13)
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
    
    func setUp() {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        resetView()
        
        titleLabel = UILabel(frame: CGRect(x: 100, y: 15, width: UIScreen.main.bounds.width - 200, height: 16))
        titleLabel.text = "Search contacts"
        titleLabel.font = UIFont(name: "SFCompactText-Regular", size: 16)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        self.addSubview(titleLabel)
        
        backButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 40, y: 7, width: 35, height: 35))
        backButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        backButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        backButton.addTarget(self, action: #selector(exit(_:)), for: .touchUpInside)
        self.addSubview(backButton)
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
}
