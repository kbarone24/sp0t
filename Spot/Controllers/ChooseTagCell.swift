//
//  ChooseTagCell.swift
//  Spot
//
//  Created by Kenny Barone on 5/4/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ChooseTagCell: UITableViewCell {
    
    var chooseTagCollection: UICollectionView!
    let tagWidth: CGFloat = 46
    let itemsInTagSection = 6
    var interitemSpacing: CGFloat = 0
    
    var tags: [Tag] = []
    var selectedTag = ""
    
    func setUp(tags: [Tag], selectedTag: String) {
        
        backgroundColor = nil
        self.tags = tags
        self.selectedTag = selectedTag

        /// tag select reload
        if interitemSpacing != 0 {
            DispatchQueue.main.async { self.chooseTagCollection.reloadData() }
            return
        }
        
        /// divide (total width taken up by tags - min insets) by number of spaces (5)
        let maxSpacing = ((UIScreen.main.bounds.width - 0.1) - (tagWidth * 6) - 36) / 5
        interitemSpacing = min(maxSpacing, 10)
        
        let tagLayout = UICollectionViewFlowLayout()
        tagLayout.minimumLineSpacing = 8
        tagLayout.minimumInteritemSpacing = interitemSpacing
        
        chooseTagCollection = UICollectionView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: bounds.height), collectionViewLayout: tagLayout)
        chooseTagCollection.backgroundColor = .white
        chooseTagCollection.delegate = self
        chooseTagCollection.dataSource = self
        chooseTagCollection.register(UploadTagCell.self, forCellWithReuseIdentifier: "TagCell")
        chooseTagCollection.setCollectionViewLayout(tagLayout, animated: false)
        chooseTagCollection.tag = 1
        contentView.addSubview(chooseTagCollection)
    }
}

extension ChooseTagCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        min(Int((Float16(tags.count)/Float16(itemsInTagSection)).rounded(.up)), 6)
        /// first 6 rows of random tags, for now
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(itemsInTagSection, tags.count - (section * itemsInTagSection))
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as? UploadTagCell else { return UICollectionViewCell() }

        let row = indexPath.section * itemsInTagSection + indexPath.row
        let selected = tags[row].name == selectedTag
        cell.setUp(tag: tags[row], selected: selected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 46, height: 46)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        let rowsInSection = collectionView.numberOfItems(inSection: section)
        var sectionWidth: CGFloat = 0
        for i in 0...rowsInSection - 1 {
            /// add cell + space in between cell and next if this isn't the last cell in the section
            sectionWidth += tagWidth + (i == rowsInSection - 1 ? 0 : interitemSpacing)
        }
        
        let minInset: CGFloat = 18
        let maxInset: CGFloat = min(34, UIScreen.main.bounds.width - (tagWidth * 6) - (interitemSpacing * 5) - minInset - 0.1)

        
        let evenSection = section % 2 == 0
        return UIEdgeInsets(top: 8, left: evenSection ? maxInset : minInset, bottom: 0, right: evenSection ? minInset : maxInset)
    }
}

class UploadTagCell: UICollectionViewCell {
    
    var tagImage: UIImageView!
    var postTag: Tag!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderWidth = 3
        layer.cornerRadius = 15
        layer.cornerCurve = .continuous
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(tag: Tag, selected: Bool) {
        
        postTag = tag
        
        if tagImage != nil { tagImage.image = UIImage() }
        tagImage = UIImageView {
            $0.frame = CGRect(x: bounds.width/2 - 13.5, y: bounds.height/2 - 13.5, width: 27, height: 27)
            $0.image = tag.image
            addSubview($0)
        }

        backgroundColor = selected ? UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.3) : .white
        layer.borderColor = selected ? UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1.0).cgColor : UIColor.white.cgColor
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        contentView.addGestureRecognizer(tap)
     }
    
    @objc func tap(_ sender: UITapGestureRecognizer) {
        guard let chooseCell = viewContainingController() as? PostInfoController else { return }
        chooseCell.selectTag(name: postTag.name)
    }
}
