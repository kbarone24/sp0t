//
//  PopOverviewHeader.swift
//  Spot
//
//  Created by Kenny Barone on 8/28/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class PopOverviewHeader: UITableViewHeaderFooterView {
    private lazy var timeLeftLabel: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.UniversCE.fontWith(size: 13)
        return label
    }()

    private lazy var visitorsIcon = UIImageView(image: UIImage(named: "PopVisitorsIcon"))

    private lazy var visitorsCount: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.UniversCE.fontWith(size: 13)
        label.textColor = .white
        return label
    }()

    lazy var newButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setTitle("New", for: .normal)
        return button
    }()

    lazy var hotButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setTitle("Hot", for: .normal)
        return button
    }()

    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: "01507B")
        return view
    }()

    private lazy var progressBar = UIView()

    private lazy var progressTick = UIView()

    private var selectedSort: PopViewModel.SortMethod = .New
    private var countdownTimer: Timer?
    private var startedTimer = false

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        clipsToBounds = false

        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(red: 0, green: 0.253, blue: 0.396, alpha: 1)
        self.backgroundView = backgroundView

        contentView.addSubview(visitorsIcon)
        visitorsIcon.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(visitorsCount)
        visitorsCount.snp.makeConstraints {
            $0.leading.equalTo(visitorsIcon.snp.trailing).offset(6)
            $0.centerY.equalToSuperview().offset(1.5)
        }

        contentView.addSubview(hotButton)
        hotButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-7)
            $0.centerY.equalToSuperview().offset(1)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.trailing.equalTo(hotButton.snp.leading).offset(-3)
            $0.height.equalTo(16)
            $0.width.equalTo(1)
            $0.centerY.equalToSuperview().offset(0.5)
        }

        contentView.addSubview(newButton)
        newButton.snp.makeConstraints {
            $0.trailing.equalTo(separatorView.snp.leading).offset(-3)
            $0.centerY.equalTo(hotButton)
        }

        contentView.addSubview(progressBar)
        progressBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(2)
        }

        contentView.addSubview(progressTick)
        progressTick.snp.makeConstraints {
            $0.leading.equalTo(progressBar.snp.trailing).offset(-3)
            $0.centerY.equalTo(progressBar)
            $0.height.equalTo(5)
            $0.width.equalTo(3.5)
        }
    }

    deinit {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    func configure(pop: Spot, sort: PopViewModel.SortMethod) {
        visitorsCount.text = "\(pop.visitorList.count) joined"

        configureSelectedSort(sort: sort)
        startCountdownTimer(pop: pop)
        configureTimeLeft(pop: pop)
    }

    private func configureSelectedSort(sort: PopViewModel.SortMethod) {
        // only using attributed strings because setTitleColor wasnt working

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: SpotFonts.UniversCE.fontWith(size: 13),
            .foregroundColor: UIColor.white
        ]
        let unselectedAttributes: [NSAttributedString.Key: Any] = [
            .font: SpotFonts.UniversCE.fontWith(size: 13),
            .foregroundColor: UIColor.white.withAlphaComponent(0.5)
        ]

        switch sort {
        case .New:
            newButton.setAttributedTitle(NSAttributedString(string: "New", attributes: selectedAttributes), for: .normal)
            hotButton.setAttributedTitle(NSAttributedString(string: "Hot", attributes: unselectedAttributes), for: .normal)
        case .Hot:
            hotButton.setAttributedTitle(NSAttributedString(string: "Hot", attributes: selectedAttributes), for: .normal)
            newButton.setAttributedTitle(NSAttributedString(string: "New", attributes: unselectedAttributes), for: .normal)
        }
    }

    private func configureTimeLeft(pop: Spot) {
        let totalTime = (pop.endTimestamp?.seconds ?? 0) - (pop.startTimestamp?.seconds ?? 0)
        let timeRemaining = (pop.endTimestamp?.seconds ?? 0) - Timestamp().seconds
        let percentageRemaining = max(CGFloat(timeRemaining) / CGFloat(totalTime), 0)
        // add 0.5 to offset progress tick off screen when time is up
        let offsetValue = UIScreen.main.bounds.width * (1 - percentageRemaining)

        progressBar.snp.removeConstraints()
        progressBar.snp.makeConstraints {
            $0.leading.bottom.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-offsetValue)
            $0.height.equalTo(2)
        }

        progressBar.backgroundColor =
        percentageRemaining > 0.5 ? UIColor(hexString: "#58FF58") :
        percentageRemaining > 0.15 ? UIColor(hexString: "FFF739") :
        UIColor(hexString: "E61515")

        progressTick.backgroundColor = progressBar.backgroundColor

        guard startedTimer else {
            progressBar.isHidden = true
            progressTick.isHidden = true
            return
        }

        guard pop.popIsActive else {
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "PopTimesUp")))
            countdownTimer?.invalidate()
            countdownTimer = nil

            progressBar.isHidden = true
            progressTick.isHidden = true
            return
        }

        if timeRemaining < 10 {
            // countdown vibration
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    private func startCountdownTimer(pop: Spot) {
        guard pop.popIsActive else { return }

        startedTimer = true
        countdownTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: true) { [weak self] timer in
            self?.configureTimeLeft(pop: pop)
        }

        countdownTimer?.tolerance = 0.1
        RunLoop.current.add(countdownTimer ?? Timer(), forMode: .common)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}
