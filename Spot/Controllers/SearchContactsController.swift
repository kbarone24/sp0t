//
//  SearchContactsViewController.swift
//  Spot
//
//  Created by kbarone on 10/9/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Contacts
import CoreLocation
import Firebase
import FirebaseUI
import Foundation
import Mixpanel
import UIKit

class SearchContactsController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let db: Firestore! = Firestore.firestore()
    var uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"

    lazy var contacts: [UserProfile] = []
    lazy var numbers: [String] = []

    var dataFetched = false
    var sentFromTutorial = false

    var noContactsLabel: UILabel!

    var emptyState: UIView!
    var tableView: UITableView!
    var sendInvitesView: UIView!
    var activityIndicatorView: CustomActivityIndicator!

    override func viewDidLoad() {

        super.viewDidLoad()
        Mixpanel.mainInstance().track(event: "SearchContactsOpen")

        view.backgroundColor = .white

        self.title = "Add Contacts"
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

        let cancelButton = UIBarButtonItem(image: UIImage(named: "BackArrow"), style: .plain, target: self, action: #selector(cancelTap(_:)))
        navigationItem.setLeftBarButton(cancelButton, animated: false)
        self.navigationItem.leftBarButtonItem?.tintColor = nil

        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isScrollEnabled = true
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
        tableView.register(ContactHeader.self, forHeaderFooterViewReuseIdentifier: "ContactHeader")
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 100, right: 0)
        tableView.tag = 0
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        tableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview()
            $0.width.equalToSuperview()
            $0.height.equalTo(UIScreen.main.bounds.height)
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

    @objc func presentSendInvites(_ sender: UITapGestureRecognizer) {
        let sendInvitesVC = SendInvitesController()
        navigationController!.pushViewController(sendInvitesVC, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return dataFetched ? 20 : 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataFetched ? contacts.count : 0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ContactHeader") as? ContactHeader {
            header.setUp(contactsCount: contacts.count)
            return header
        } else {
            return UITableViewHeaderFooterView()

        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactCell

        cell.backgroundColor = .black

        if self.contacts.isEmpty {
            return cell
        }

        cell.set(contact: self.contacts[indexPath.row], inviteContact: nil, friend: self.contacts[indexPath.row].friend! ? .friends : self.contacts[indexPath.row].pending! ? .pending : .none, invited: .none)

        return cell
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(false)
    }

    @objc func cancelTap(_ sender: UIButton) {
        navigationController!.popViewController(animated: true)
    }

    func checkAuth() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .denied, .notDetermined:
            CNContactStore().requestAccess(for: CNEntityType.contacts) { [weak self] (access, _) in
                guard let self = self else { return }

                if access {
                    Mixpanel.mainInstance().track(event: "ContactsAuthEnabled")
                    self.getContacts()
                } else {
                    Mixpanel.mainInstance().track(event: "ContactsAuthDisabled")
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
                                self.navigationController?.popViewController(animated: true)
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
            self.activityIndicatorView = CustomActivityIndicator(frame: CGRect(x: 0, y: UIScreen.main.bounds.minY + 40, width: UIScreen.main.bounds.width, height: 30))
            self.activityIndicatorView.isHidden = true
            self.tableView.addSubview(self.activityIndicatorView)
        }

        // get all of a users contact's phone numbers
        let store = CNContactStore()

        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        var message = ""

        do {

            try store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) {
                (contact, _) -> Void in

                if !contact.phoneNumbers.isEmpty {

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
            getContactInfo()

        } else {
            let alert = UIAlertController(title: "Error", message: "There was an issue accessing your contacts.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)

            return
        }
    }

    func getContactInfo() {

        // loop through all users in DB to see if users contact phone numbers contains phone number from DB
        var localContacts: [UserProfile] = []

        DispatchQueue.global().async {

            self.db.collection("users").getDocuments { [weak self]
                (snap, err) in

                guard let self = self else { return }
                var index = 0

                for document in snap!.documents {

                    do {

                        let info = try document.data(as: UserProfile.self)
                        guard var userInfo = info else {
                            index += 1; if index == snap!.documents.count && self.contacts.isEmpty { self.setUpEmptyState() }; continue
                        }

                        userInfo.id = document.documentID
                        if userInfo.id == self.uid { index += 1; if index == snap!.documents.count && self.contacts.isEmpty { self.setUpEmptyState() }; continue }

                        var number = userInfo.phone ?? ""
                        number = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        number = String(number.suffix(10))
                        userInfo.phone = number

                        if self.numbers.contains(number) {

                            let id = document.documentID
                            userInfo.id = id

                            let notiRef = self.db.collection("users").document(id).collection("notifications")
                            let friendRequestQuery = notiRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending").whereField("senderID", isEqualTo: self.uid)

                            /// check if theres already a friend request pending to this contact
                            friendRequestQuery.getDocuments { [weak self] (fSnap, _) in

                                guard let self = self else { return }

                                userInfo.friend = UserDataModel.shared.userInfo.friendIDs.contains(id)
                                userInfo.pending = !userInfo.friend! && ((fSnap?.documents.count ?? 0) > 0 || UserDataModel.shared.userInfo.pendingFriendRequests.contains(id))
                                localContacts.append(userInfo)

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

    func addContactsToTable(contacts: [UserProfile]) {
        for contact in contacts {

            self.contacts.append(contact)

            if self.contacts.count == contacts.count {
                DispatchQueue.main.async {
                    self.contacts.sort(by: { $1.username > $0.username })
                    self.contacts.sort(by: { !$0.pending! && $1.pending! })
                    self.contacts.sort(by: { !$0.friend! && $1.friend! })
                    self.dataFetched = true

                    if self.activityIndicatorView.isAnimating() {self.activityIndicatorView.stopAnimating()}
                    self.tableView.reloadData()
                }
            }
        }
    }

    func setUpEmptyState() {

        self.activityIndicatorView.stopAnimating()

        sendInvitesView = SendInvitesView {
            $0.setUp(sentInvites: UserDataModel.shared.userInfo.sentInvites.count)
            $0.isUserInteractionEnabled = true
            $0.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(presentSendInvites(_:))))
            $0.isHidden = false
            view.addSubview($0)
        }

         noContactsLabel = UILabel {
            $0.text = "No contacts on sp0t yet. Invite friends to join"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.isHidden = false
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
         }

        noContactsLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview().offset(16)
        }

        sendInvitesView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(60)
            $0.top.equalTo(noContactsLabel.snp.bottom).offset(16)
        }

    }

    @objc func inviteFriendsTap(_ sender: UIButton) {
        let sendInvitesVC = SendInvitesController()
        navigationController!.pushViewController(sendInvitesVC, animated: true)
    }
}

class ContactHeader: UITableViewHeaderFooterView {

    var titleLabel: UILabel!

    func setUp(contactsCount: Int) {

        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView

        resetView()

        titleLabel = UILabel {
            $0.text = "You have " + String(contactsCount) + " contacts on sp0t"
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            self.addSubview($0)
        }

        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
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
    }
}
