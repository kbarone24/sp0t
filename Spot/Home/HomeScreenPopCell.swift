//
//  HomeScreenPopCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/25/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage
import Firebase

class HomeScreenPopCell: UICollectionViewCell {
    private lazy var postArea: UIImageView = {
        let view = UIImageView()
        view.layer.borderWidth = 3
        view.layer.cornerRadius = 21
        view.layer.masksToBounds = true
        view.contentMode = .scaleAspectFill
        view.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.25, radius: 3, offset: CGSize(width: 0, height: 1))
        return view
    }()

    private lazy var gradientBackground = UIView()

    private lazy var timestampArea: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 14
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = SpotFonts.SFCompactRoundedHeavy.fontWith(size: 14)
        return label
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 28)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 14.5)
        return label
    }()

    private lazy var statsView = UIView()

    private lazy var joinedIcon = UIImageView(image: UIImage(named: "PopVisitorsIcon"))

    private lazy var joinedLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.UniversCE.fontWith(size: 13)
        return label
    }()

    private lazy var fireIcon = UIImageView(image: UIImage(named: "HomeScreenFireIcon"))

    private lazy var fireLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.UniversCE.fontWith(size: 13)
        return label
    }()

    private var countdownTimer: Timer?

    override func layoutSubviews() {
        super.layoutSubviews()
        addGradient()
    }

    deinit {
        countdownTimer?.invalidate()
        countdownTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false

        contentView.addSubview(postArea)
        postArea.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.bottom.equalToSuperview()
        }

        postArea.addSubview(gradientBackground)
        gradientBackground.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        postArea.addSubview(timestampArea)
        timestampArea.snp.makeConstraints {
            $0.leading.top.equalToSuperview().offset(13)
        }

        timestampArea.addSubview(timestampLabel)
        timestampLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(8)
            $0.top.bottom.equalToSuperview().inset(5)
        }

        postArea.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(-20)
        }

        postArea.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.bottom.equalTo(descriptionLabel.snp.top).offset(-3)
            $0.leading.trailing.equalToSuperview().inset(14)
        }

        /*
        postArea.addSubview(statsView)
        statsView.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.bottom.equalTo(nameLabel.snp.top).offset(-7)
        }

        statsView.addSubview(joinedIcon)
        joinedIcon.snp.makeConstraints {
            $0.leading.bottom.equalToSuperview()
        }

        statsView.addSubview(joinedLabel)
        joinedLabel.snp.makeConstraints {
            $0.leading.equalTo(joinedIcon.snp.trailing).offset(4)
            $0.bottom.equalTo(joinedIcon)
        }

        statsView.addSubview(fireIcon)
        fireIcon.snp.makeConstraints {
            $0.leading.equalTo(joinedLabel.snp.trailing).offset(12)
            $0.bottom.equalTo(joinedIcon)
        }

        statsView.addSubview(fireLabel)
        fireLabel.snp.makeConstraints {
            $0.leading.equalTo(fireIcon.snp.trailing).offset(3.5)
            $0.bottom.equalTo(joinedLabel)
        }
         */
    }

    func configure(pop: Spot) {
        startCountdownTimer(pop: pop)
        configureView(pop: pop)
    }

    private func configureView(pop: Spot) {
        nameLabel.text = pop.spotName
        descriptionLabel.text = pop.spotDescription
        postArea.sd_setImage(with: URL(string: pop.imageURL), placeholderImage: nil, options: .highPriority) { [weak self] image, _, _, _ in
            if pop.popIsExpired, !pop.userHasPopAccess {
                self?.postArea.image = self?.postArea.image?.convertToGrayscale()
            }
        }

        statsView.isHidden = false
        joinedLabel.text = String(pop.visitorList.count)
        fireLabel.text = String(pop.fireScore)

        postArea.alpha = 1.0

        if pop.popIsExpired {
            if pop.userHasPopAccess {
                postArea.layer.borderColor = SpotColors.SpotGreen.color.cgColor
                timestampArea.backgroundColor = SpotColors.SpotGreen.color
                timestampLabel.text = "Joined"

            } else {
                postArea.alpha = 0.65
                postArea.layer.borderColor = UIColor(hexString: "D9D9D9").cgColor
                timestampArea.backgroundColor = UIColor(hexString: "D9D9D9")
                timestampLabel.text = "missed it 💔"
                postArea.image = postArea.image?.convertToGrayscale() ?? UIImage()
            }
            return
        }

        else if pop.popIsActive {
            // live pop
            postArea.layer.borderColor = UIColor(hexString: "58FF58").cgColor
            timestampArea.backgroundColor = UIColor(hexString: "58FF58")

        } else {
            // hasn't started yet
            postArea.layer.borderColor = UIColor(hexString: "DEFC24").cgColor
            timestampArea.backgroundColor = UIColor(hexString: "DEFC24")
            statsView.isHidden = true
        }

        configureTimeLeft(pop: pop)
    }

    private func addGradient() {
        gradientBackground.layoutIfNeeded()
        for layer in gradientBackground.layer.sublayers ?? [] { layer.removeFromSuperlayer() }
        let layer = CAGradientLayer()
        layer.colors = [
        UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
        UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor
        ]
        layer.locations = [0.0, 1]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.frame = gradientBackground.bounds
        gradientBackground.layer.insertSublayer(layer, at: 0)
    }

    private func configureTimeLeft(pop: Spot) {
        guard let startTimestamp = pop.startTimestamp else {
            timestampLabel.text = ""
            return
        }

        let currentTimestamp = Timestamp()

        if pop.popIsActive {
            let hoursLeft = pop.minutesRemaining / 60
            var minutesLessHours = max(pop.minutesRemaining % 60, 0)
            if pop.secondsRemaining > 0 {
                // round minutes up if there's still time left
                minutesLessHours += 1
            }
            timestampLabel.text = "Live now \(hoursLeft):\(String(format: "%02d", minutesLessHours)) left"

        } else if startTimestamp.seconds > currentTimestamp.seconds {
            let dateFormatter = DateFormatter()
            let calendar = Calendar.current
            let startDateTime = startTimestamp.dateValue()
            let daysDifference = calendar.dateComponents([.day], from: currentTimestamp.dateValue(), to: startDateTime).day ?? 0

            if daysDifference < 7 {
                dateFormatter.amSymbol = "AM"
                dateFormatter.pmSymbol = "PM"

                if calendar.isDate(startDateTime, inSameDayAs: currentTimestamp.dateValue()) {
                    // same calendar day
                    dateFormatter.dateFormat = "h:mma"
                    timestampLabel.text = "Today, \(dateFormatter.string(from: startDateTime))"
                    return
                }
                // show day of the week + time
                dateFormatter.dateFormat = "EEEE, h:mma"
                timestampLabel.text = dateFormatter.string(from: startDateTime)

            } else {
                // show date
                dateFormatter.dateFormat = "MM/dd/yyyy"
                timestampLabel.text = dateFormatter.string(from: startDateTime)
            }
        } else {
            // pop is expired
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "PopTimesUp")))
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    private func startCountdownTimer(pop: Spot) {
        guard let targetTimestamp = pop.endTimestamp else { return }

        // calculate seconds to next minute for the first time that this timer will fire to update the time remaining
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute], from: Date(), to: targetTimestamp.dateValue())
        let remainingSeconds = min((components.second ?? 0) + 1, 60)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(remainingSeconds), repeats: false) { [weak self] timer in
            self?.configureView(pop: pop)

            self?.countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
                self?.configureView(pop: pop)
            }
            self?.countdownTimer?.tolerance = 10  // Allow some tolerance for more accurate firing
            RunLoop.current.add(self?.countdownTimer ?? Timer(), forMode: .common)
        }

        countdownTimer?.tolerance = 1
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        countdownTimer?.invalidate()
        countdownTimer = nil
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
