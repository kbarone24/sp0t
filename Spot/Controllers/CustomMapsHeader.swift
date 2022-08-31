//
//  CustomMapsHeader.swift
//  Spot
//
//  Created by Kenny Barone on 8/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CustomMapsHeader: UITableViewHeaderFooterView {
    var customMapsLabel: UILabel!
    var newMapButton: UIButton!
    var plusIcon: UIImageView!
    var mapLabel: UILabel!
    var mapsEmpty: Bool = true {
        didSet {
            customMapsLabel.isHidden = mapsEmpty
        }
    }
    var newMap: Bool = false {
        didSet {
            newMapButton.isHidden = newMap
        }
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView
                
        customMapsLabel = UILabel {
            $0.text = "MY MAPS"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.isHidden = true
            addSubview($0)
        }
        customMapsLabel.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.bottom.equalToSuperview().inset(6)
        }

        newMapButton = UIButton {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.addTarget(self, action: #selector(newMapTap(_:)), for: .touchUpInside)
            $0.layer.cornerRadius = 15
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1).cgColor
            addSubview($0)
        }
        newMapButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(26)
            $0.bottom.equalToSuperview().inset(10)
            $0.width.equalTo(101)
            $0.height.equalTo(30)
        }

        plusIcon = UIImageView {
            $0.image = UIImage(named: "PlusIcon")
            newMapButton.addSubview($0)
        }
        plusIcon.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.width.height.equalTo(12)
            $0.centerY.equalToSuperview()
        }
        
        mapLabel = UILabel {
            $0.text = "New map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            newMapButton.addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(plusIcon.snp.trailing).offset(5)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func newMapTap(_ sender: UIButton) {
        if let chooseMapVC = viewContainingController() as? ChooseMapController {
            if let newMapVC = chooseMapVC.storyboard?.instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
                newMapVC.delegate = chooseMapVC
                chooseMapVC.present(newMapVC, animated: true)
            }
        }
    }
}

