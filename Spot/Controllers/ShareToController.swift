//
//  ShareToViewController.swift
//  Spot
//
//  Created by Kenny Barone on 5/25/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI
import SnapKit

class ShareToController: UIViewController {
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore = Firestore.firestore()
    
    var newMap: CustomMap?
    private lazy var customMaps: [CustomMap] = []
    
    private var buttonView: UIView!
    private var shareButton: UIButton!
    private var tableView: UITableView!
    private var heightConstraint: Constraint? = nil
    
    private var progressBar: UIView!
    private var progressFill: UIView!
    
    /// tableViewConstraint helpers
    let rowHeight: CGFloat = 63
    let headerHeight: CGFloat = 54
    let topBoundary: CGFloat = 120
    let bottomBoundary: CGFloat = 138
    
    let backgroundColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1)
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
            
        addButtons()
        addTableView()
        addProgressBar()
        
        DispatchQueue.global(qos: .userInitiated).async { self.getCustomMaps() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        view.backgroundColor = backgroundColor
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func setUpNavBar() {

        navigationItem.title = "Share to"
        
        /// set title to black
        if let appearance = navigationController?.navigationBar.standardAppearance {
            appearance.titleTextAttributes[.foregroundColor] = UIColor.black
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
        }
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.removeBackgroundImage()
        navigationController?.navigationBar.removeShadow()
        
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.barTintColor = .clear
        
        let barButtonItem = UIBarButtonItem(image: UIImage(named: "BackArrowDark"), style: .plain, target: self, action: #selector(backTap(_:)))
        navigationItem.leftBarButtonItem = barButtonItem
    }
    
    func addButtons() {
        /// work bottom to top laying out views
        shareButton = UIButton {
            $0.setImage(UIImage(named: "ShareButton"), for: .normal)
            $0.addTarget(self, action: #selector(shareTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        shareButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-48)
            $0.width.equalTo(240)
            $0.height.equalTo(60)
            $0.centerX.equalToSuperview()
        }
    }
    
    func addTableView() {
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = nil
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.showsVerticalScrollIndicator = false
        tableView.isScrollEnabled = false
        tableView.register(CustomMapsHeader.self, forHeaderFooterViewReuseIdentifier: "MapsHeader")
        tableView.register(CustomMapUploadCell.self, forCellReuseIdentifier: "MapCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(shareButton.snp.top).offset(-30)
            $0.top.greaterThanOrEqualToSuperview().offset(topBoundary)
            $0.height.equalTo(80) /// just big enough for header to start
        }
    }
    
    func addProgressBar() {
        progressBar = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
            $0.layer.cornerRadius = 6
            $0.layer.borderWidth = 2
            $0.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
            $0.isHidden = true
            view.addSubview($0)
        }
        progressBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(50)
            $0.bottom.equalTo(shareButton.snp.top).offset(-20)
            $0.height.equalTo(18)
        }
        
        progressFill = UIView {
            $0.frame = CGRect(x: 1, y: 1, width: 0, height: 16)
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 6
            progressBar.addSubview($0)
        }
        progressFill.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(1)
            $0.width.equalTo(0)
            $0.height.equalTo(16)
        }
    }
    
    func getCustomMaps() {
        let db = Firestore.firestore()
        let query = db.collection("maps").whereField("memberIDs", arrayContains: uid)
        
        query.getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            
            var index = 0
            for doc in docs {
                do {
                    let unwrappedInfo = try doc.data(as: CustomMap.self)
                    guard let mapInfo = unwrappedInfo else { index += 1; if index == docs.count { self.reloadTable() }; return }
                    index += 1
                    self.customMaps.append(mapInfo)
                    if index == docs.count { self.reloadTable(); return }
                } catch {
                    index += 1; if index == docs.count { self.reloadTable(); return }
                }
            }
        }
    }
    
    func reloadTable() {
        DispatchQueue.main.async {
            let headerHeight: CGFloat = self.newMap == nil ? 84 : 30
            let height = (CGFloat(self.customMaps.count) * 63) + headerHeight
            let maxHeight = UIScreen.main.bounds.height - self.bottomBoundary - self.topBoundary
            self.tableView.snp.updateConstraints {
                $0.height.equalTo(min(height, maxHeight))
            }
            self.tableView.isScrollEnabled = height > maxHeight
            self.tableView.reloadData()
        }
    }
    
            
    @objc func shareTap(_ sender: UIButton) {
        
        shareButton.isEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false

        /// make sure all post values are set for upload
        /// make sure there is a spot object attached to this post if posting to a spot
        /// need to enable create new spot
        UploadPostModel.shared.setFinalPostValues()
        if newMap == nil && UploadPostModel.shared.mapObject != nil { UploadPostModel.shared.setFinalMapValues() }

        let uid = uid
        let post = UploadPostModel.shared.postObject!
        let spot = UploadPostModel.shared.spotObject
        let map = UploadPostModel.shared.mapObject
        let newMap = self.newMap != nil
        progressBar.isHidden = false
        
        let fullWidth = self.progressBar.bounds.width - 2
        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadPostImage(post.postImage, postID: post.id!, progressFill: self.progressFill, fullWidth: fullWidth) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                
                if imageURLs.isEmpty && failed {
                    self.runFailedUpload()
                    return
                }
                
                UploadPostModel.shared.postObject.imageURLs = imageURLs
                UploadPostModel.shared.postObject.timestamp = Firebase.Timestamp(date: Date())
                let post = UploadPostModel.shared.postObject!
                
                self.uploadPost(post: post)

                if spot != nil {
                    var spot = spot!
                    spot.imageURL = imageURLs.first ?? ""
                    self.uploadSpot(post: post, spot: spot, submitPublic: false)
                }
                
                if map != nil {
                    var map = map!
                    if map.imageURL == "" { map.imageURL = imageURLs.first ?? "" }
                    self.uploadMap(map: map, newMap: newMap, post: post)
                }
                
                let visitorList = spot?.visitorList ?? []
                self.setUserValues(poster: uid, post: post, spotID: spot?.id ?? "", visitorList: visitorList, mapID: map?.id ?? "")
                
                UploadPostModel.shared.destroy()
                
                /// enable upload animation to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.popToMap()
                }
            }
        } 
    }
            
    func runFailedUpload() {
        showFailAlert()
        /// save to drafts
    }
    
    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style{
            case .default:
                self.popToMap()
            case .cancel:
                self.popToMap()
            case .destructive:
                self.popToMap()
            @unknown default:
                fatalError()
            }}))
        present(alert, animated: true, completion: nil)
    }

    @objc func backTap(_ sender: UIBarButtonItem) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func popToMap() {
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}

