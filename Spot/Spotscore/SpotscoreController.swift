//
//  SpotscoreController.swift
//  Spot
//
//  Created by Kenny Barone on 4/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol SpotscoreDelegate: AnyObject {
    func openEditAvatar(family: AvatarFamily?)
}

class SpotscoreController: UIViewController {
    private(set) lazy var titleView = SpotscoreTitleView(score: spotscore)

    private(set) lazy var tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
        view.showsVerticalScrollIndicator = false
        view.register(SpotscoreCell.self, forCellReuseIdentifier: SpotscoreCell.reuseID)
        view.register(EmptySpotscoreCell.self, forCellReuseIdentifier: EmptySpotscoreCell.reuseID)
        return view
    }()

    private(set) lazy var bottomMaskView = UIView()
    private(set) lazy var editAvatarButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.backgroundColor = UIColor(red: 0.227, green: 0.725, blue: 1, alpha: 1)
        let attString = NSMutableAttributedString(string: "CHANGE AVATAR", attributes: [NSAttributedString.Key.kern: 0.91])
        button.setAttributedTitle(attString, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "Gameplay", size: 13)
        button.addTarget(self, action: #selector(editAvatarTap), for: .touchUpInside)
        return button
    }()

    let avatars = AvatarGenerator.shared.getUnlockableAvatars()
    var spotscore = 0
    weak var delegate: SpotscoreDelegate?

    init(spotscore: Int) {
        super.init(nibName: nil, bundle: nil)
        self.spotscore = spotscore
        view.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(titleView)
        titleView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(6)
            $0.height.equalTo(66)
        }

        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(titleView.snp.bottom)
        }

        view.addSubview(bottomMaskView)
        bottomMaskView.isUserInteractionEnabled = false
        bottomMaskView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(240)
        }

        view.addSubview(editAvatarButton)
        editAvatarButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalTo(-51)
            $0.height.equalTo(51)
        }

        view.layoutIfNeeded()
        addGradients()

    //    scrollToSelectedRow()
    }

    private func addGradients() {
        let bottomMask = CAGradientLayer()
        bottomMask.frame = bottomMaskView.bounds
        bottomMask.colors = [
            UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 0.0).cgColor,
            UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1).cgColor,
            UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1).cgColor,
        ]
        bottomMask.locations = [0, 0.6, 1]
        bottomMask.startPoint = CGPoint(x: 0.5, y: 0)
        bottomMask.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomMaskView.layer.addSublayer(bottomMask)

        let buttonLayer = CAGradientLayer()
        buttonLayer.frame = editAvatarButton.bounds
        buttonLayer.colors = [
          UIColor(red: 0.376, green: 0.925, blue: 1, alpha: 1).cgColor,
          UIColor(red: 0.227, green: 0.725, blue: 1, alpha: 1).cgColor
        ]
        buttonLayer.locations = [0, 1]
        buttonLayer.startPoint = CGPoint(x: 0.5, y: 0)
        buttonLayer.endPoint = CGPoint(x: 0.5, y: 1)
        editAvatarButton.layer.insertSublayer(buttonLayer, at: 0)
    }

    private func scrollToSelectedRow() {
        let selectedRow = min((avatars.lastIndex(where: { $0.isUnlocked }) ?? 0) + 2, avatars.count - 1)
        DispatchQueue.main.async {
            self.tableView.scrollToRow(at: IndexPath(row: selectedRow, section: 0), at: .bottom, animated: false)
        }
    }


    @objc func editAvatarTap() {
        openEditAvatar(family: nil)
    }

    private func openEditAvatar(family: AvatarFamily?) {
        DispatchQueue.main.async {
            self.delegate?.openEditAvatar(family: family)
            self.dismiss(animated: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension SpotscoreController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return avatars.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row > 0, let cell = tableView.dequeueReusableCell(withIdentifier: SpotscoreCell.reuseID) as? SpotscoreCell {
            cell.setUp(avatar: avatars[indexPath.row - 1], dotCount: getDotNumber(index: indexPath.row - 1), maskOpacity: getMaskOpacity(index: indexPath.row - 1))
            return cell
        }
        if let cell = tableView.dequeueReusableCell(withIdentifier: EmptySpotscoreCell.reuseID) as? EmptySpotscoreCell {
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 8
        }
        return 63.5
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let avatar = avatars[safe: indexPath.row - 1], avatar.isUnlocked {
            openEditAvatar(family: avatar.family)
        }
    }

    private func getDotNumber(index: Int) -> Int {
        // 2 dots above current avatar, 4 dots below current avatar
        let previousLevel = avatars[safe: index - 1]?.unlockScore ?? 0
        let currentLevel = avatars[index].unlockScore
        let nextLevel = avatars[safe: index + 1]?.unlockScore ?? 20000

        let previousDifference = Double(spotscore - previousLevel) / Double(currentLevel - previousLevel)
        let previousDots = getDotsFor(difference: previousDifference)

        let nextDifference = Double(spotscore - currentLevel) / Double(nextLevel - currentLevel)
        let nextDots = getDotsFor(difference: nextDifference)

        return max(0, previousDots - 2) + max(0, nextDots - 4)
    }

    private func getDotsFor(difference: Double) -> Int {
        Int(difference / (1 / 6))
    }

    private func getMaskOpacity(index: Int) -> CGFloat {
        let currentLevel = avatars[index].unlockScore
        if spotscore >= currentLevel {
            return 0
        }

        let lastRow = avatars.lastIndex(where: { $0.isUnlocked })
        // increment mask for locked avis from 80% by 4.5% to max of 97%
        let maskAdjustment = min(0.15, CGFloat(index - (lastRow ?? 0)) * 0.0375)
        return 0.8 + maskAdjustment
    }
}
