//
//  ChooseMapController.swift
//  Spot
//
//  Created by Kenny Barone on 5/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseUI
import Foundation
import Mixpanel
import SnapKit
import UIKit

final class ChooseMapController: UIViewController {
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore = Firestore.firestore()

    var newMap: CustomMap?
    private lazy var customMaps: [CustomMap] = []

    private lazy var postButton: PostButton = {
        let button = PostButton()
        button.addTarget(self, action: #selector(postTap), for: .touchUpInside)
        return button
    }()
    private lazy var friendsMapButton = FriendsMapButton()
    private lazy var tableView = ChooseMapTableView()
    private lazy var bottomMask = UIView()
    private lazy var progressBar = ProgressBar()

    private var heightConstraint: Constraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        addButtons()
        addTableView()
        addProgressBar()

        DispatchQueue.global(qos: .userInitiated).async { self.getCustomMaps() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = .white
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ChooseMapOpen")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewDidLayoutSubviews() {
        addBottomMask()
    }

    func setUpNavBar() {
        navigationItem.title = "Post to maps"
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.addWhiteBackground()

        let barButtonItem = UIBarButtonItem(image: UIImage(named: "BackArrowDark"), style: .plain, target: self, action: #selector(backTap(_:)))
        navigationItem.leftBarButtonItem = barButtonItem

        if let mapNav = navigationController as? MapNavigationController {
            mapNav.requiredStatusBarStyle = .darkContent
        }

    }

    func addButtons() {
        // work bottom to top laying out views
        view.addSubview(postButton)
        postButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-48)
            $0.leading.trailing.equalToSuperview().inset(49)
            $0.height.equalTo(58)
        }

        friendsMapButton = FriendsMapButton {
            $0.addTarget(self, action: #selector(friendsMapTap), for: .touchUpInside)
            view.addSubview($0)
        }
        friendsMapButton.snp.makeConstraints {
            $0.top.equalTo(45)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(62)
        }
    }

    func addTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(friendsMapButton.snp.bottom).offset(38)
            $0.bottom.equalTo(postButton.snp.top)
        }
    }

    func addProgressBar() {
        progressBar.isHidden = true
        view.addSubview(progressBar)
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.bottom.equalTo(postButton.snp.top).offset(-20)
            $0.height.equalTo(18)
        }
    }

    func getCustomMaps() {
        newMap = UploadPostModel.shared.mapObject
        customMaps = UserDataModel.shared.userInfo.mapsList.filter({ $0.memberIDs.contains(UserDataModel.shared.uid) }).sorted(by: { $0.userTimestamp.seconds > $1.userTimestamp.seconds })

        if var newMap {
            newMap.coverImage = UploadPostModel.shared.postObject?.postImage.first ?? UIImage() /// new map image not set when going through new map flow
            customMaps.insert(newMap, at: 0)
            if newMap.secret { toggleFriendsMap() }
        }

        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    func enablePostButton() {
        postButton.isEnabled = friendsMapButton.buttonSelected || UploadPostModel.shared.postObject?.mapID != ""
    }

    @objc func friendsMapTap() {
        toggleFriendsMap()
        HapticGenerator.shared.play(.light)
    }

    func toggleFriendsMap() {
        friendsMapButton.buttonSelected.toggle()
        UploadPostModel.shared.postObject?.hideFromFeed = !friendsMapButton.buttonSelected
        enablePostButton()
    }

    func addBottomMask() {
        bottomMask.isUserInteractionEnabled = false
        view.addSubview(bottomMask)
        view.bringSubviewToFront(postButton)
        view.bringSubviewToFront(progressBar)
        _ = CAGradientLayer {
            $0.frame = CGRect(x: 0, y: postButton.frame.minY - 120, width: UIScreen.main.bounds.width, height: 120)
            $0.colors = [
                UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0).cgColor,
                UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 0.0)
            $0.endPoint = CGPoint(x: 0.5, y: 1.0)
            $0.locations = [0, 1]
            bottomMask.layer.addSublayer($0)
        }
    }

    @objc func postTap() {
        postButton.isEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false

        /// make sure all post values are set for upload
        /// make sure there is a spot object attached to this post if posting to a spot
        UploadPostModel.shared.setFinalPostValues()
        if UploadPostModel.shared.mapObject != nil { UploadPostModel.shared.setFinalMapValues() }
        let newMap = self.newMap != nil

        progressBar.isHidden = false
        view.bringSubviewToFront(progressBar)
        let fullWidth = self.progressBar.bounds.width - 2

        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadPostImage(
                images: UploadPostModel.shared.postObject?.postImage ?? [],
                postID: UploadPostModel.shared.postObject?.id ?? "",
                progressFill: self.progressBar.progressFill,
                fullWidth: fullWidth) { [weak self] imageURLs, failed in
                    
                guard let self = self else { return }
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUpload")
                    self.runFailedUpload()
                    return
                }
                UploadPostModel.shared.postObject?.imageURLs = imageURLs
                self.uploadPostToDB(newMap: newMap)
                /// enable upload animation to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    HapticGenerator.shared.play(.soft)
                    self.popToMap()
                }
            }
        }
    }

    func runFailedUpload() {
        showFailAlert()
        UploadPostModel.shared.saveToDrafts()
    }

    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style {
            case .default:
                self.popToMap()
            case .cancel:
                self.popToMap()
            case .destructive:
                self.popToMap()
            @unknown default:
                fatalError("unknown alert action")
            }}))
        present(alert, animated: true, completion: nil)
    }

    @objc func backTap(_ sender: UIBarButtonItem) {
        /// reset new map object to show empty selection next time user comes through
        UploadPostModel.shared.setMapValues(map: nil)
        self.navigationController?.popViewController(animated: true)
    }

    func popToMap() {
        UploadPostModel.shared.destroy()
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}

