//
//  ContactsFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/28/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Contacts
import Firebase

class ContactsFetcher {
    private lazy var numbers: [String] = []
    private lazy var allUsers: [UserProfile] = []
    private lazy var contacts: [UserProfile] = []
    private lazy var pendingFriendIDs: [String] = []
    private var errorMessage: String?

    let dispatch = DispatchGroup()

    func runFetch(completion: @escaping (_ contacts: [UserProfile], _ err: String?) -> Void) {
        dispatch.enter()
        dispatch.enter()
        dispatch.enter()

        DispatchQueue.global().async {
            self.getUserContacts()
            self.getAllUsers()
            self.getPendingFriends()
        }

        dispatch.notify(queue: .main) {
            // match contacts with numbers -> only include non-friends/pending
            for number in self.numbers {
                if let user = self.allUsers.first(where: { $0.phone == number }),
                   !UserDataModel.shared.userInfo.friendIDs.contains(user.id ?? "") &&
                    !self.pendingFriendIDs.contains(user.id ?? "") &&
                    !(UserDataModel.shared.userInfo.hiddenUsers ?? []).contains(user.id ?? "") {
                    self.contacts.append(user)
                }
            }
            completion(self.contacts, self.errorMessage)
        }
    }
    
    func getUserContacts() {
        let store = CNContactStore()
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        do {
            try store.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { (contact, _) -> Void in
                if !contact.phoneNumbers.isEmpty {
                    for phoneNumber in contact.phoneNumbers {
                        let phoneNumberStruct = phoneNumber.value as CNPhoneNumber
                        let phoneNumberString = phoneNumberStruct.stringValue
                        var number = phoneNumberString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

                        if !number.isEmpty {
                            // match based on last 10 digits to eliminate country codes and formatting from matching
                            number = String(number.suffix(10))
                            self.numbers.append(number)
                        }
                    }
                }
            }
            dispatch.leave()
        } catch {
            errorMessage = "Unable to fetch contacts"
        }
    }

    func getAllUsers() {
        // loop through all users in DB to see if users contact phone numbers contains phone number from DB
        let db = Firestore.firestore()
        db.collection("users").getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let snap = snap else { return }
            for document in snap.documents {
                do {
                    let unwrappedInfo = try document.data(as: UserProfile.self)
                    guard var userInfo = unwrappedInfo else { continue }
                    if userInfo.id == UserDataModel.shared.uid { continue }

                    var number = userInfo.phone ?? ""
                    number = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    number = String(number.suffix(10))
                    userInfo.phone = number
                    self.allUsers.append(userInfo)

                } catch {
                    continue
                }
            }
            self.dispatch.leave()
        }
    }

    func getPendingFriends() {
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
}
