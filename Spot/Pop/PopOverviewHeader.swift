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

    private lazy var sortLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.UniversCE.fontWith(size: 13)
        return label
    }()

    private lazy var progressBar = UIView()

    private lazy var progressTick = UIView()

    private lazy var sortArrows = UIImageView(image: UIImage(named: "SpotSortArrows"))

    private(set) lazy var sortButton = UIButton()

    private var countdownTimer: Timer?
    var startedTimer = false

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

        contentView.addSubview(sortArrows)
        sortArrows.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-17)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(sortLabel)
        sortLabel.snp.makeConstraints {
            $0.trailing.equalTo(sortArrows.snp.leading).offset(-9)
            $0.centerY.equalToSuperview().offset(1)
        }

        contentView.addSubview(sortButton)
        sortButton.snp.makeConstraints {
            $0.leading.equalTo(sortLabel.snp.leading).offset(-5)
            $0.trailing.equalTo(sortArrows.snp.trailing).offset(5)
            $0.centerY.height.equalToSuperview()
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
        sortLabel.text = sort.rawValue

        startCountdownTimer(pop: pop)
        configureTimeLeft(pop: pop)
    }

    private func configureTimeLeft(pop: Spot) {
        let totalTime = (pop.endTimestamp?.seconds ?? 0) - (pop.startTimestamp?.seconds ?? 0)
        let timeRemaining = (pop.endTimestamp?.seconds ?? 0) - Timestamp().seconds
        let percentageRemaining = max(CGFloat(timeRemaining) / CGFloat(totalTime), 0)
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

        guard startedTimer else { return }

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
