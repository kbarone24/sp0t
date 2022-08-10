//
//  SpotPageController.swift
//  Spot
//
//  Created by Arnold on 8/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit
import Mixpanel
import Firebase
import SDWebImage

class SpotPageController: UIViewController {

    private var spotPageCollectionView: UICollectionView!
    private var addSpotButton: UIButton!
    private var barView: UIView!
    private var titleLabel: UILabel!
    private var barBackButton: UIButton!
    private var mapPostLabel: UILabel!
    private var communityPostLabel: UILabel!
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("SpotPageController(\(self) deinit")
        barView.removeFromSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
    }
}

extension SpotPageController {
    private func viewSetup() {
        view.backgroundColor = .white
        navigationItem.setHidesBackButton(true, animated: true)
        
        spotPageCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(SpotPageHeaderCell.self, forCellWithReuseIdentifier: "SpotPageHeaderCell")
            view.register(SpotPageBodyCell.self, forCellWithReuseIdentifier: "SpotPageBodyCell")
            return view
        }()
        view.addSubview(spotPageCollectionView)
        spotPageCollectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        addSpotButton = UIButton {
            $0.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
            $0.layer.shadowOpacity = 1
            $0.layer.shadowRadius = 8
            $0.layer.shadowOffset = CGSize(width: 0, height: 0.5)
            $0.setImage(UIImage(named: "AddToSpotButton"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(addSpotAction), for: .touchUpInside)
            view.addSubview($0)
        }
        addSpotButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview().inset(35)
            $0.width.height.equalTo(73)
        }
        
        barView = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 91)
            $0.backgroundColor = .gray
            view.addSubview($0)
        }
        titleLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = "asdcasd"
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.sizeToFit()
            $0.frame = CGRect(origin: CGPoint(x: 0, y: 55), size: CGSize(width: view.frame.width, height: 18))
            barView.addSubview($0)
        }
        barBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrow-1"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
            barView.addSubview($0)
        }
        barBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.centerY.equalTo(titleLabel)
        }
        
        mapPostLabel = UILabel {
            let frontPadding = "    "
            let bottomPadding = "   "
            $0.text = frontPadding + "mapPostLabel" + bottomPadding
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 8
            $0.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
        
        communityPostLabel = UILabel {
            let frontPadding = "    "
            let bottomPadding = "   "
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "CommunityGlobe")
            imageAttachment.bounds = CGRect(x: 0, y: -2.5, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: frontPadding)
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " "))
            completeText.append(NSAttributedString(string: "Community Post" + bottomPadding))
            $0.attributedText = completeText
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.textColor = UIColor(red: 0.587, green: 0.587, blue: 0.587, alpha: 1)
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 8
            $0.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
    }
    
    @objc func addSpotAction() {
        
    }
    
    @objc func backButtonAction() {
        barBackButton.isHidden = true
        dismiss(animated: true)
    }
}

extension SpotPageController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : 3
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "SpotPageHeaderCell" : "SpotPageBodyCell", for: indexPath)
        if let headerCell = cell as? SpotPageHeaderCell {
            return headerCell
        } else if let bodyCell = cell as? SpotPageBodyCell {
            if indexPath == IndexPath(row: 0, section: 1) && view.subviews.contains(mapPostLabel) == false  {
                collectionView.addSubview(mapPostLabel)
                mapPostLabel.snp.makeConstraints {
                    $0.leading.equalToSuperview()
                    $0.top.equalToSuperview().offset(cell.frame.minY - 15.5)
                    $0.height.equalTo(31)
                }
                
            }
            if indexPath == IndexPath(row: 0, section: 2) && view.subviews.contains(communityPostLabel) == false {
                collectionView.addSubview(communityPostLabel)
                communityPostLabel.snp.makeConstraints {
                    $0.leading.equalToSuperview()
                    $0.top.equalToSuperview().offset(cell.frame.minY - 15.5)
                    $0.height.equalTo(31)
                }
                
            }

            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 130) : CGSize(width: view.frame.width/2 - 0.5, height: (view.frame.width/2 - 0.5) * 267 / 194.5)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
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

extension SpotPageController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > -91 {
            barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
            titleLabel.text = scrollView.contentOffset.y > 0 ? "" : ""
        }
    }
}
