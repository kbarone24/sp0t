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

    var sectionTitles: [String] = []
    var numbers: [String] = []
    var sentInvites: [String] = []
    var pendingNumber = "" /// temporary variable used while messages controller is presented
    
    var rawContacts: [CNContact] = []
    var contacts: [(contact: CNContact, status: InviteStatus)] = []
    var queryContacts: [(contact: CNContact, status: InviteStatus)] = []
    
    var searchBar: UISearchBar!
    var searchBarContainer: UIView!
    var cancelButton: UIButton!
    var resultsTable: UITableView!
    
    var tableView: UITableView!
    var loadingIndicator: CustomActivityIndicator!
        
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        
        view.backgroundColor = .white
        
        self.title = "Invite Friends"
        navigationItem.backButtonTitle = ""

        navigationController!.navigationBar.barTintColor = UIColor.white
        navigationController!.navigationBar.isTranslucent = false
        navigationController!.navigationBar.barStyle = .black
        navigationController!.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white

        navigationController!.navigationBar.titleTextAttributes = [
                .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
                .font: UIFont(name: "SFCompactText-Heavy", size: 20)!
        ]
        
        let backButton = UIBarButtonItem(image: UIImage(named: "BackArrow"), style: .plain, target: self, action: #selector(cancelTap(_:)))
        navigationItem.setLeftBarButton(backButton, animated: false)
        self.navigationItem.leftBarButtonItem?.tintColor = nil
                
        
        searchBarContainer = UIView {
            $0.backgroundColor = nil
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        searchBarContainer.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(20)
            $0.width.equalToSuperview()
            $0.height.equalTo(50)
        }
        
        searchBar = UISearchBar {
            $0.searchBarStyle = .default
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.barTintColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            $0.searchTextField.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            $0.searchTextField.leftView?.tintColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.delegate = self
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.placeholder = "Search users"
            $0.searchTextField.font = UIFont(name: "SFCompactText-Medium", size: 15)
            $0.clipsToBounds = true
            $0.layer.masksToBounds = true
            $0.searchTextField.layer.masksToBounds = true
            $0.searchTextField.clipsToBounds = true
            $0.layer.cornerRadius = 3
            $0.searchTextField.layer.cornerRadius = 3
            $0.backgroundImage = UIImage()
            $0.translatesAutoresizingMaskIntoConstraints = false
            searchBarContainer.addSubview($0)
        }
        searchBar.snp.makeConstraints{
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.top.equalToSuperview()
            $0.height.equalTo(36)
        }
        
        cancelButton = UIButton{
            $0.setTitle("Cancel", for: .normal)
            $0.setTitleColor(UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
            $0.titleLabel?.textAlignment = .center
            $0.titleEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
            $0.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
            $0.isHidden = true
            searchBarContainer.addSubview($0)
        }
        
        cancelButton.snp.makeConstraints{
            $0.trailing.equalToSuperview().offset(-16)
        }
        
        
        tableView = UITableView {
            $0.dataSource = self
            $0.delegate = self
            $0.isScrollEnabled = true
            $0.backgroundColor = .white
            $0.separatorStyle = .none
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
            $0.allowsSelection = false
            $0.isHidden = false
            $0.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
            $0.tag = 0
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        tableView.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(searchBarContainer.snp.bottom)
            $0.width.equalToSuperview()
            $0.height.equalTo(UIScreen.main.bounds.height - searchBarContainer.frame.maxY)
        }
        
        resultsTable = UITableView {
            $0.dataSource = self
            $0.delegate = self
            $0.isScrollEnabled = false
            $0.backgroundColor = .white
            $0.separatorStyle = .none
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
            $0.allowsSelection = false
            $0.isHidden = true
            $0.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
            $0.keyboardDismissMode = .onDrag

            $0.tag = 1
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        resultsTable.snp.makeConstraints{
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(searchBarContainer.snp.bottom)
            $0.width.equalToSuperview()
            $0.height.equalTo(UIScreen.main.bounds.height - searchBarContainer.frame.maxY)
        }
        
        
        loadingIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 90, width: UIScreen.main.bounds.width, height: 30))
        loadingIndicator.isHidden = true
        view.addSubview(loadingIndicator)
        
        loadingIndicator.snp.makeConstraints{
            $0.top.equalTo(tableView.snp.bottom).offset(50)
        }

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
    
    @objc func cancelTap(_ sender: UIButton){
        navigationController!.popViewController(animated: true)
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
        for invite in UserDataModel.shared.userInfo.sentInvites {
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
            if status == .none && sentInvites.contains(number.formatNumber()) {
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
        return tableView.tag == 0 ? sectionTitles.map({$0}) : []
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableView.tag == 0 ? sectionTitles.count : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if tableView.tag == 1 { return min(queryContacts.count, 10) }
        
        let head = sectionTitles[section]
        let firstIndex = contacts.firstIndex(where: {$0.contact.familyName.isEmpty ? $0.contact.givenName.prefix(1) == head : $0.contact.familyName.prefix(1) == head})
        let finalIndex = contacts.lastIndex(where: {$0.contact.familyName.isEmpty ? $0.contact.givenName.prefix(1) == head : $0.contact.familyName.prefix(1) == head})
        return Int(finalIndex! - firstIndex!) + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as? ContactCell else { return UITableViewCell() }
        
        if tableView.tag == 1 { let contact = queryContacts[indexPath.row]; cell.set(contact: nil, inviteContact: contact.0, friend: .none, invited: contact.1); return cell }
        
        let head = sectionTitles[indexPath.section]
        /// get first contact starting with this section letter and count from there
        let firstIndex = contacts.firstIndex(where: {$0.contact.familyName.isEmpty ? $0.contact.givenName.prefix(1) == head : $0.contact.familyName.prefix(1) == head})!
        let contact = contacts[firstIndex + indexPath.row]
        cell.set(contact: nil, inviteContact: contact.0, friend: .none, invited: contact.1)
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        /// set header text color 
        (view as! UITableViewHeaderFooterView).contentView.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
    }
        
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableView.tag == 0 ? sectionTitles[section] : ""
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

extension SendInvitesController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        /// clear old search results if search bar is empty
        if searchBar.text == "" { DispatchQueue.main.async { self.resultsTable.reloadData() } }

        cancelButton.alpha = 0.0
        cancelButton.isHidden = false
        resultsTable.alpha = 0.0
        resultsTable.isHidden = false
        
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.alpha = 1.0
            self.resultsTable.alpha = 1.0
            searchBar.snp.remakeConstraints{
                $0.leading.equalToSuperview().offset(16)
                $0.trailing.equalToSuperview().offset(-60)
                $0.top.equalToSuperview()
                $0.height.equalTo(36)
            }
            self.view.layoutIfNeeded()
        }
    }
        
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        /// dismiss here if user swiped down to exit with empty search bar
        if searchBar.text == "" { dismissKeyboard() }
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.isHidden = true
            searchBar.snp.updateConstraints{
                $0.trailing.equalToSuperview().offset(-16)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    func dismissKeyboard() {
        
        searchBar.text = ""
        queryContacts.removeAll()

        UIView.animate(withDuration: 0.1) {
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: self.searchBar.frame.minY, width: UIScreen.main.bounds.width - 28, height: self.searchBar.frame.height)
            self.cancelButton.alpha = 0.0
            self.resultsTable.alpha = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.cancelButton.isHidden = true
            self.resultsTable.isHidden = true
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        queryContacts.removeAll()
        /// show no contacts when search bar is empty rather than all contacts
        if searchBar.text == "" { DispatchQueue.main.async { self.resultsTable.reloadData() }; return }
        
        let nameList = contacts.map({$0.contact.givenName + " " + $0.contact.familyName})
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
                return dataString.range(of: searchText, options: .caseInsensitive) != nil
            })
            
            for name in filteredNames {
                if let friend = self.contacts.first(where: {$0.contact.givenName + " " + $0.contact.familyName == name} ) { self.queryContacts.append(friend) }
            }
            
            DispatchQueue.main.async { self.resultsTable.reloadData() }
        }
    }
        
    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.resignFirstResponder()
        dismissKeyboard()
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
            
            if let i = queryContacts.firstIndex(where: {$0.contact.phoneNumbers.first?.value.stringValue ?? "" == pendingNumber}) {
                queryContacts[i].status = .invited
            }

            let formattedNumber = pendingNumber.formatNumber()
        /// update header
            UserDataModel.shared.userInfo.sentInvites.append(formattedNumber)
            
        /// update local sentInvites
            sentInvites.append(formattedNumber)
        
        /// send noti to find friends controller
            let notificationName = Notification.Name("SentInvite")
            NotificationCenter.default.post(name: notificationName, object: nil, userInfo: nil)

        /// upadte database
            self.db.collection("users").document(uid).updateData(["sentInvites": FieldValue.arrayUnion([formattedNumber])])
            DispatchQueue.main.async { self.tableView.reloadData(); self.resultsTable.reloadData() }
            
        default:
            print("")
        }
        
        pendingNumber = ""
        controller.dismiss(animated: true, completion: nil)
    }

    func sendInvite(number: String) {
                
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
