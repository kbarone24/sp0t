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
    
    private var topYContentOffset: CGFloat?
    private var middleYContentOffset: CGFloat?
    
    private var customMapCollectionView: UICollectionView!
    private var floatBackButton: UIButton!
    private var barView: UIView!
    private var titleLabel: UILabel!
    private var barBackButton: UIButton!
    
    private var userProfile: UserProfile?
    public var mapData: CustomMap? {
        didSet {
            customMapCollectionView.reloadData()
        }
    }
    private var containerDrawerView: DrawerView?
    public var profileVC: ProfileViewController?
    private var mapController: UIViewController?

    init(userProfile: UserProfile? = nil, mapData: CustomMap, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
        self.mapData = mapData
        self.containerDrawerView = presentedDrawerView
        containerDrawerView?.canInteract = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        floatBackButton.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
        barView.removeFromSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
        if let mapVC = window as? UINavigationController {
            mapController = mapVC.viewControllers[0]
        }
        viewSetup()
    }
}

extension CustomMapController {
    private func viewSetup() {
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToTopCompletion), name: NSNotification.Name("DrawerViewToTopComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToMiddleCompletion), name: NSNotification.Name("DrawerViewToMiddleComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToBottomCompletion), name: NSNotification.Name("DrawerViewToBottomComplete"), object: nil)
        
        view.backgroundColor = .white
        navigationItem.setHidesBackButton(true, animated: true)
        
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
        // Need a new pan gesture to react when profileCollectionView scroll disables
        let scrollViewPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        scrollViewPanGesture.delegate = self
        customMapCollectionView.addGestureRecognizer(scrollViewPanGesture)
        customMapCollectionView.isScrollEnabled = false
        
        floatBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrow-1"), for: .normal)
            $0.backgroundColor = .white
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
            $0.layer.cornerRadius = 19
            mapController?.view.insertSubview($0, belowSubview: containerDrawerView!.slideView)
        }
        floatBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(15)
            $0.top.equalToSuperview().offset(49)
            $0.height.width.equalTo(38)
        }
        
        barView = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 91)
            $0.backgroundColor = .clear
        }
        titleLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = ""
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
            $0.isHidden = true
            barView.addSubview($0)
        }
        barBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.centerY.equalTo(titleLabel)
        }
        containerDrawerView?.slideView.addSubview(barView)
    }
    
    @objc func DrawerViewToTopCompletion() {
        barBackButton.isHidden = false
        customMapCollectionView.isScrollEnabled = true
    }
    @objc func DrawerViewToMiddleCompletion() {
        barBackButton.isHidden = true
    }
    @objc func DrawerViewToBottomCompletion() {
        barBackButton.isHidden = true
    }
    
    @objc func backButtonAction() {
        barBackButton.isHidden = true
        profileVC?.maps[profileVC!.mapSelectedIndex!] = mapData!
        navigationController?.popViewController(animated: true)
    }
    
    @objc func editMapAction() {
        Mixpanel.mainInstance().track(event: "EnterEditMapController")
        let editVC = EditMapController(mapData: mapData!)
        editVC.customMapVC = self
        editVC.modalPresentationStyle = .fullScreen
        present(editVC, animated: true)
    }
}

extension CustomMapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : mapData?.postIDs.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "CustomMapHeaderCell" : "CustomMapBodyCell", for: indexPath)
        if let headerCell = cell as? CustomMapHeaderCell {
            headerCell.cellSetup(userProfile: userProfile!, mapData: mapData)
            if mapData!.memberIDs.contains(UserDataModel.shared.userInfo.id!) {
                headerCell.actionButton.addTarget(self, action: #selector(editMapAction), for: .touchUpInside)
            }
            return headerCell
        } else if let bodyCell = cell as? CustomMapBodyCell {
            bodyCell.cellSetup(userProfile: userProfile!, postID: mapData?.postIDs[indexPath.row])
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

extension CustomMapController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if topYContentOffset != nil && containerDrawerView?.status == .Top {
            // Disable the bouncing effect when scroll view is scrolled to top
            if scrollView.contentOffset.y <= topYContentOffset! {
                scrollView.contentOffset.y = topYContentOffset!
                containerDrawerView?.canDrag = false
                containerDrawerView?.swipeToNextState = false
            }
            // Show navigation bar
            if scrollView.contentOffset.y > topYContentOffset! {
                barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
                titleLabel.text = scrollView.contentOffset.y > 0 ? mapData?.mapName : ""
            }
        }
        
        // Get middle y content offset
        if middleYContentOffset == nil {
            middleYContentOffset = scrollView.contentOffset.y
        }
        
        // Set scroll view content offset when in transition
        if
            middleYContentOffset != nil &&
            topYContentOffset != nil &&
            scrollView.contentOffset.y <= middleYContentOffset! &&
            containerDrawerView!.slideView.frame.minY >= middleYContentOffset! - topYContentOffset!
        {
            scrollView.contentOffset.y = middleYContentOffset!
        }
        
        // Whenever drawer view is not in top position, scroll to top, disable scroll and enable drawer view swipe to next state
        if containerDrawerView?.status != .Top {
            customMapCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            customMapCollectionView.isScrollEnabled = false
            containerDrawerView?.swipeToNextState = true
        }
    }
}

extension CustomMapController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Swipe up y translation < 0
        // Swipe down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y
        
        // Get the initial Top y position contentOffset
        if containerDrawerView?.status == .Top && topYContentOffset == nil {
            topYContentOffset = customMapCollectionView.contentOffset.y
        }
        
        // Enter full screen then enable collection view scrolling and determine if need drawer view swipe to next state feature according to user swipe direction
        if
            topYContentOffset != nil &&
            containerDrawerView?.status == .Top &&
            customMapCollectionView.contentOffset.y <= topYContentOffset!
        {
            containerDrawerView?.swipeToNextState = yTranslation > 0 ? true : false
        }

        // Preventing the drawer view to be dragged when it's status is top and user is scrolling down
        if
            containerDrawerView?.status == .Top &&
            customMapCollectionView.contentOffset.y > topYContentOffset ?? -91 &&
            yTranslation > 0 &&
            containerDrawerView?.swipeToNextState == false
        {
            containerDrawerView?.canDrag = false
            containerDrawerView?.slideView.frame.origin.y = 0
        }
        
        // Reset drawer view varaiables when the drawer view is on top and user swipes down
        if customMapCollectionView.contentOffset.y <= topYContentOffset ?? -91 && yTranslation > 0 {
            containerDrawerView?.canDrag = true
            barBackButton.isHidden = true
        }
        
        // Need to prevent content in collection view being scrolled when the status of drawer view is top but frame.minY is not 0
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
