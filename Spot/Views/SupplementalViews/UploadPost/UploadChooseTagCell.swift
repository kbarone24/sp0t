//
//  UploadChooseTagCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadChooseTagCell: UITableViewCell {
    
    var topLine: UIView!
    var titleLabel: UILabel!

    var chooseTagCollection: UICollectionView  = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var tags: [Tag] = [Tag(name: "Active"), Tag(name: "Art"), Tag(name: "Boogie"), Tag(name: "Chill"), Tag(name: "Coffee"), Tag(name: "Drink"), Tag(name: "Eat"), Tag(name: "Historic"), Tag(name: "Home"), Tag(name: "Nature"), Tag(name: "Shop"), Tag(name: "Smoke"), Tag(name: "Sunset"), Tag(name: "Swim"), Tag(name: "View"), Tag(name: "Weird")]
    

    func setUp() {
        
        backgroundColor = .black
        contentView.backgroundColor = .black
        
        resetView()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        contentView.addSubview(topLine)
        
        titleLabel = UILabel(frame: CGRect(x: 16, y: 12, width: 150, height: 18))
        titleLabel.text = "Add tag"
        titleLabel.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        titleLabel.font = UIFont(name: "SFCamera-Regular", size: 13.5)
        contentView.addSubview(titleLabel)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 40, height: 40)
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        
        chooseTagCollection.frame = CGRect(x: 0, y: 39, width: UIScreen.main.bounds.width, height: 89)
        chooseTagCollection.backgroundColor = nil
        chooseTagCollection.delegate = self
        chooseTagCollection.dataSource = self
        chooseTagCollection.register(UploadTagCell.self, forCellWithReuseIdentifier: "TagCell")
        chooseTagCollection.showsHorizontalScrollIndicator = false
        chooseTagCollection.setCollectionViewLayout(layout, animated: false)
        addSubview(chooseTagCollection)
        
        chooseTagCollection.reloadData()
    }
        
    func resetView() {
        if topLine != nil { topLine.backgroundColor = nil }
        if titleLabel != nil { titleLabel.text = "" }
    }
}

extension UploadChooseTagCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tags.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as? UploadTagCell else { return UICollectionViewCell() }
        cell.setUp(tag: tags[indexPath.row])
        
        let alpha: CGFloat = tags.contains(where: {$0.selected}) && !tags[indexPath.row].selected ? 0.6 : 1.0
        cell.setAlphas(alpha: alpha)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let uploadVC = viewContainingController() as? UploadPostController else { return }
        var tag = tags[indexPath.row]
        tag.selected = !tag.selected
        uploadVC.selectTag(tag: tag)
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
        tagImage = UIImageView(frame: CGRect(x: 9, y: 9, width: 24, height: 24))
        tagImage.image = tag.image
        addSubview(tagImage)
    }
    
    func setAlphas(alpha: CGFloat) {
        tagImage.alpha = alpha
        backgroundColor = postTag.selected ? UIColor(red: 0.00, green: 0.09, blue: 0.09, alpha: 1.00) : UIColor(red: 0.112, green: 0.112, blue: 0.112, alpha: 1).withAlphaComponent(alpha)
        layer.borderColor = postTag.selected ? UIColor(named: "SpotGreen")!.cgColor : UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: alpha).cgColor
    }
}
