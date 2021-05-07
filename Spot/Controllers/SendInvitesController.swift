//
//  SendInvitesController.swift
//  Spot
//
//  Created by Kenny Barone on 3/29/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Contacts
import MessageUI
import Mixpanel

enum InviteStatus {
    case joined
    case invited
    case none
}

class SendInvitesController: UIViewController {
    
    let db: Firestore! = Firestore.firestore()
    var uid : String = Auth.auth().currentUser?.uid ?? "invalid ID"
    unowned var mapVC: MapViewController!

    var sectionTitles: [String] = []
    var numbers: [String] = []
    var sentInvites: [String] = []
    var pendingNumber = "" /// temporary variable used while messages controller is presented
    
    var rawContacts: [CNContact] = []
    var contacts: [(contact: CNContact, status: InviteStatus)] = []
    var tableView: UITableView!
    var titleView: SendInvitesTitleView!
    var loadingIndicator: CustomActivityIndicator!
    
    var errorBox: UIView!
    var errorText: UILabel!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "SpotBlack")
                
        titleView = SendInvitesTitleView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 60))
        titleView.setUp(count: 5 - mapVC.userInfo.sentInvites.count)
        view.addSubview(titleView)

        tableView = UITableView(frame: CGRect(x: 0, y: 60, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDismissMode = .onDrag
        tableView.allowsSelection = false 
        tableView.register(SendInviteCell.self, forCellReuseIdentifier: "SendInvite")
        view.addSubview(tableView)
        
        loadingIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 30, width: UIScreen.main.bounds.width, height: 30))
        loadingIndicator.isHidden = true
        view.addSubview(loadingIndicator)
        
        errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 100, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        errorBox.isHidden = true
        view.addSubview(errorBox)
        
        errorText = UILabel(frame: CGRect(x: 0, y: 6, width: UIScreen.main.bounds.width, height: 18))
        errorText.lineBreakMode = .byWordWrapping
        errorText.numberOfLines = 0
        errorText.textColor = UIColor.white
        errorText.textAlignment = .center
        errorText.text = "You're all out of invites!"
        errorText.font = UIFont(name: "SFCamera-Regular", size: 14)!
        errorBox.addSubview(errorText)

        checkAuth()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if loadingIndicator != nil && contacts.count == 0 {
            /// resume frozen indicator animation
            DispatchQueue.main.async { self.loadingIndicator.startAnimating() }
            
        } else if tableView != nil && !tableView.isHidden {
            /// reload to allow user interaction
            DispatchQueue.main.async { self.tableView.reloadData() }
        }

    }
    
    func checkAuth() {
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .denied, .notDetermined, .restricted:
            CNContactStore().requestAccess(for: CNEntityType.contacts) { [weak self] (access, accessError) in
                guard let self = self else { return }
                
                if access {
                    DispatchQueue.global(qos: .userInitiated).async { self.getNumbers() }
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
                                self.dismiss(animated: true, completion: nil)
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
            DispatchQueue.global(qos: .userInitiated).async { self.getNumbers() }
                        
        @unknown default:
            return
        }
    }
    
    func getNumbers() {
        
        /// get users sent invites in correct format
        for invite in mapVC.userInfo.sentInvites {
            sentInvites.append(invite.formatNumber())
        }
        
        /// get all numbers on the app for matching -> should be faster than running individual queries
        db.collection("users").getDocuments { [weak self]
            (snap, err) in

            guard let self = self else { return }
            var index = 0
            
            for document in snap!.documents {
            
                if let phone = document.get("phone") as? String {
                    
                    let number = phone.formatNumber()
                    if !self.numbers.contains(where: {$0 == number }) { self.numbers.append(number) }
                    index += 1; if index == snap!.documents.count { self.getContacts() }
                    
                } else {
                    index += 1; if index == snap!.documents.count { self.getContacts() }
                }
            }
        }
    }
    
    
    func getContacts() {
        
        let store = CNContactStore()
        
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactImageDataKey as CNKeyDescriptor]
        let fetchRequest = CNContactFetchRequest(keysToFetch: keys)
        fetchRequest.sortOrder = .userDefault
        
        do {
            
            try store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) {
                (contact, cursor) -> Void in
                
                let phoneEmpty = contact.phoneNumbers.isEmpty
                let nameEmpty = contact.givenName.isEmpty && contact.familyName.isEmpty
                if !(phoneEmpty || nameEmpty) { self.rawContacts.append(contact) }
            }
            
            checkContactStatuses()
            
        } catch {
            let alert  = UIAlertController(title: "Error", message: "There was an issue accessing your contacts.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func checkContactStatuses() {

        var localContacts: [(contact: CNContact, status: InviteStatus)] = []
        
        for contact in rawContacts {
            
            let rawNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
            let number = rawNumber.formatNumber()

            let status: InviteStatus = numbers.contains(number) ? .joined : .none
            
            /// user already invited this contact but they haven't joined yet
            if status == .none && sentInvites.contains(number) {
                localContacts.append((contact: contact, status: .invited))
                if localContacts.count == rawContacts.count { reloadContactsTable(localContacts: localContacts) }
                continue
            }

            
            localContacts.append((contact: contact, status: status))
            if localContacts.count == rawContacts.count { reloadContactsTable(localContacts: localContacts) }
        }
    }
    
    func reloadContactsTable(localContacts: [(contact: CNContact, status: InviteStatus)]) {

        for contact in localContacts {
            
            let primaryName = contact.0.familyName.isEmpty ? contact.0.givenName : contact.0.familyName
            let sectionInitial = String(primaryName.prefix(1)).uppercased()
            
            if !sectionTitles.contains(where: {$0 == sectionInitial }) {
                sectionTitles.append(sectionInitial)
            }
        }
        
        contacts = localContacts
        
        contacts.sort {
            /// sort based on last name then first name if both, just first name if no last name available
            let criteriaA = $0.contact.familyName.isEmpty ? $0.contact.givenName.lowercased() : $0.contact.familyName.lowercased()
            let criteriaB = $1.contact.familyName.isEmpty ? $1.contact.givenName.lowercased() : $1.contact.familyName.lowercased()
            return criteriaA < criteriaB
        }
        
        sectionTitles.sort(by: {$0 < $1})

        DispatchQueue.main.async {
            self.loadingIndicator.stopAnimating()
            self.tableView.reloadData()
        }
    }
}

