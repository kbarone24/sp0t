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
    public var containerDrawerView: DrawerView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
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
        return collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "ProfileHeaderCell" : "ProfileBodyCell", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return section == 0 ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) : UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.frame.width - 40) / 2
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 160) : CGSize(width: width , height: 250)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 18
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
        // Disable the bouncing effect when scroll view is scrolled to top
        if lastYContentOffset != nil {
            if containerDrawerView?.status == .Top && scrollView.contentOffset.y <= lastYContentOffset! {
                scrollView.contentOffset.y = lastYContentOffset!
            }
        }
        
        // Whenever drawer view is not in top position, scroll to top, disable scroll and set drawer view swipe to next state true
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
        
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
