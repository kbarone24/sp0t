//
//  ContactsFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/28/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import Contacts
import ContactsUI
import Firebase
import FirebaseFirestore

class ContactsFetcher {
    public lazy var contactInfos: [ContactInfo] = []
    public var contactsAuth: CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }

    private lazy var allUsers: [UserProfile] = []
    private lazy var pendingFriendIDs: [String] = []
    private var errorMessage: String?

    let dispatch = DispatchGroup()
    static let shared = ContactsFetcher()

    private lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    func runFetch(completion: @escaping (_ contacts: [UserProfile], _ err: String?) -> Void) {
        let getContacts = contactInfos.isEmpty
        allUsers.removeAll()
        dispatch.enter()
        dispatch.enter()
        if getContacts { dispatch.enter() }

        DispatchQueue.global().async {
            self.getAllUsers()
            self.getPendingFriends()
            if getContacts { self.getUserContacts() }
        }

        var contacts: [UserProfile] = []
        dispatch.notify(queue: .main) {
            // match contacts with numbers -> only include non-friends/pending
            for info in self.contactInfos {
                if var user = self.allUsers.first(where: { $0.phone == info.formattedNumber }),
                   !UserDataModel.shared.userInfo.friendIDs.contains(user.id ?? "") &&
                    !self.pendingFriendIDs.contains(user.id ?? "") &&
                    !(UserDataModel.shared.userInfo.hiddenUsers ?? []).contains(user.id ?? "") {
                    user.contactInfo = info
                    contacts.append(user)
                }
            }
            // upload / update existing user contacts in the database
            self.userService?.uploadContactsToDB(contacts: self.contactInfos)
            completion(contacts, self.errorMessage)
        }
    }

    func getContacts() {
        dispatch.enter()
        DispatchQueue.global().async {
            self.getUserContacts()
        }
    }
    
    private func getUserContacts() {
        let store = CNContactStore()
        let keys = [CNContactPhoneNumbersKey, CNContactFamilyNameKey, CNContactGivenNameKey, CNContactThumbnailImageDataKey] as [CNKeyDescriptor]
        do {
            try store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { (contact, _) -> Void in
                if !contact.phoneNumbers.isEmpty {
                    for phoneNumber in contact.phoneNumbers {
                        let phoneNumberStruct = phoneNumber.value as CNPhoneNumber
                        let phoneNumberString = phoneNumberStruct.stringValue
                        var formattedNumber = phoneNumberString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

                        if !formattedNumber.isEmpty {
                            // match based on last 10 digits to eliminate country codes and formatting from matching
                            formattedNumber = String(formattedNumber.suffix(10))
                            self.contactInfos.append(
                                ContactInfo(
                                    realNumber: phoneNumberString,
                                    formattedNumber: formattedNumber,
                                    firstName: contact.givenName,
                                    lastName: contact.familyName,
                                    thumbnailData: contact.thumbnailImageData,
                                    pending: false
                                )
                            )
                        }
                    }
                }
            }
            self.sortContactInfos()
            dispatch.leave()
        } catch {
            errorMessage = "Unable to fetch contacts"
        }
    }

    private func getAllUsers() {
        // loop through all users in DB to see if users contact phone numbers contains phone number from DB
        let db = Firestore.firestore()
        db.collection("users").getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let snap = snap else { return }
            for document in snap.documents {
                do {
                    let unwrappedInfo = try? document.data(as: UserProfile.self)
                    guard var userInfo = unwrappedInfo else { continue }
                    if userInfo.id == UserDataModel.shared.uid { continue }

                    var number = userInfo.phone ?? ""
                    number = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    number = String(number.suffix(10))
                    userInfo.phone = number
                    self.allUsers.append(userInfo)

                }
            }
            self.dispatch.leave()
        }
    }

    private func getPendingFriends() {
        // get pending requests to add ppl user has sent requests to + fetch for requests they've received
        let db = Firestore.firestore()
        let uid = UserDataModel.shared.uid
        let notiRef = db.collection("users").document(uid).collection("notifications")
        let friendRequestQuery = notiRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending").whereField("senderID", isEqualTo: UserDataModel.shared.uid)

        pendingFriendIDs.append(contentsOf: UserDataModel.shared.userInfo.pendingFriendRequests)
        friendRequestQuery.getDocuments { [weak self] snap, _ in
            guard let self = self else { return }
            guard let snap = snap else { self.dispatch.leave(); return }
            for doc in snap.documents {
                if let senderID = doc.get("senderID") as? String {
                    self.pendingFriendIDs.append(senderID)
                }
            }
            self.dispatch.leave()
        }
    }

    private func sortContactInfos() {
        contactInfos = contactInfos.sorted { c1, c2 in
            if (c1.thumbnailData == nil) != (c2.thumbnailData == nil) {
                return c1.thumbnailData != nil && c2.thumbnailData == nil
            }
            if c1.fullName.containsEmoji != c2.fullName.containsEmoji {
                return c1.fullName.containsEmoji && !c2.fullName.containsEmoji
            }
            return c1.fullName < c2.fullName
        }
    }
}
