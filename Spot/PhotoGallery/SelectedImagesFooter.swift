//
//  SelectedImagesDrawer.swift
//  Spot
//
//  Created by Kenny Barone on 7/11/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Mixpanel
import UIKit

class SelectedImagesFooter: UICollectionReusableView {
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout {
            $0.itemSize = CGSize(width: 67, height: 79)
            $0.minimumInteritemSpacing = 12
            $0.scrollDirection = .horizontal
        }
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = nil
        view.showsHorizontalScrollIndicator = false
        view.register(SelectedImageCell.self, forCellWithReuseIdentifier: "ImageCell")
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        view.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        view.delegate = self
        view.dataSource = self
        view.dragInteractionEnabled = true
        return view
    }()

    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        return view
    }()

    private lazy var detailView = UIView()

    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.575, green: 0.575, blue: 0.575, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Medium", size: 14)
        return label
    }()

    private lazy var nextButton: FooterNextButton = {
        let button = FooterNextButton()
        button.addTarget(self, action: #selector(nextTap(_:)), for: .touchUpInside)
        return button
    }()

    lazy var imageCount: Int = 0 {
        didSet {
            detailLabel.text = imageCount > 1 ? "Drag and drop to reorder" : "Select up to 5 photos"
            nextButton.isEnabled = imageCount > 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        addInitialViews()
    }

    func addInitialViews() {
        addSubview(detailView)
        detailView.snp.updateConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(12)
            $0.height.equalTo(100)
        }

        detailView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(7)
            $0.height.equalTo(18)
        }

        nextButton.isEnabled = false
        detailView.addSubview(nextButton)
        nextButton.snp.makeConstraints {
            $0.top.equalToSuperview().offset(2)
            $0.trailing.equalToSuperview().inset(15)
            $0.width.equalTo(94)
            $0.height.equalTo(40)
        }
    }

    func setUp() {
        let imageSelected = !UploadPostModel.shared.selectedObjects.isEmpty
        let removing = !imageSelected && collectionView.superview != nil
        let adding = imageSelected && collectionView.superview == nil

        collectionView.removeFromSuperview()
        separatorLine.removeFromSuperview()

        if imageSelected {
            collectionView.dragDelegate = self
            collectionView.dropDelegate = self
            addSubview(collectionView)
            collectionView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.top.equalTo(11)
                $0.height.equalTo(79)
            }
            collectionView.reloadData()

            addSubview(separatorLine)
            separatorLine.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.top.equalTo(collectionView.snp.bottom).offset(11)
                $0.height.equalTo(1)
            }
        }

        let detailY = imageSelected ? 112 : 12
        // animate view change when adding or removing the collection
        if removing || adding {
            UIView.animate(withDuration: 0.3) {
                self.detailView.snp.updateConstraints { $0.top.equalTo(detailY) }
                self.layoutIfNeeded()
            }
        }

        imageCount = UploadPostModel.shared.selectedObjects.count
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
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as? SelectedImageCell else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Mixpanel.mainInstance().track(event: "GalleryFooterPreviewTap")

        var object: ImageObject?
        var galleryIndex = 0

        guard let cell = collectionView.cellForItem(at: IndexPath(row: indexPath.row, section: 0)) as? SelectedImageCell else { return }
        guard let index = UploadPostModel.shared.imageObjects.firstIndex(where: { $0.image.id == cell.assetID }) else { return }

        object = UploadPostModel.shared.imageObjects[index].image
        galleryIndex = index

        let imagePreview = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        imagePreview.alpha = 0.0
        imagePreview.delegate = self
        imagePreview.animateFromFooter = true

        if let window = UIApplication.shared.keyWindow, let object {
            window.addSubview(imagePreview)
            let frame = cell.superview?.convert(cell.frame, to: nil) ?? CGRect()
            imagePreview.imageExpand(originalFrame: frame, selectedIndex: 0, galleryIndex: galleryIndex, imageObjects: [object])
        }
    }

    private func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        if let item = coordinator.items.first, let sourceIndexPath = item.sourceIndexPath {
            let selectedCount = UploadPostModel.shared.selectedObjects.count
            // check that index is in bounds and execute drag and drop
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

extension SelectedImagesFooter: ImagePreviewDelegate {
    func select(galleryIndex: Int) {
        if let gallery = viewContainingController() as? PhotoGalleryController {
            gallery.select(index: galleryIndex)
        }
    }

    func deselect(galleryIndex: Int) {
        if let gallery = viewContainingController() as? PhotoGalleryController {
            gallery.deselect(index: galleryIndex)
        }
    }
}

class SelectedImageCell: UICollectionViewCell {
    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 1
        contentView.addSubview(view)
        return view
    }()
    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.setImage(UIImage(named: "CancelButton"), for: .normal)
        button.layer.cornerRadius = 1
        button.imageEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        button.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        return button
    }()
    lazy var assetID: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalToSuperview()
        }

        contentView.addSubview(cancelButton)
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

class FooterNextButton: UIButton {
    override var isEnabled: Bool {
        didSet {
            backgroundColor = isEnabled ? UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1) : UIColor(red: 0.367, green: 0.367, blue: 0.367, alpha: 1)
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