extension ShareToController: NewMapDelegate {
    func finishPassing(map: CustomMap) {
        newMap = map
        customMaps.append(map)
        selectMap(map: map)
    }
    
    func selectMap(map: CustomMap) {
        UploadPostModel.shared.mapObject = map
        UploadPostModel.shared.postObject.mapID = map.id!
        UploadPostModel.shared.postObject.mapName = map.mapName
        DispatchQueue.main.async { self.reloadTable() }
    }
    
    func deselectMap(map: CustomMap) {
        UploadPostModel.shared.mapObject = nil
        UploadPostModel.shared.postObject.mapID = ""
        UploadPostModel.shared.postObject.mapName = ""
        DispatchQueue.main.async { self.reloadTable() }
    }
}

extension ShareToController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return customMaps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell", for: indexPath) as? CustomMapUploadCell {
            let map = customMaps[indexPath.row]
            cell.setUp(map: map, selected: UploadPostModel.shared.postObject.mapID == map.id!)
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeight
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return newMap == nil ? headerHeight : 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "MapsHeader") as? CustomMapsHeader else { return UIView() }
        return header
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let map = customMaps[indexPath.row]
        map.id == UploadPostModel.shared.postObject.mapID ? deselectMap(map: map) : selectMap(map: map)
    }
}

class CustomMapsHeader: UITableViewHeaderFooterView {
    var newMapButton: UIButton!
    var plusIcon: UIImageView!
    var mapLabel: UILabel!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = nil
        self.backgroundView = backgroundView

        newMapButton = UIButton {
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.addTarget(self, action: #selector(newMapTap(_:)), for: .touchUpInside)
            $0.layer.cornerRadius = 11
            addSubview($0)
        }

        newMapButton.snp.makeConstraints {
            $0.leading.equalTo(17)
            $0.top.equalTo(0)
            $0.width.equalTo(119)
            $0.height.equalTo(38)
        }
        
        plusIcon = UIImageView {
            $0.image = UIImage(named: "PlusIcon")
            newMapButton.addSubview($0)
        }
        plusIcon.snp.makeConstraints {
            $0.leading.top.equalTo(12)
            $0.width.height.equalTo(15)
        }
        
        mapLabel = UILabel {
         //   $0.frame = CGRect(x: plusIcon.frame.maxX + 8, y: 10, width: 80, height: 19)
            $0.text = "New map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 15.5)
            newMapButton.addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(plusIcon.snp.trailing).offset(8)
            $0.top.equalTo(10)
            $0.width.equalTo(80)
            $0.height.equalTo(19)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func newMapTap(_ sender: UIButton) {
        if let shareVC = viewContainingController() as? ShareToController {
            if let newMapVC = shareVC.storyboard?.instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
                newMapVC.delegate = shareVC
                shareVC.present(newMapVC, animated: true)
            }
        }
    }
}

class CustomMapUploadCell: UITableViewCell {
    var pillView: UIView!
    var mapImage: UIImageView!
    var nameLabel: UILabel!
    var selectedImage: UIImageView!
    
    func setUp(map: CustomMap, selected: Bool) {
        backgroundColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1)
        selectionStyle = .none
        
        pillView = UIView {
            $0.frame = CGRect(x: 15, y: 5, width: UIScreen.main.bounds.width - 30, height: 53)
            $0.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
            $0.layer.cornerRadius = 12
            contentView.addSubview($0)
        }
        
        mapImage = UIImageView {
            $0.frame = CGRect(x: 9, y: 9, width: 34, height: 34)
            $0.layer.cornerRadius = 17
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill

            let url = map.imageURL
            if map.coverImage != UIImage () {
                $0.image = map.coverImage
            } else if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                $0.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
            pillView.addSubview($0)
        }
        
        nameLabel = UILabel {
            $0.frame = CGRect(x: mapImage.frame.maxX + 8, y: 17, width: pillView.bounds.width - 100, height: 18)
            $0.text = map.mapName
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            pillView.addSubview($0)
        }
        
        let buttonImage = selected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
        selectedImage = UIImageView {
            $0.frame = CGRect(x: pillView.bounds.width - 43, y: 12, width: 29, height: 29)
            $0.image = buttonImage
            pillView.addSubview($0)
        }
    }
}
