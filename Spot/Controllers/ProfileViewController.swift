//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SnapKit

class ProfileViewController: UIViewController {
    
    private var profileCollectionView: UICollectionView!
    private var lastYContentOffset: CGFloat?
    private var noPostLabel: UILabel!
    private var barView: UIView!
    private var titleLabel: UILabel!
    public var containerDrawerView: DrawerView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
    }
    
    private func setNavBar(transparent: Bool) {
        title = transparent ? "" : UserDataModel.shared.userInfo.name
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 20.5)!]
        navigationController?.navigationBar.setBackgroundImage(transparent ? UIImage() : nil, for: .default)
        navigationController?.navigationBar.shadowImage = transparent ? UIImage() : nil
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.barTintColor = .white
    }
}

extension ProfileViewController {
    
    private func viewSetup() {
        view.backgroundColor = .white
        
        profileCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(ProfileHeaderCell.self, forCellWithReuseIdentifier: "ProfileHeaderCell")
            view.register(ProfileMyMapCell.self, forCellWithReuseIdentifier: "ProfileMyMapCell")
            view.register(ProfileBodyCell.self, forCellWithReuseIdentifier: "ProfileBodyCell")
            return view
        }()
        view.addSubview(profileCollectionView)

        // Need a new pan gesture to react when profileCollectionView scroll disables
        let scrollViewPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        scrollViewPanGesture.delegate = self
        profileCollectionView.addGestureRecognizer(scrollViewPanGesture)
        profileCollectionView.isScrollEnabled = false
        profileCollectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        noPostLabel = UILabel {
            $0.text = "\(UserDataModel.shared.userInfo.name) hasn't posted yet"
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.isHidden = true
            view.addSubview($0)
        }
        noPostLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(243)
        }
        
        barView = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: (containerDrawerView?.slideView.frame.width)!, height: 91)
            $0.backgroundColor = .white
            $0.alpha = 0
        }
        titleLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = UserDataModel.shared.userInfo.name
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.sizeToFit()
            $0.frame = CGRect(origin: CGPoint(x: 0, y: 55), size: CGSize(width: (containerDrawerView?.slideView.frame.width)!, height: 18))
            barView.addSubview($0)
        }
        containerDrawerView?.slideView.insertSubview(barView, aboveSubview: (navigationController?.view)!)
    }
}

extension ProfileViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : 10
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "ProfileHeaderCell" : indexPath.row == 0 ? "ProfileMyMapCell" : "ProfileBodyCell", for: indexPath)
        if let mapCell = cell as? ProfileMyMapCell {
            mapCell.myMapImages = [R.image.landingPage0()!, R.image.landingPage1()!, R.image.landingPage2()!, R.image.landingPage3()!, R.image.landingPage4()!, R.image.landingPage0()!, R.image.landingPage1()!, R.image.landingPage2()!, R.image.landingPage3()!, R.image.landingPage4()!]
            return mapCell
        } else if let bodyCell = cell as? ProfileBodyCell {
            
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return section == 0 ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) : UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.frame.width - 40) / 2
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 160) : CGSize(width: width , height: 250)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let collectionCell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.15) {
            collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { (Bool) in
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = .identity
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        let collectionCell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.15) {
            collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        let collectionCell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.15) {
            collectionCell?.transform = .identity
        }
    }
}

extension ProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // Show navigation bar when user scroll pass the header section
        setNavBar(transparent: !(scrollView.contentOffset.y >= (lastYContentOffset ?? -50) + 160))

        // Disable the bouncing effect when scroll view is scrolled to top
        if lastYContentOffset != nil {
            if containerDrawerView?.status == .Top && scrollView.contentOffset.y <= lastYContentOffset! {
                scrollView.contentOffset.y = lastYContentOffset!
            }
        }
                
        // Whenever drawer view is not in top position, scroll to top, disable scroll and enable drawer view swipe to next state
        if containerDrawerView?.status != .Top {
            profileCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            profileCollectionView.isScrollEnabled = false
            containerDrawerView?.swipeToNextState = true
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // When scroll to top this will be called last
        if scrollView.contentOffset.y == lastYContentOffset ?? -50 && containerDrawerView?.status == .Top {
            containerDrawerView?.swipeToNextState = true
        }
    }
}

extension ProfileViewController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Swipe up y translation < 0
        // Swipe down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y
        
        
        // Get the initial Top y position contentOffset
        if containerDrawerView?.status == .Top && lastYContentOffset == nil {
            lastYContentOffset = profileCollectionView.contentOffset.y
        }
        
        // Enter full screen then enable collection view scrolling and determine if need drawer view swipe to next state feature according to user swipe direction
        if
            containerDrawerView?.status == .Top &&
            profileCollectionView.contentOffset.y <= lastYContentOffset ?? -50
        {
            profileCollectionView.isScrollEnabled = true
            containerDrawerView?.swipeToNextState = yTranslation > 0 ? true : false
        }

        // Preventing the drawer view to be dragged when it's status is top and user is scrolling down
        if
            containerDrawerView?.status == .Top &&
            profileCollectionView.contentOffset.y > lastYContentOffset ?? -50 &&
            yTranslation > 0 && containerDrawerView?.swipeToNextState == false &&
            containerDrawerView!.slideView.frame.origin.y > 0
        {
            containerDrawerView?.slideView.frame.origin.y -= yTranslation
        }
        
        // Preventing the content in collection view being scrolled when the status of drawer view is top but frame.minY is not 0
        if (containerDrawerView?.slideView.frame.minY)! > 0 {
            profileCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        }
        
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
