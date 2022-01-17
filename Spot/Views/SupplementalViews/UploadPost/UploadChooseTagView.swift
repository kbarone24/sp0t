//
//  UploadChooseTagCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

protocol ChooseTagDelegate {
    func finishPassingTag(tag: Tag)
}

class UploadChooseTagView: UIView {
    
    var selectedIndex = 0
    var categoryCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var chooseTagCollection: UICollectionView  = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    
    var categories: [TagCategory] = [TagCategory(name: "RANDOM", index: 0), TagCategory(name: "ACTIVITY", index: 1), TagCategory(name: "EAT & DRINK", index: 2), TagCategory(name: "LIFE", index: 3), TagCategory(name: "NATURE", index: 4)]
    
    var filteredTags: [Tag] = []
   
    var tagWidth: CGFloat = 0
    var delegate: ChooseTagDelegate?
    
    let itemsInTagSection = 6

    override init(frame: CGRect) {
        super.init(frame: frame)
        Mixpanel.mainInstance().track(event: "UploadChooseTagOpen", properties: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp() {
        
        backgroundColor = nil
        
        filteredTags = UploadImageModel.shared.sortedTags
        
        tagWidth = (UIScreen.main.bounds.width - 84) / 6 - 0.1
        
        let categoryLayout = UICollectionViewFlowLayout()
        categoryLayout.minimumLineSpacing = 10
        categoryLayout.minimumInteritemSpacing = UserDataModel.shared.screenSize == 2 ? 15 : 10
        categoryLayout.scrollDirection = .horizontal
        
        /// add extra container to show as the background view -> touch area was too tight on the main view so this expands the view up by 20pts and wont close on an accidental mask tap
        let backgroundContainer = UIView(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: bounds.height - 20))
        backgroundContainer.backgroundColor = UIColor(named: "SpotBlack")
        backgroundContainer.tag = 100
        addSubview(backgroundContainer)
                
        categoryCollection.frame = CGRect(x: 0, y: 8, width: UIScreen.main.bounds.width, height: 43)
        categoryCollection.backgroundColor = nil
        categoryCollection.delegate = self
        categoryCollection.dataSource = self
        categoryCollection.register(TagCategoryCell.self, forCellWithReuseIdentifier: "CategoryCell")
        categoryCollection.setCollectionViewLayout(categoryLayout, animated: false)
        categoryCollection.tag = 0
        categoryCollection.isScrollEnabled = false
        backgroundContainer.addSubview(categoryCollection)
        
        let tagLayout = UICollectionViewFlowLayout()
        tagLayout.minimumLineSpacing = 8
        tagLayout.minimumInteritemSpacing = 8
        
        chooseTagCollection.frame = CGRect(x: 0, y: categoryCollection.frame.maxY + 4, width: UIScreen.main.bounds.width, height: 212)
        chooseTagCollection.backgroundColor = nil
        chooseTagCollection.delegate = self
        chooseTagCollection.dataSource = self
        chooseTagCollection.register(UploadTagCell.self, forCellWithReuseIdentifier: "TagCell")
        chooseTagCollection.setCollectionViewLayout(tagLayout, animated: false)
        chooseTagCollection.tag = 1
        backgroundContainer.addSubview(chooseTagCollection)
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(leftSwipe(_:)))
        leftSwipe.direction = .left
        chooseTagCollection.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(rightSwipe(_:)))
        rightSwipe.direction = .right
        chooseTagCollection.addGestureRecognizer(rightSwipe)

        chooseTagCollection.reloadData()
    }
        
    @objc func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex < categories.count - 1 { categoryTap(row: selectedIndex + 1) }
    }
    
    @objc func rightSwipe(_ sender: UISwipeGestureRecognizer) {
        if selectedIndex > 0 { categoryTap(row: selectedIndex - 1) }
    }
}

