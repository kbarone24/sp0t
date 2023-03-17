//
//  CommentsController.swift
//  Spot
//
//  Created by kbarone on 6/25/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth
import IQKeyboardManagerSwift
import Mixpanel
import UIKit
import SDWebImage

protocol CommentsDelegate: AnyObject {
    func openProfileFromComments(user: UserProfile)
}

final class CommentsController: UIViewController {
    var commentList: [MapComment] {
        didSet {
            titleView.commentCount = max(0, commentList.count - 1)
        }
    }
    var post: MapPost
    weak var delegate: CommentsDelegate?
    lazy var taggedUserProfiles: [UserProfile] = []

    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db = Firestore.firestore()
    let emptyTextString = "Comment..."

    private lazy var titleView = CommentsTitleView()

    private(set) lazy var tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        view.separatorStyle = .none
        view.showsVerticalScrollIndicator = false
        view.allowsSelection = false
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        view.estimatedRowHeight = 50
        view.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
        return view
    }()

    private(set) lazy var footerOffset: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        return view
    }()
    private(set) lazy var footerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        return view
    }()
    private(set) lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    private(set) lazy var postButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "PostCommentButton"), for: .normal)
        button.addTarget(self, action: #selector(postComment(_:)), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    private(set) lazy var textView: UITextView = {
        let textView = UITextView()
        textView.delegate = self
        textView.backgroundColor = UIColor(red: 0.937, green: 0.937, blue: 0.937, alpha: 1)
        textView.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        textView.font = UIFont(name: "SFCompactText-Semibold", size: 17)
        textView.alpha = 0.65
        textView.text = emptyTextString
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 60)
        textView.isScrollEnabled = false
        textView.returnKeyType = .send
        textView.textContainer.maximumNumberOfLines = 6
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.delegate = self
        textView.layer.cornerRadius = 11
        return textView
    }()

    lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()
    
    private lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()
    
    lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
    private(set) lazy var tagFriendsView = TagFriendsView()
    
    var cancelOnDismiss = false
    var firstOpen = true

    init(commentsList: [MapComment], post: MapPost) {
        self.commentList = commentsList
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        setUpView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disableKeyboardMethods()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enableKeyboardMethods()

        if firstOpen {
            DispatchQueue.main.async { self.textView.becomeFirstResponder() }
            firstOpen = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CommentsOpen")
    }

    func enableKeyboardMethods() {
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.enable = false /// disable for textView sticking to keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func setUpView() {
        view.addSubview(titleView)
        titleView.commentCount = max(0, commentList.count - 1)
        titleView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(65)
        }

        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.snp.makeConstraints {
            $0.top.equalTo(titleView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        panGesture.isEnabled = false
        tableView.addGestureRecognizer(panGesture)

        view.addSubview(footerOffset)
        footerOffset.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(40)
        }
        /// footerView isn't a true footer but the input accessory view used to fix text to the keyboard
        view.addSubview(footerView)
        footerView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footerOffset.snp.top)
        }

        footerView.addSubview(avatarImage)
        if UserDataModel.shared.userInfo.avatarURL ?? "" != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: UserDataModel.shared.userInfo.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.width.equalTo(36)
            $0.height.equalTo(40.5)
            $0.bottom.equalToSuperview().inset(15)
        }

        footerView.addSubview(textView)
        textView.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(10)
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalToSuperview().inset(12)
        }

        footerView.addSubview(postButton)
        postButton.snp.makeConstraints {
            $0.trailing.equalTo(textView.snp.trailing).inset(7)
            $0.width.height.equalTo(32)
            $0.bottom.equalTo(textView.snp.bottom).inset(6)
        }
    }
}

extension CommentsController: TagFriendsDelegate {
    func finishPassing(selectedUser: UserProfile) {
        textView.addUsernameAtCursor(username: selectedUser.username)
        removeTagTable()
    }
}
