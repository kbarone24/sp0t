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
import Mixpanel
import UIKit

class SearchContactsController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .white
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 80, right: 0)
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 70
        tableView.register(SearchContactsCell.self, forCellReuseIdentifier: "ContactsCell")
        tableView.register(SearchContactsHeader.self, forHeaderFooterViewReuseIdentifier: "Header")
        return tableView
    }()
    private lazy var actionButton = ContactsActionButton()
    private lazy var activityIndicator = CustomActivityIndicator()
    private lazy var bottomMask = UIView()

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Whoa... you’re the first of your friends on sp0t  :O"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isHidden = true
        return label
    }()

    private lazy var contacts: [UserProfile] = []
    private lazy var contactsFetched = false
    private lazy var emptyState = false {
        didSet {
            emptyStateLabel.isHidden = !emptyState
        }
    }
        override func viewDidLoad() {
        super.viewDidLoad()
        setUpNavBar()
        addTableView()
        DispatchQueue.global().async { self.fetchContacts() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addBottomMask()
    }

    private func setUpNavBar() {
        edgesForExtendedLayout = []
        navigationController?.navigationBar.addWhiteBackground()
        let logo = UIImage(named: "OnboardingLogo")
        let imageView = UIImageView(image: logo)
        imageView.snp.makeConstraints {
            $0.height.equalTo(32.9)
            $0.width.equalTo(78)
        }
        navigationItem.titleView = imageView
        navigationItem.setHidesBackButton(true, animated: false)
    }

    private func addTableView() {
        view.backgroundColor = .white

        actionButton.addTarget(self, action: #selector(actionTap), for: .touchUpInside)
        view.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalTo(-48)
            $0.height.equalTo(51)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(10)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(actionButton.snp.top)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(30)
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(30)
        }

        tableView.addSubview(emptyStateLabel)
        emptyStateLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(90)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-60)
        }
    }

    private func fetchContacts() {
        if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
            emptyState = true
            self.reloadViews(row: nil)
            return
        }

        DispatchQueue.main.async { self.activityIndicator.startAnimating() }

        let contactsFetcher = ContactsFetcher()
        contactsFetcher.runFetch { contacts, err in
            if err != nil { print("err", err as Any) }
            for contact in contacts where !self.contacts.contains(contact) {
                self.contacts.append(contact)
            }
            self.contacts.sort(by: { $0.username < $1.username })
            self.contactsFetched = true
            self.emptyState = self.contacts.isEmpty
            self.reloadViews(row: nil)
        }
    }

    private func reloadViews(row: Int?) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.actionButton.setUp(emptyState: self.emptyState, selectedCount: self.contacts.filter({ $0.selected }).count)

            if row == nil {
                self.tableView.reloadData()
            } else if let cell = self.tableView.cellForRow(at: IndexPath(row: row ?? 0, section: 0)) as? SearchContactsCell {
                cell.setBubbleImage(selected: self.contacts[row ?? 0].selected)
            }
        }
    }

    private func addBottomMask() {
        if bottomMask.superview != nil { return }
        bottomMask.isUserInteractionEnabled = false
        view.addSubview(bottomMask)
        view.bringSubviewToFront(actionButton)
        let layer = CAGradientLayer()
        layer.frame = CGRect(x: 0, y: actionButton.frame.minY - 120, width: UIScreen.main.bounds.width, height: 120)
        layer.colors = [
            UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor,
            UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.locations = [0, 1]
        bottomMask.layer.addSublayer(layer)
    }

    @objc func actionTap() {
        let selectedContactIDs = (contacts.filter({ $0.selected }).map({ $0.id ?? "" }))
        Mixpanel.mainInstance().track(event: "SearchContactsAddTap", properties: ["count": selectedContactIDs.count])
        sendFriendRequests(selectedContactIDs: selectedContactIDs)
        animateToMap()
    }

    func sendFriendRequests(selectedContactIDs: [String]) {
        do {
            let friendService = try ServiceContainer.shared.service(for: \.friendsService)
            selectedContactIDs.forEach {
                friendService.addFriend(receiverID: $0, completion: nil)
            }
        } catch {
            return
        }
    }

    func animateToMap() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        let homeScreenController = HomeScreenContainerController()
        navigationController?.popToRootViewController(animated: false)
        window.rootViewController = homeScreenController
        window.makeKeyAndVisible()
    }
}

extension SearchContactsController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "Header") as? SearchContactsHeader {
            header.setLabel(count: contacts.count)
            return header
        }
        return UITableViewHeaderFooterView()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return emptyState || !contactsFetched ? 0 : 30
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ContactsCell", for: indexPath) as? SearchContactsCell {
            cell.setUp(user: contacts[indexPath.row])
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contactsFetched ? contacts.count : 0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        contacts[indexPath.row].selected.toggle()
        DispatchQueue.main.async {
            HapticGenerator.shared.play(.light)
            self.reloadViews(row: indexPath.row)
        }
    }
}

class ContactsActionButton: UIButton {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Bold", size: 16)
        return label
    }()
    private lazy var emptyState = true
    private lazy var selectedCount = 0 {
        didSet {
            setLabelText()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
        layer.cornerRadius = 9

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }

        setLabelText()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(emptyState: Bool, selectedCount: Int) {
        self.emptyState = emptyState
        self.selectedCount = selectedCount
    }

    func setLabelText() {
        let countString = String(selectedCount)
        label.text = emptyState ? "Done" : "Add \(countString) Friends"
        label.attributedText = label.text?.getAttributedText(boldString: countString, font: label.font) ?? NSAttributedString(string: "")
    }
}
