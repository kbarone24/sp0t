//
//  CustomMapController.swift
//  Spot
//
//  Created by Arnold on 7/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit
import Mixpanel
import Firebase

class CustomMapController: UIViewController {
    
    private var customMapCollectionView: UICollectionView!
    
    private var userProfile: UserProfile?
    private var mapData: CustomMap? {
        didSet {
            customMapCollectionView.reloadData()
        }
    }
    private var containerDrawerView: DrawerView?

    init(userProfile: UserProfile? = nil, mapData: CustomMap, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
        self.mapData = mapData
        self.containerDrawerView = presentedDrawerView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        // Do any additional setup after loading the view.
    }
}

extension CustomMapController {
    private func viewSetup() {
        view.backgroundColor = .white

        self.title = ""
        navigationItem.backButtonTitle = ""

        navigationController!.navigationBar.barTintColor = UIColor.white
        navigationController!.navigationBar.isTranslucent = true
        navigationController!.navigationBar.barStyle = .black
        navigationController!.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white
        
        navigationController!.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            .font: UIFont(name: "SFCompactText-Heavy", size: 20)!
        ]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrow-1"),
            style: .plain,
            target: containerDrawerView,
            action: #selector(containerDrawerView?.closeAction)
        )
        
        customMapCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(CustomMapHeaderCell.self, forCellWithReuseIdentifier: "CustomMapHeaderCell")
            view.register(CustomMapBodyCell.self, forCellWithReuseIdentifier: "CustomMapBodyCell")
            return view
        }()
        view.addSubview(customMapCollectionView)
        customMapCollectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension CustomMapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : 10
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "CustomMapHeaderCell" : "CustomMapBodyCell", for: indexPath)
        if let headerCell = cell as? CustomMapHeaderCell {
            headerCell.cellSetup(userProfile: userProfile!, mapData: mapData)
            return headerCell
        } else if let bodyCell = cell as? CustomMapBodyCell {
            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: mapData?.mapDescription != nil ? 180 : 155) : CGSize(width: view.frame.width/2 - 0.5, height: (view.frame.width/2 - 0.5) * 267 / 194.5)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            Mixpanel.mainInstance().track(event: "CustomMapSelect")
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (Bool) in
                UIView.animate(withDuration: 0.15) {
                    collectionCell?.transform = .identity
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = .identity
            }
        }
    }
}
