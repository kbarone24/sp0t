//
//  PopOverviewHeader.swift
//  Spot
//
//  Created by Kenny Barone on 8/28/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PopOverviewHeader: UITableViewHeaderFooterView {
    private lazy var timeLeftLabel: UILabel = {
        let label = UILabel()
        label.font = SpotFonts.UniversCE.fontWith(size: 13)
        return label
    }()

    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    private lazy var joinLabel: UILabel = {
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

    private lazy var sortArrows = UIImageView(image: UIImage(named: "SpotSortArrows"))

    private(set) lazy var sortButton = UIButton()

    private var countdownTimer: Timer?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(red: 0, green: 0.253, blue: 0.396, alpha: 1)
        self.backgroundView = backgroundView

        contentView.addSubview(timeLeftLabel)
        timeLeftLabel.snp.makeConstraints {
            $0.leading.equalTo(8)
            $0.centerY.equalToSuperview().offset(1.5)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.leading.equalTo(timeLeftLabel.snp.trailing).offset(8)
            $0.width.equalTo(2)
            $0.height.equalTo(12)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(joinLabel)
        joinLabel.snp.makeConstraints {
            $0.leading.equalTo(separatorView.snp.trailing).offset(8)
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
    }

    deinit {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    func configure(pop: Spot, sort: PopViewModel.SortMethod) {
        configureTimeLeft(pop: pop)
        joinLabel.text = "\(pop.visitorList.count) joined"
        sortLabel.text = sort.rawValue

        startCountdownTimer(pop: pop)
    }

    private func configureTimeLeft(pop: Spot) {
        let hoursLeft = pop.minutesRemaining / 60
        let minutesLessHours = max(pop.minutesRemaining % 60, 0)
        timeLeftLabel.text = "\(hoursLeft):\(String(format: "%02d", minutesLessHours)) left"
        timeLeftLabel.textColor = pop.minutesRemaining > 10 ? UIColor(hexString: "FFF739") : UIColor(hexString: "E61515")
    }

    private func startCountdownTimer(pop: Spot) {
        guard let targetTimestamp = pop.endTimestamp else { return }

        // calculate seconds to next minute for the first time that this timer will fire to update the time remaining
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute], from: Date(), to: targetTimestamp.dateValue())
        let remainingSeconds = min((components.second ?? 0) + 5, 60)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(remainingSeconds), repeats: false) { [weak self] timer in
            self?.configureTimeLeft(pop: pop)

            self?.countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
                self?.configureTimeLeft(pop: pop)
            }
            self?.countdownTimer?.tolerance = 10  // Allow some tolerance for more accurate firing
            RunLoop.current.add(self?.countdownTimer ?? Timer(), forMode: .common)
        }

        countdownTimer?.tolerance = 10  // Allow some tolerance for more accurate firing
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
