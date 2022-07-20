//
//  SelectedImagesDrawer.swift
//  Spot
//
//  Created by Kenny Barone on 7/11/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class SelectedImagesFooter: UICollectionReusableView {
    
    var collectionView: UICollectionView?
    var separatorLine: UIView!
    var detailView: UIView!
    var detailLabel: UILabel!
    var nextButton: UIButton!
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setUp()
    }
    
    func setUp() {
        let imageSelected = UploadPostModel.shared.selectedObjects.count > 0
        let removing = !imageSelected && collectionView != nil && collectionView?.superview != nil
        let adding = imageSelected && (collectionView == nil || collectionView?.superview == nil)
                
        if collectionView != nil { collectionView!.removeFromSuperview() }
        if separatorLine != nil { separatorLine.removeFromSuperview() }
        if imageSelected {
            let layout = UICollectionViewFlowLayout {
                $0.itemSize = CGSize(width: 67, height: 79)
                $0.minimumInteritemSpacing = 12
                $0.scrollDirection = .horizontal
            }
            collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView!.backgroundColor = nil
            collectionView!.showsHorizontalScrollIndicator = false
            collectionView!.register(SelectedImageCell.self, forCellWithReuseIdentifier: "ImageCell")
            collectionView!.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
            collectionView!.delegate = self
            collectionView!.dataSource = self
            collectionView!.allowsSelection = false
            collectionView!.dragInteractionEnabled = true
            collectionView!.dragDelegate = self
            collectionView!.dropDelegate = self
            addSubview(collectionView!)
            collectionView!.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.top.equalTo(11)
                $0.height.equalTo(79)
            }
            
            separatorLine = UIView {
                $0.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
                addSubview($0)
            }
            separatorLine.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.top.equalTo(collectionView!.snp.bottom).offset(11)
                $0.height.equalTo(1)
            }
        }
        
        let detailY = imageSelected ? 112 : 12
        // animate view change when adding or removing the collection
        if (removing || adding) && detailView != nil {
            UIView.animate(withDuration: 0.3) {
                self.detailView.snp.updateConstraints { $0.top.equalTo(detailY) }
                self.layoutIfNeeded()
            }
            nextButton.isEnabled = imageSelected
            return
        } else if detailView != nil {
            return
        }
        
        detailView = UIView {
            $0.backgroundColor = nil
            addSubview($0)
        }
        detailView.snp.updateConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(detailY)
            $0.height.equalTo(100)
        }
        
        let imageCount = UploadPostModel.shared.selectedObjects.count
        detailLabel = UILabel {
            $0.text = imageCount > 1 ? "Drag and drop to reorder" : "Select up to 5 photos"
            $0.textColor = UIColor(red: 0.575, green: 0.575, blue: 0.575, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14)
            detailView.addSubview($0)
        }
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(7)
            $0.height.equalTo(18)
        }
        
        nextButton = NextButton {
            $0.isEnabled = imageSelected
            $0.addTarget(self, action: #selector(nextTap(_:)), for: .touchUpInside)
            detailView.addSubview($0)
        }
        nextButton.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.trailing.equalToSuperview().inset(15)
            $0.height.equalTo(40)
            $0.width.equalTo(94)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func nextTap(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "ImagePreview") as? ImagePreviewController {
            if let galleryVC = viewContainingController() as? PhotoGalleryController {
                DispatchQueue.main.async { galleryVC.navigationController?.pushViewController(vc, animated: false) }
            }
        }
    }
}

extension SelectedImagesFooter: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return UploadPostModel.shared.selectedObjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! SelectedImageCell
        cell.setImageValues(object: UploadPostModel.shared.selectedObjects[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = UploadPostModel.shared.selectedObjects[indexPath.row].id
        let itemProvider = NSItemProvider(object: item as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        var destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            let row = collectionView.numberOfItems(inSection: 0)
            destinationIndexPath = IndexPath(item: row - 1, section: 0)
        }
        
        if coordinator.proposal.operation == .move {
            reorderItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
        }
    }
    
    private func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        if let item = coordinator.items.first, let sourceIndexPath = item.sourceIndexPath {
            let selectedCount = UploadPostModel.shared.selectedObjects.count
            /// check that index is in bounds and execute drag and drop
            if (sourceIndexPath.item >= 0 && sourceIndexPath.item < selectedCount) && (destinationIndexPath.item >= 0 && destinationIndexPath.item < selectedCount) {
                Mixpanel.mainInstance().track(event: "GalleryDragAndDrop")
                collectionView.performBatchUpdates {
                    let item = UploadPostModel.shared.selectedObjects.remove(at: sourceIndexPath.item)
                    UploadPostModel.shared.selectedObjects.insert(item, at: destinationIndexPath.item)
                    
                    collectionView.deleteItems(at: [sourceIndexPath])
                    collectionView.insertItems(at: [destinationIndexPath])
                }
                coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
            }
        }
    }
}

class SelectedImageCell: UICollectionViewCell {
    var cancelButton: UIButton!
    var imageView: UIImageView!
    var assetID: String!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if imageView != nil { imageView.image = UIImage(); imageView.removeFromSuperview() }
        imageView = UIImageView {
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            $0.layer.cornerRadius = 1
            contentView.addSubview($0)
        }
        imageView.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalToSuperview()
        }
        
        if cancelButton != nil { cancelButton.removeFromSuperview() }
        cancelButton = UIButton {
            $0.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            $0.setImage(UIImage(named: "CancelButton"), for: .normal)
            $0.layer.cornerRadius = 1
            $0.imageEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            contentView.addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.height.width.equalTo(23)
        }
    }
    
    func setImageValues(object: ImageObject) {
        imageView.image = object.stillImage
        assetID = object.id
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "GalleryCancelFromFooter")
        if let gallery = viewContainingController() as? PhotoGalleryController {
            gallery.deselectFromFooter(id: assetID)
        }
    }
}

class NextButton: UIButton {
    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? UIColor(named: "SpotGreen") : UIColor(red: 0.367, green: 0.367, blue: 0.367, alpha: 1)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setTitle("Next", for: .normal)
        setTitleColor(.black, for: .normal)
        titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        layer.cornerRadius = 7
        contentHorizontalAlignment = .center
        contentVerticalAlignment = .center
        imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
