//
//  StillImagePreviewView.swift
//  Spot
//
//  Created by Kenny Barone on 7/21/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol StillImagePreviewDelegate: AnyObject {
    func finishPassing(imageObject: ImageObject)
}

class StillImagePreviewView: UIViewController {
    let imageObject: ImageObject
    weak var delegate: StillImagePreviewDelegate?

    private lazy var bottomMask: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 0.75)
        return view
    }()

    private lazy var topMask: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 0.75)
        return view
    }()

    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var useButton: UIButton = {
        let button = UIButton()
        button.setTitle("Use Photo", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
        button.addTarget(self, action: #selector(usePhotoTap), for: .touchUpInside)
        return button
    }()

    lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        return button
    }()

    init(imageObject: ImageObject) {
        self.imageObject = imageObject
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = UIColor(named: "SpotBlack")
        edgesForExtendedLayout = []

        imageView.image = imageObject.stillImage
        view.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(topMask)
        topMask.snp.makeConstraints {
            $0.leading.top.trailing.equalToSuperview()
            $0.height.equalTo(UserDataModel.shared.statusHeight + 45)
        }

        view.addSubview(bottomMask)
        bottomMask.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(100)
        }

        bottomMask.addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.top.equalTo(20)
        }

        bottomMask.addSubview(useButton)
        useButton.snp.makeConstraints {
            $0.trailing.equalTo(-14)
            $0.top.equalTo(cancelButton)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func cancelTap() {
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: false)
        }
    }

    @objc func usePhotoTap() {
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: false)
            self.delegate?.finishPassing(imageObject: self.imageObject)
        }
    }
}
