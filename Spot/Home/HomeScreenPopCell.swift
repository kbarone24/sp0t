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

class HomeScreenPopCell: UITableViewCell {
    private lazy var postArea: UIImageView = {
        let view = UIImageView()
        view.layer.borderWidth = 3
        view.layer.cornerRadius = 21
        view.layer.masksToBounds = true
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

    override func layoutSubviews() {
        super.layoutSubviews()
        addGradient()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(postArea)
        postArea.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.height.equalTo(192)
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
    }

    func configure(pop: Spot) {
        let activeColor = UIColor(hexString: "58FF58")
        let inactiveColor = UIColor(hexString: "DEFC24")
        postArea.layer.borderColor = pop.popIsActive ? activeColor.cgColor : inactiveColor.cgColor
        postArea.sd_setImage(with: URL(string: pop.imageURL), placeholderImage: nil, options: .highPriority)
        
        timestampArea.backgroundColor = pop.popIsActive ? activeColor : inactiveColor
        timestampLabel.text = getTimestampText(pop: pop)

        nameLabel.text = pop.spotName
        descriptionLabel.text = pop.spotDescription
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

    private func getTimestampText(pop: Spot) -> String {
        guard let startTimestamp = pop.startTimestamp, let endTimestamp = pop.endTimestamp else { return "" }
        let currentTimestamp = Timestamp()
        let startDateTime = startTimestamp.dateValue()
        let endDateTime = endTimestamp.dateValue()

        if pop.popIsActive {
            let hoursLeft = pop.minutesRemaining / 60
            let minutesLessHours = pop.minutesRemaining % 60
            return "Live now \(hoursLeft):\(String(format: "%02d", minutesLessHours)) left"

        } else if startTimestamp.seconds > currentTimestamp.seconds {
            let dateFormatter = DateFormatter()
            let calendar = Calendar.current
            let daysDifference = calendar.dateComponents([.day], from: currentTimestamp.dateValue(), to: startDateTime).day ?? 0

            if daysDifference < 7 {
                dateFormatter.amSymbol = "AM"
                dateFormatter.pmSymbol = "PM"

                if calendar.isDate(startDateTime, inSameDayAs: currentTimestamp.dateValue()) {
                    // same calendar day
                    dateFormatter.dateFormat = "h:mma"
                    return "Today, \(dateFormatter.string(from: startDateTime))"

                }
                // show day of the week + time
                dateFormatter.dateFormat = "EEEE, h:mma"
                return dateFormatter.string(from: startDateTime)

            } else {
                // show date
                dateFormatter.dateFormat = "MM/dd/yyyy"
                return dateFormatter.string(from: startDateTime)
            }
        }
        return ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
