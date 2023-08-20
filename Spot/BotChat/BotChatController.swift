//
//  BotChatController.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import Combine
import Mixpanel

class BotChatController: UIViewController {
    enum Section: Hashable {
        case main
    }

    enum Item: Hashable {
        case item(chat: BotChatMessage)
    }

    typealias Input = BotChatViewModel.Input
    typealias Output = BotChatViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    let viewModel: BotChatViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .item(chat: let chat):
                let cell = tableView.dequeueReusableCell(withIdentifier: BotChatCell.reuseID, for: indexPath) as? BotChatCell
                cell?.configure(chat: chat)
                return cell
            }
        }
        return dataSource
    }()

    private lazy var footerView = BotChatFooter()

    private lazy var footerOffset: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.979, green: 0.979, blue: 0.979, alpha: 1)
        return view
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UIScreen.main.bounds.height / 2
        tableView.backgroundColor = UIColor(red: 0.979, green: 0.979, blue: 0.979, alpha: 1)
        tableView.contentInset = UIEdgeInsets(top: 15, left: 0, bottom: 20, right: 0)
        tableView.clipsToBounds = true
        tableView.register(BotChatCell.self, forCellReuseIdentifier: BotChatCell.reuseID)
        return tableView
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()
    private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))

    init(viewModel: BotChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.979, green: 0.979, blue: 0.979, alpha: 1)

        view.addSubview(footerOffset)
        footerOffset.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(40)
        }
        /// footerView isn't a true footer but the input accessory view used to fix text to the keyboard
        view.addSubview(footerView)
        footerView.delegate = self
        footerView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footerOffset.snp.top)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footerView.snp.top)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(100)
        }
        activityIndicator.color = .white
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.startAnimating()

        panGesture.isEnabled = false
        tableView.addGestureRecognizer(panGesture)

        let input = Input(
            refresh: refresh
        )

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.activityIndicator.stopAnimating()
                self?.scrollToLastRow(animated: false)
            }
            .store(in: &subscriptions)

        refresh.send(true)

        NotificationCenter.default.addObserver(self, selector: #selector(setAvatarImage), name: Notification.Name(rawValue: "UserProfileLoad"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "BotChatAppeared")
    }

    @objc func setAvatarImage() {
        footerView.avatarImage.image = UserDataModel.shared.userInfo.getAvatarImage()
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        view.animateWithKeyboard(notification: notification) { keyboardFrame in
            self.footerView.snp.removeConstraints()
            self.footerView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        view.animateWithKeyboard(notification: notification) { _ in
            self.footerView.snp.removeConstraints()
            self.footerView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(self.footerOffset.snp.top)
            }
        }
    }

    @objc func pan(_ sender: UIPanGestureRecognizer) {
        if !footerView.textView.isFirstResponder { return }
        let direction = sender.velocity(in: view)
        if abs(direction.y) > 100 { footerView.textView.resignFirstResponder() }
    }
}

extension BotChatController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()

        // set seen for message
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        switch item {
        case .item(chat: let chat):
            guard let chatID = chat.id else { return }
            viewModel.setSeenFor(chatID: chatID)
        }
    }

    func scrollToLastRow(animated: Bool) {
        // scroll to last row (most recent chat) on first fetch and upload
        guard !self.datasource.snapshot().itemIdentifiers.isEmpty else { return }
        self.tableView.scrollToRow(at: IndexPath(row: (self.datasource.snapshot().itemIdentifiers.count) - 1, section: 0), at: .bottom, animated: animated)
    }
}

extension BotChatController: BotFooterDelegate {
    func uploadChat(text: String) {
        viewModel.uploadChat(text: text)
        refresh.send(false)
        scrollToLastRow(animated: true)
    }

    func togglePanGesture(enable: Bool) {
        panGesture.isEnabled = enable
    }
}