extension SendInvitesController: UITableViewDelegate, UITableViewDataSource {
        
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionTitles.map({$0})
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let head = sectionTitles[section]
        let firstIndex = contacts.firstIndex(where: {$0.contact.familyName.isEmpty ? $0.contact.givenName.prefix(1) == head : $0.contact.familyName.prefix(1) == head})
        let finalIndex = contacts.lastIndex(where: {$0.contact.familyName.isEmpty ? $0.contact.givenName.prefix(1) == head : $0.contact.familyName.prefix(1) == head})
        return Int(finalIndex! - firstIndex!) + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SendInvite") as? SendInviteCell else { return UITableViewCell() }
        let head = sectionTitles[indexPath.section]
        /// get first contact starting with this section letter and count from there
        let firstIndex = contacts.firstIndex(where: {$0.contact.familyName.isEmpty ? $0.contact.givenName.prefix(1) == head : $0.contact.familyName.prefix(1) == head})!
        let contact = contacts[firstIndex + indexPath.row]
        cell.setUp(contact: contact.0, status: contact.1)
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        /// set header text color 
        (view as! UITableViewHeaderFooterView).contentView.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.white
    }
        
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 61
    }
}

extension SendInvitesController: MFMessageComposeViewControllerDelegate {
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        
        switch result {
        
        case .sent:
            
            Mixpanel.mainInstance().track(event: "SendInvitesInviteSent")
            
        /// update cell
            if let i = contacts.firstIndex(where: {$0.contact.phoneNumbers.first?.value.stringValue ?? "" == pendingNumber}) {
                contacts[i].status = .invited
            }
            
        /// update header
            mapVC.userInfo.sentInvites.append(pendingNumber)
            titleView.setUp(count: 5 - mapVC.userInfo.sentInvites.count)
            
        /// update local sentInvites
            sentInvites.append(pendingNumber.formatNumber())
        
        /// send noti to find friends controller
            let notificationName = Notification.Name("SentInvite")
            NotificationCenter.default.post(name: notificationName, object: nil, userInfo: nil)

        /// upadte database
            self.db.collection("users").document(uid).updateData(["sentInvites": FieldValue.arrayUnion([pendingNumber])])
        
            DispatchQueue.main.async { self.tableView.reloadData() }
            
        default:
            print("")
        }
        
