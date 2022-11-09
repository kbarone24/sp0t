//
//  SearchContactsOverviewController.swift
//  Spot
//
//  Created by Kenny Barone on 11/7/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Contacts
import Mixpanel

class SearchContactsOverviewController: UIViewController {
    private lazy var promptLabel: UILabel = {
        let label = UILabel()
        label.text = "See if you have friends on sp0t already!"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 20)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    private lazy var avatarImage = UIImageView(image: UIImage(named: "AvatarGroupImage"))
    private lazy var searchContactsButton: UIButton = {
        let button = PillButtonWithImage()
        button.setUp(image: UIImage(named: "SearchContactsButtonIcon") ?? UIImage(), str: "Search contacts", cornerRadius: 9)
        button.addTarget(self, action: #selector(searchContactsTap), for: .touchUpInside)
        return button
    }()

    private lazy var skipButton: UIButton = {
        let button = UIButton()
        button.setTitle("Skip", for: .normal)
        button.setTitleColor(UIColor(red: 0.604, green: 0.604, blue: 0.604, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        button.titleEdgeInsets = UIEdgeInsets(top: 2.5, left: 2.5, bottom: 2.5, right: 2.5)
        button.addTarget(self, action: #selector(skipTap), for: .touchUpInside)
        return button
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
    }

    func setUpNavBar() {
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

    func setUpViews() {
        view.backgroundColor = .white
        view.addSubview(promptLabel)
        promptLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(60)
            $0.top.equalTo(140)
        }

        view.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.top.equalTo(promptLabel.snp.bottom).offset(21)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(265)
            $0.height.equalTo(148.75)
        }

        view.addSubview(searchContactsButton)
        searchContactsButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.top.equalTo(avatarImage.snp.bottom).offset(40.25)
            $0.height.equalTo(51)
        }

        view.addSubview(skipButton)
        skipButton.snp.makeConstraints {
            $0.top.equalTo(searchContactsButton.snp.bottom).offset(13.5)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(33)
            $0.height.equalTo(21)
        }
    }

    @objc func skipTap() {
        // present map
        Mixpanel.mainInstance().track(event: "SearchContactsSkipTap")
        DispatchQueue.main.async { self.animateToMap() }
    }

    @objc func searchContactsTap() {
        // ask for contacts access
        CNContactStore().requestAccess(for: CNEntityType.contacts) { [weak self] (access, _) in
            guard let self = self else { return }
            if access {
                Mixpanel.mainInstance().track(event: "SearchContactsAuthEnabled")
                DispatchQueue.main.async { self.presentSearchContacts() }
            } else {
                Mixpanel.mainInstance().track(event: "SearchContactsAuthDisabled")
                DispatchQueue.main.async { self.animateToMap() }
            }
        }
    }

    func animateToMap() {
        let storyboard = UIStoryboard(name: "Map", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "MapVC") as? MapController else { return }
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen

        let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        navigationController?.popToRootViewController(animated: false)
        window?.rootViewController = navController
    }

    func presentSearchContacts() {
        let vc = SearchContactsController()
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
