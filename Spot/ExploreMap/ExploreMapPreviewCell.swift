//
//  ExploreMapPreviewCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

protocol ExploreMapPreviewCellDelegate: AnyObject {
    func cellTapped(map: CustomMap, posts: [MapPost])
    func joinMap(map: CustomMap)
    func moreTapped(map: CustomMap)
    func cacheScrollPosition(map: CustomMap, position: CGPoint)
}

final class ExploreMapPreviewCell: UITableViewCell {
    typealias Snapshot = NSDiffableDataSourceSnapshot<MapPhotosCollectionView.Section, MapPhotosCollectionView.Item>

    private lazy var titleContainer = UIView()

    private lazy var rankLabel = GradientLabel(topColor: UIColor(hexString: "#A5A5A5"), bottomColor: UIColor(hexString: "#505050"), font: UIFont(name: "SFCompactText-Heavy", size: 28))

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Bold", size: 16)
        //TODO: replace with real font
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Bold", size: 11.5)
        label.numberOfLines = 0
        label.textColor = UIColor(red: 0.851, green: 0.851, blue: 0.851, alpha: 1)
        label.textAlignment = .left
        return label
    }()

    private lazy var separatorIcon: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.851, green: 0.851, blue: 0.851, alpha: 1)
        return view
    }()

    private lazy var founderLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.433, green: 0.433, blue: 0.433, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 11.5)
        return label
    }()

    private lazy var headerView = UIView()

    private lazy var joinButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)
        return button
    }()

    private lazy var moreButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "SimpleMoreButton"), for: .normal)
        button.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var photosCollectionView: MapPhotosCollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInsetReference = .fromContentInset
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        
        let collectionView = MapPhotosCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isScrollEnabled = true
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.allowsSelection = false
        
        return collectionView
    }()

    var tap: UITapGestureRecognizer?
    private weak var delegate: ExploreMapPreviewCellDelegate?
    private var onJoinTap: (() -> Void)?
    private var onCellTap: (() -> Void)?
    private var onMoreTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = UIColor(named: "SpotBlack")
        contentView.backgroundColor = UIColor(named: "SpotBlack")
        
        contentView.addSubview(headerView)
        contentView.addSubview(photosCollectionView)

        headerView.addSubview(rankLabel)
        headerView.addSubview(titleContainer)
        headerView.addSubview(moreButton)
        titleContainer.addSubview(titleLabel)
        titleContainer.addSubview(scoreLabel)
        titleContainer.addSubview(separatorIcon)
        titleContainer.addSubview(founderLabel)
        
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        rankLabel.snp.makeConstraints {
            $0.leading.equalTo(14.0)
            $0.centerY.equalToSuperview()
        }

        // auto-sizing container to center with cover image
        titleContainer.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8.0)
            $0.leading.equalTo(40)
            $0.trailing.equalToSuperview().inset(96.0)
            $0.bottom.equalToSuperview().offset(-8.0)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }
        
        scoreLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(3.0)
            $0.leading.bottom.equalToSuperview()
        }

        separatorIcon.snp.makeConstraints {
            $0.leading.equalTo(scoreLabel.snp.trailing).offset(5)
            $0.centerY.equalTo(scoreLabel)
            $0.height.width.equalTo(2)
        }

        founderLabel.snp.makeConstraints {
            $0.leading.equalTo(separatorIcon.snp.trailing).offset(5)
            $0.centerY.equalTo(scoreLabel)
        }

        let itemWidth = (UIScreen.main.bounds.width - 18) / 2.85
        let itemHeight = itemWidth * 1.25 + 2
        photosCollectionView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(headerView.snp.bottom).offset(4.0)
            $0.bottom.equalToSuperview().inset(28.0)
            $0.height.equalTo(itemHeight)
        }

        moreButton.snp.makeConstraints {
            $0.trailing.equalTo(-10)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(18.3)
            $0.width.equalTo(29.83)
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        scoreLabel.text = ""
        scoreLabel.attributedText = nil
        joinButton.removeFromSuperview()
        onJoinTap = nil
        onCellTap = nil
        if let tap { removeGestureRecognizer(tap) }
        headerView.gestureRecognizers?.forEach { headerView.removeGestureRecognizer($0) }
    }
    
    func configure(
        customMap: CustomMap,
        data: [MapPost],
        rank: Int,
        isSelected: Bool,
        delegate: ExploreMapPreviewCellDelegate?,
        position: CGPoint
    ) {
        self.delegate = delegate
        tap = UITapGestureRecognizer(target: self, action: #selector(cellTapped(_:)))
        addGestureRecognizer(tap ?? UITapGestureRecognizer())

        rankLabel.text = String(rank)
        titleLabel.text = customMap.mapName

        let attachment = NSTextAttachment()
        attachment.image = UIImage(named: "MapScoreIcon")?
            .withRenderingMode(.alwaysOriginal)
        let attachmentString = NSAttributedString(attachment: attachment)
        let myString = NSMutableAttributedString()
        myString.append(attachmentString)
        myString.append(
            NSMutableAttributedString(string: " \(Int(customMap.mapScore ?? 0))")
        )
        
        myString.addAttributes(
            [
                .foregroundColor: UIColor(red: 0.433, green: 0.433, blue: 0.433, alpha: 1) as Any
            ],
            range: NSRange(location: 0, length: myString.length)
        )
        
        scoreLabel.attributedText = myString
        founderLabel.text = "by \(customMap.posterUsernames.first ?? "")"

        headerView.addSubview(joinButton)
        if isSelected {
            joinButton.isUserInteractionEnabled = false
            joinButton.setImage(UIImage(named: "JoinedButtonImage"), for: .normal)
            joinButton.snp.removeConstraints()
            joinButton.snp.makeConstraints {
                $0.centerY.equalToSuperview()
                $0.trailing.equalTo(moreButton.snp.leading).offset(-4.5)
                $0.height.equalTo(21.54)
                $0.width.equalTo(25)
            }
            
        } else {
            joinButton.isUserInteractionEnabled = true
            joinButton.setImage(UIImage(named: "JoinButtonImage"), for: .normal)
            joinButton.snp.removeConstraints()
            joinButton.snp.makeConstraints {
                $0.centerY.equalToSuperview()
                $0.trailing.equalTo(moreButton.snp.leading).offset(-4.5)
                $0.height.equalTo(38)
                $0.width.equalTo(38)
            }
        }

        self.onJoinTap = { [weak self] in
            self?.delegate?.joinMap(map: customMap)
        }

        self.onMoreTap = { [weak self] in
            self?.delegate?.moreTapped(map: customMap)
        }

        self.onCellTap = { [weak self] in
            self?.delegate?.cellTapped(map: customMap, posts: data)
        }

        var snapshot = Snapshot()
        snapshot.appendSections([.main(customMap)])
        data.forEach {
            snapshot.appendItems([.item($0)], toSection: .main(customMap))
        }
        
        photosCollectionView.configure(snapshot: snapshot, delegate: delegate, position: position)
    }

    @objc private func cellTapped(_ sender: UITapGestureRecognizer) {
        // cancelTouches in and around the action buttons to avoid accidental taps
        let location = sender.location(in: self)
        if location.x > joinButton.frame.minX - 10 && location.y < headerView.frame.maxY { return }
        onCellTap?()
    }
    
    @objc private func joinTapped() {
        onJoinTap?()
        HapticGenerator.shared.play(.light)
    }

    @objc private func moreTapped() {
        onMoreTap?()
    }
}
