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
    
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if profileCollectionView.contentOffset.y <= lastYContentOffset ?? -50 && containerDrawerView?.status == .Top {
//            profileCollectionView.isScrollEnabled = true
//        }
//    }
}

extension ProfileViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : 5
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
        print("scrollViewDidScroll")
        // Get the initial Top y position contentOffset
        if containerDrawerView?.status == .Top && lastYContentOffset == nil {
            lastYContentOffset = scrollView.contentOffset.y
        }
        
//        scrollView.isScrollEnabled = containerDrawerView?.status == .Top ? true : false
        
        if lastYContentOffset != nil {
            if scrollView.contentOffset.y < lastYContentOffset! {
                scrollView.isScrollEnabled = false
            }
        }
    }
    
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        print("scrollViewWillBeginDecelerating")
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        print("scrollViewDidEndDecelerating")
        // When profileCollectionView is scrolled to top and user stops scrolling, set scroll to false, so user can interact with drawerView
        if scrollView.contentOffset.y <= lastYContentOffset ?? -50 {
            scrollView.isScrollEnabled = false
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        print("scrollViewWillBeginDragging")
    }
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        print("scrollViewWillEndDragging")
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        print("scrollViewDidEndDragging")
    }
    
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        print("scrollViewDidChangeAdjustedContentInset")
    }
}

extension ProfileViewController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Swipe up y translation < 0
        // Swipe down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y
        // When profileCollectionView is scrolled to top, drawerView is in top position and user swipes up, set scroll to true
        if profileCollectionView.contentOffset.y <= lastYContentOffset ?? -50 && containerDrawerView?.status == .Top && yTranslation < 0 {
            profileCollectionView.isScrollEnabled = true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