        pendingNumber = ""
        controller.dismiss(animated: true, completion: nil)
    }

    func sendInvite(number: String) {
        
        let adminID = mapVC.uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || mapVC.uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2"
        if mapVC.userInfo.sentInvites.count == 5 && !adminID {
            errorBox.isHidden = false
            return
        }
        
        if (MFMessageComposeViewController.canSendText()) {
            
            let controller = MFMessageComposeViewController()
            
            let betaString = "https://testflight.apple.com/join/dtVe46HZ"
            
            controller.body = "Hey! Here’s an invite to download sp0t, the app for finding and sharing cool spots: \(betaString)"
            controller.recipients = [number]
            controller.messageComposeDelegate = self
            
            self.pendingNumber = number
            self.present(controller, animated: true, completion: nil)
        }
    }
}

class SendInvitesTitleView: UIView {
    
    var titleLabel: UILabel!
    var subtitleLabel: UILabel!
    var backButton: UIButton!
    
    func setUp(count: Int) {
            
        backgroundColor = nil
        
        if titleLabel != nil { titleLabel.text = "" }
        titleLabel = UILabel(frame: CGRect(x: 100, y: 15, width: UIScreen.main.bounds.width - 200, height: 16))
        titleLabel.text = "Send invites"
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 16)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        addSubview(titleLabel)
        
        if subtitleLabel != nil { subtitleLabel.text = "" }
        subtitleLabel = UILabel(frame: CGRect(x: 100, y: titleLabel.frame.maxY + 1, width: UIScreen.main.bounds.width - 200, height: 16))
        subtitleLabel.text = "\(count) remaining"
        subtitleLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        subtitleLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        subtitleLabel.textAlignment = .center
        addSubview(subtitleLabel)
        
        if backButton != nil { backButton.setImage(UIImage(), for: .normal) }
        backButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 40, y: 7, width: 35, height: 35))
        backButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        backButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        backButton.addTarget(self, action: #selector(exit(_:)), for: .touchUpInside)
        addSubview(backButton)
    }
    
    @objc func exit(_ sender: UIButton) {
        if let vc = viewContainingController() as? SendInvitesController {
            vc.dismiss(animated: true, completion: nil)
        }
    }
}

class SendInviteCell: UITableViewCell {
    
    var number: String = ""
    
    var profilePic: UIImageView!
    var nameLabel: UILabel!
    var numberLabel: UILabel!
    var inviteButton: UIButton!
    
    func setUp(contact: CNContact, status: InviteStatus) {
        
        self.contentView.isUserInteractionEnabled = false
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        let rawNumber = contact.phoneNumbers.first?.value
        number = rawNumber?.stringValue ?? ""
        
        if profilePic != nil { profilePic.image = UIImage() }
        profilePic = UIImageView(frame: CGRect(x: 14, y: 8.5, width: 44, height: 44))
        profilePic.layer.cornerRadius = profilePic.bounds.width/2
        profilePic.clipsToBounds = true
        profilePic.contentMode = .scaleAspectFill
        profilePic.image = UIImage(data: contact.imageData ?? Data()) ?? UIImage(named: "BlankContact")
        addSubview(profilePic)
        
        let contactName = contact.givenName + " " + contact.familyName

        
        if nameLabel != nil { nameLabel.text = "" }
        nameLabel = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: 14.5, width: UIScreen.main.bounds.width - 186, height: 15))
        nameLabel.textAlignment = .left
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.text = contactName
        nameLabel.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        nameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13.5)
        addSubview(nameLabel)
        
        if numberLabel != nil { numberLabel.text = "" }
        numberLabel = UILabel(frame: CGRect(x: profilePic.frame.maxX + 9, y: nameLabel.frame.maxY + 1, width: 150, height: 15))
        numberLabel.text = number
        numberLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        numberLabel.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        addSubview(numberLabel)
        
        if inviteButton != nil { inviteButton.setImage(UIImage(), for: .normal) }
        inviteButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 125, y: 8, width: 104, height: 42))
        inviteButton.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        inviteButton.imageView?.contentMode = .scaleAspectFit
        
        switch status {
        
        case .invited:
            inviteButton.setImage(UIImage(named: "InvitedContact"), for: .normal)
            
        case .joined:
            inviteButton.setImage(UIImage(named: "JoinedContact"), for: .normal)
            
        default:
            inviteButton.setImage(UIImage(named: "InviteContactButton"), for: .normal)
            inviteButton.addTarget(self, action: #selector(inviteFriend(_:)), for: .touchUpInside)
        }

        addSubview(inviteButton)
    }
    
    @objc func inviteFriend(_ sender: UIButton) {
        if let vc = viewContainingController() as? SendInvitesController {
            vc.sendInvite(number: number)
        }
    }
}


