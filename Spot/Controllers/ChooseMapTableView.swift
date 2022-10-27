//
//  ChooseMapTableView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class ChooseMapTableView: UITableView {

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        backgroundColor = nil
        contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        separatorStyle = .none
        showsVerticalScrollIndicator = false

        register(CustomMapUploadCell.self, forCellReuseIdentifier: "MapCell")
        register(CustomMapsHeader.self, forHeaderFooterViewReuseIdentifier: "MapsHeader")
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