extension ChooseMapController: NewMapDelegate {
    func finishPassing(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapCreateNew")
        // only select if map was just created, update on edit
        if newMap == nil {
            customMaps.insert(map, at: 0)
        } else {
            customMaps[0] = map
        }

        newMap = map
        selectMap(map: map)
    }

    func selectMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapSelectMap")
        UploadPostModel.shared.setMapValues(map: map)
        /// if private map, make sure mymapbutton is deselected, if public, make sure selected
        if map.secret && friendsMapButton.buttonSelected { toggleFriendsMap() }
        DispatchQueue.main.async { self.tableView.reloadData() }
        enablePostButton()
    }

    func deselectMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "ChooseMapDeselectMap")
        UploadPostModel.shared.setMapValues(map: nil)

        DispatchQueue.main.async { self.tableView.reloadData() }
        enablePostButton()
    }
}

extension ChooseMapController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newMap != nil ? customMaps.count : customMaps.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath) as? CustomMapUploadCell {
            let index = newMap != nil ? indexPath.row : indexPath.row - 1
            /// map will be nil for row "-1" which represents the add spot row
            let map = customMaps[safe: index]
            let selected = UploadPostModel.shared.postObject?.mapID == map?.id ?? "_"
            cell.setUp(map: map, selected: selected, newMap: newMap != nil)
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let index = indexPath.row - 1
        let map = customMaps[safe: index]
        if let map = map {
            if map.id == UploadPostModel.shared.postObject?.mapID ?? "" {
                deselectMap(map: map)
            } else { selectMap(map: map) }
            HapticGenerator.shared.play(.light)

        } else if map == nil, let newMapVC = storyboard?.instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
            newMapVC.delegate = self
            newMapVC.mapObject = newMap
            DispatchQueue.main.async { self.present(newMapVC, animated: true) }
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MapsHeader") as? CustomMapsHeader else { return UIView() }
        return header
    }
}
