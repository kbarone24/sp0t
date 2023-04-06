//
//  GalleryCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import Mixpanel

class GalleryCell: UICollectionViewCell {
    private lazy var globalRow = 0
    private lazy var id = ""
    lazy var requestID: Int32 = 1

    lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.frame = self.bounds
        view.image = UIImage(color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1))
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.isUserInteractionEnabled = true
        return view
    }()

    lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.color = .white
        view.transform = CGAffineTransform(scaleX: 1.7, y: 1.7)
        view.isHidden = true
        return view
    }()

    private lazy var circleView: CircleView = {
        let view = CircleView()
        view.layer.cornerRadius = 11.5
        return view
    }()

    private lazy var circleButton = UIButton()

    private lazy var imageMask: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.5)
        return view
    }()

    private lazy var playImage: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "PlayButton")
        view.isHidden = true
        return view
    }()

    private lazy var timestamp: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFont(name: "SFCompactText-Semibold", size: 12.5)
        return view
    }()

    private var imageSelected: Bool = false {
        didSet {
            imageMask.isHidden = !imageSelected
            circleView.selected = imageSelected
        }
    }

    lazy var asset: PHAsset = PHAsset() {
        didSet {
            playImage.isHidden = !(asset.mediaType == .video)
            timestamp.isHidden = playImage.isHidden
            timestamp.text = asset.duration.minutesSeconds
            circleView.isHidden = asset.mediaType == .video
            circleButton.isHidden = circleView.isHidden
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        layer.borderWidth = 1
        layer.borderColor = UIColor(named: "SpotBlack")?.cgColor
        isOpaque = true

        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpView() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        contentView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.height.width.equalTo(30)
            $0.centerX.centerY.equalToSuperview()
        }

        // live indicator shows playbutton over image to indicate live capability on this image
        contentView.addSubview(playImage)
        playImage.snp.makeConstraints {
            $0.width.height.equalTo(28)
            $0.centerX.centerY.equalToSuperview()
        }

        contentView.addSubview(timestamp)
        timestamp.snp.makeConstraints {
            $0.trailing.bottom.equalToSuperview().offset(-3)
        }

        contentView.addSubview(imageMask)
        imageMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        contentView.addSubview(circleView)
        circleView.snp.makeConstraints {
            $0.trailing.equalTo(imageView.snp.trailing).inset(6)
            $0.top.equalTo(imageView.snp.top).offset(6)
            $0.width.height.equalTo(23)
        }

        circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        contentView.addSubview(circleButton)
        circleButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.width.height.equalTo(40)
        }
    }

    func setUp(asset: PHAsset, row: Int, selected: Bool, id: String) {
        self.asset = asset
        self.globalRow = row
        self.id = id
        self.imageSelected = selected
    }

    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }

    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        activityIndicator.stopAnimating()
        if let galleryVC = viewContainingController() as? PhotoGalleryController {
            galleryVC.imageManager.cancelImageRequest(requestID)
        }
    }

    @objc func circleTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "GalleryCircleTap")
        guard let picker = viewContainingController() as? PhotoGalleryController else { return }
        if UploadPostModel.shared.selectedObjects.contains(where: { $0.id == id }) {
            picker.deselect(index: globalRow)
        } else {
            picker.select(index: globalRow)
        }
    }
}
