//
//  SelectedImagesDrawer.swift
//  Spot
//
//  Created by Kenny Barone on 7/11/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SelectedImagesFooter: UICollectionReusableView {
    
    var imagesCollection: UICollectionView?
    var separatorLine: UIView!
    var detailLabel: UILabel!
    var nextButton: UIButton!
    
    override func layoutSubviews() {
        super.layoutSubviews()
    //    print("laout sub")
    //    setUp()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setUp()
    }
    
    func setUp() {
        let imageSelected = UploadPostModel.shared.selectedObjects.count > 0
                
        if imagesCollection != nil { imagesCollection!.removeFromSuperview() }
        if separatorLine != nil { separatorLine.removeFromSuperview() }
        if imageSelected {
            let layout = UICollectionViewFlowLayout {
                $0.itemSize = CGSize(width: 67, height: 79)
                $0.minimumInteritemSpacing = 12
                $0.scrollDirection = .horizontal
            }
            imagesCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
            imagesCollection!.backgroundColor = nil
            imagesCollection!.showsHorizontalScrollIndicator = false
            imagesCollection!.register(SelectedImageCell.self, forCellWithReuseIdentifier: "ImageCell")
            imagesCollection!.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
            imagesCollection!.delegate = self
            imagesCollection!.dataSource = self
            imagesCollection!.allowsSelection = false
            addSubview(imagesCollection!)
            imagesCollection!.snp.makeConstraints {
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
                $0.top.equalTo(imagesCollection!.snp.bottom).offset(11)
                $0.height.equalTo(1)
            }
        }
        
        let detailY = imageSelected ? 112 : 12
        let detailView = UIView {
            $0.backgroundColor = nil
            addSubview($0)
        }
        detailView.snp.updateConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(detailY)
            $0.height.equalTo(100)
        }
        
        if detailLabel != nil { detailLabel.text = ""; detailLabel.removeFromSuperview() }
        detailLabel = UILabel {
            $0.text = "Select up to 5 photos"
            $0.textColor = UIColor(red: 0.575, green: 0.575, blue: 0.575, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14)
            detailView.addSubview($0)
        }
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(7)
            $0.height.equalTo(18)
        }
        
        if nextButton != nil { nextButton.setTitle("", for: .normal); nextButton.removeFromSuperview() }
        nextButton = UIButton {
            $0.backgroundColor = imageSelected ? UIColor(named: "SpotGreen") : UIColor(red: 0.367, green: 0.367, blue: 0.367, alpha: 1)
            $0.setTitle("Next", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            $0.addTarget(self, action: #selector(nextTap(_:)), for: .touchUpInside)
            $0.layer.cornerRadius = 7
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            $0.isEnabled = imageSelected
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
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

extension SelectedImagesFooter: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return UploadPostModel.shared.selectedObjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! SelectedImageCell
        cell.setImageValues(object: UploadPostModel.shared.selectedObjects[indexPath.row])
        return cell
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
        if let gallery = viewContainingController() as? PhotoGalleryController {
            gallery.deselectFromFooter(id: assetID)
        }
    }
}
