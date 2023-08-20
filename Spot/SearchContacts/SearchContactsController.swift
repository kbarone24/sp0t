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
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 70
        tableView.register(SearchContactsCell.self, forCellReuseIdentifier: "ContactsCell")
        return tableView
    }()
    private lazy var actionButton = ContactsActionButton()
    private lazy var activityIndicator = UIActivityIndicatorView()
    private lazy var bottomMask = UIView()

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "x_x  No contacts yet"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isHidden = true
        return label
    }()

    private lazy var contacts: [UserProfile] = []
    private lazy var contactsFetched = false {
        didSet {
            setContactsCount()
        }
    }
    private lazy var emptyState = false {
        didSet {
            emptyStateLabel.isHidden = !emptyState
        }
    }

    private lazy var titleView = ContactsTitleView()
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()

        Mixpanel.mainInstance().track(event: "SearchContactsOpen")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addTableView()
        checkContactsAuth()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addBottomMask()
    }

    private func setUpNavBar() {
        edgesForExtendedLayout = []
        navigationController?.setUpOpaqueNav(backgroundColor: SpotColors.SpotBlack.color)
        titleView.snp.makeConstraints {
            $0.height.equalTo(40)
            $0.width.equalTo(UIScreen.main.bounds.width)
        }
        navigationItem.titleView = titleView
        navigationItem.setHidesBackButton(true, animated: false)
    }

    private func setContactsCount() {
        titleView.contactsCount = contacts.count
        navigationItem.titleView = titleView
    }

    private func addTableView() {
        view.backgroundColor = UIColor(named: "SpotBlack")

        actionButton.addTarget(self, action: #selector(actionTap), for: .touchUpInside)
        view.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalTo(-48)
            $0.height.equalTo(51)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(actionButton.snp.top)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.isHidden = true
        activityIndicator.snp.makeConstraints {
            $0.top.equalTo(30)
            $0.centerX.equalToSuperview()
            $0.height.width.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)

        tableView.addSubview(emptyStateLabel)
        emptyStateLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(90)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-60)
        }
    }

    private func checkContactsAuth() {
        switch ContactsFetcher.shared.contactsAuth {
        case .notDetermined:
            CNContactStore().requestAccess(for: CNEntityType.contacts) { [weak self] (_, _) in
                guard let self = self else { return }
                self.checkContactsAuth()
            }
        case .denied, .restricted:
            // weren't getting window scene because auth request window was still active
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.animateHome()
            }

        case.authorized:
            Mixpanel.mainInstance().track(event: "ContactsAuthEnabled")
            DispatchQueue.global().async { self.fetchContacts() }

        @unknown default: return
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
            for contact in contacts where !self.contacts.contains(contact) {
                self.contacts.append(contact)
            }

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
            UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).cgColor,
            UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor
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
        animateHome()
    }

    func sendFriendRequests(selectedContactIDs: [String]) {
        do {
            let friendService = try ServiceContainer.shared.service(for: \.friendsService)
            _ = selectedContactIDs.map {
                friendService.addFriend(receiverID: $0, completion: nil)
            }
        } catch {
            return
        }
    }

    func animateHome() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
                    return
                }

            let homeScreenController = HomeScreenController(viewModel: HomeScreenViewModel(serviceContainer: ServiceContainer.shared))
            self.navigationController?.popToRootViewController(animated: false)
            let navigationController = UINavigationController(rootViewController: homeScreenController)
            window.rootViewController = navigationController
            window.makeKeyAndVisible()
        }
    }
}

extension SearchContactsController: UITableViewDataSource, UITableViewDelegate {
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
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 16)
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