extension UploadChooseTagView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionView.tag == 0 ? 5 : min(itemsInTagSection, filteredTags.count - (section * itemsInTagSection))
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        /// each row has its own section to allow for custom section insets
        return collectionView.tag == 0 ? 1 : min(Int((Float16(filteredTags.count)/Float16(itemsInTagSection)).rounded(.up)), 4)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch collectionView.tag {
            
        case 0:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as? TagCategoryCell else { return UICollectionViewCell() }
            cell.setUp(category: categories[indexPath.row])
            return cell
            
        case 1:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as? UploadTagCell else { return UICollectionViewCell() }

            let row = indexPath.section * itemsInTagSection + indexPath.row
            cell.setUp(tag: filteredTags[row])
            
            let selected = filteredTags[row].name == UploadImageModel.shared.selectedTag
            cell.setAlphas(alpha: 1.0, selected: selected)
            return cell

        default: return UICollectionViewCell()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let selectedTag = UploadImageModel.shared.selectedTag
        
        switch collectionView.tag {
            
        case 0: categoryTap(row: indexPath.row)
            
        case 1:
            let row = indexPath.section * itemsInTagSection + indexPath.row
            var tag = filteredTags[row]
            tag.selected = tag.name != selectedTag
            delegate?.finishPassingTag(tag: tag)
        
        default: return
        }
    }
    
    func categoryTap(row: Int) {
        
        let selectedTag = UploadImageModel.shared.selectedTag

        for i in 0...categories.count - 1 { categories[i].selected = false }
        categories[row].selected = true
        selectedIndex = row
        
        if selectedIndex == 0 {
            /// random sorting, shuffle if not selected
            /// shuffle model tags as well to keep order consistent for reopen
            if selectedTag == "" { UploadImageModel.shared.sortedTags = UploadImageModel.shared.sortedTags.shuffled() }
            filteredTags = UploadImageModel.shared.sortedTags
            
        } else if selectedIndex > 0 {
            filteredTags = UploadImageModel.shared.tags() /// use static tags to preserve sorted order
            filteredTags = filteredTags.filter({$0.category == selectedIndex})
        }
        /// move selected tag first
        DispatchQueue.main.async { self.categoryCollection.reloadData(); self.chooseTagCollection.reloadData() }
        Mixpanel.mainInstance().track(event: "UploadTagCategorySelected", properties: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.tag == 0 ? getCategorySize(category: categories[indexPath.row]) : CGSize(width: tagWidth, height: 45)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        
        switch collectionView.tag {
        case 0:
            var sectionWidth: CGFloat = 0
            let interitemSpacing: CGFloat = UserDataModel.shared.screenSize == 2 ? 15 : 10
            for i in 0...categories.count - 1 {
                /// add width in between categories if this isn't the last cell in the section
                sectionWidth += getCategorySize(category: categories[i]).width + (i == categories.count - 1 ? 0 : interitemSpacing)
            }
            let inset = max((UIScreen.main.bounds.width - sectionWidth)/2, 12)
            return UIEdgeInsets(top: 5, left: inset, bottom: 0, right: inset)

        case 1:
            let rowsInSection = collectionView.numberOfItems(inSection: section)
            var sectionWidth: CGFloat = 0
            for i in 0...rowsInSection - 1 {
                /// add cell + space in between cell and next if this isn't the last cell in the section
                sectionWidth += tagWidth + (i == rowsInSection - 1 ? 0 : 8)
            }
            let minInset: CGFloat = 16
            /// for consistent left align if final section
            let standardInset: CGFloat = UIScreen.main.bounds.width - (CGFloat(itemsInTagSection) * tagWidth + 5 * 8) - minInset
            let maxInset: CGFloat = UIScreen.main.bounds.width - sectionWidth - minInset
            /// left align even sections and last section
            let evenSection = section % 2 == 0
            return UIEdgeInsets(top: 8, left: evenSection ? standardInset : minInset, bottom: 0, right: evenSection ? minInset : maxInset)
        default: return UIEdgeInsets()
        }
    }
    
    func getCategorySize(category: TagCategory) -> CGSize {
        
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 18))
        tempLabel.text = category.name
        tempLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        
        if category.index == 2 {
            let attString = NSMutableAttributedString(string: tempLabel.text!)
            attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCompactText-Semibold", size: 10) as Any, range: NSRange(location: 4, length: 1))
            tempLabel.attributedText = attString
        }
        
        tempLabel.sizeToFit()
        return CGSize(width: tempLabel.frame.width + 6, height: 30)
    }
}

class TagCategoryCell: UICollectionViewCell {
    
    var label: UILabel!
    var underLine: UIView!
    
    func setUp(category: TagCategory) {

        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 0, y: 6, width: bounds.width, height: 14))
        label.text = category.name
        label.textAlignment = .center
        label.textColor = category.selected ? .white : UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        
        /// make & smaller for eat & drink
        if category.index == 2 {
            let attString = NSMutableAttributedString(string: label.text!)
            attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCompactText-Semibold", size: 10) as Any, range: NSRange(location: 4, length: 1))
            label.attributedText = attString
        }
        
        addSubview(label)
        
        if underLine != nil { underLine.backgroundColor = nil }
        if category.selected {
            underLine = UIView(frame: CGRect(x: 2, y: label.frame.maxY + 3.5, width: bounds.width - 4, height: 2.25))
            underLine.backgroundColor = UIColor(named: "SpotGreen")
            underLine.layer.cornerRadius = 1
            underLine.layer.cornerCurve = .continuous
            addSubview(underLine)
        }
    }
}

class UploadTagCell: UICollectionViewCell {
    
    var tagImage: UIImageView!
    var postTag: Tag!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderWidth = 1
        layer.cornerRadius = 7.5
        layer.cornerCurve = .continuous
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(tag: Tag) {
        
        postTag = tag
        
        if tagImage != nil { tagImage.image = UIImage() }
        tagImage = UIImageView(frame: CGRect(x: bounds.width/2 - 13.5, y: bounds.height/2 - 13.5, width: 27, height: 27))
        tagImage.image = tag.image
        addSubview(tagImage)
    }
    
    func setAlphas(alpha: CGFloat, selected: Bool) {
        tagImage.alpha = alpha
        backgroundColor = selected ? UIColor(red: 0.00, green: 0.09, blue: 0.09, alpha: 1.00) : UIColor(red: 0.094, green: 0.094, blue: 0.094, alpha: 1).withAlphaComponent(alpha)
        layer.borderColor = selected ? UIColor(named: "SpotGreen")!.cgColor : UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: 1).cgColor
    }
}
