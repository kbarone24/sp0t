//
//  CountryPickerController.swift
//  Spot
//
//  Created by Kenny Barone on 3/25/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

protocol CountryPickerDelegate {
    func finishPassing(code: CountryCode)
}

class CountryPickerController: UIViewController {
    var delegate: CountryPickerDelegate?
    var tableView: UITableView!
    
    let countries = [
            CountryCode(id: 224, code: "+1", name: "United States"),
            CountryCode(id: 0, code: "+7 840", name: "Abkhazia"),
            CountryCode(id: 1, code: "+93", name: "Afghanistan"),
            CountryCode(id: 2, code: "+355", name: "Albania"),
            CountryCode(id: 3, code: "+213", name: "Algeria"),
            CountryCode(id: 4, code: "+1 684", name: "American Samoa"),
            CountryCode(id: 5, code: "+376", name: "Andorra"),
            CountryCode(id: 6, code: "+244", name: "Angola"),
            CountryCode(id: 7, code: "+1 264", name: "Anguilla"),
            CountryCode(id: 8, code: "+1 268", name: "Antigua and Barbuda"),
            CountryCode(id: 9, code: "+54", name: "Argentina"),
            CountryCode(id: 10, code: "+374", name: "Armenia"),
            CountryCode(id: 11, code: "+297", name: "Aruba"),
            CountryCode(id: 12, code: "+247", name: "Ascension"),
            CountryCode(id: 13, code: "+61", name: "Australia"),
            CountryCode(id: 14, code: "+672", name: "Australian External Territories"),
            CountryCode(id: 15, code: "+43", name: "Austria"),
            CountryCode(id: 16, code: "+994", name: "Azerbaijan"),
            CountryCode(id: 17, code: "+1 242", name: "Bahamas"),
            CountryCode(id: 18, code: "+973", name: "Bahrain"),
            CountryCode(id: 19, code: "+880", name: "Bangladesh"),
            CountryCode(id: 20, code: "+1 246", name: "Barbados"),
            CountryCode(id: 21, code: "+1 268", name: "Barbuda"),
            CountryCode(id: 22, code: "+375", name: "Belarus"),
            CountryCode(id: 23, code: "+32", name: "Belgium"),
            CountryCode(id: 24, code: "+501", name: "Belize"),
            CountryCode(id: 25, code: "+229", name: "Benin"),
            CountryCode(id: 26, code: "+1 441", name: "Bermuda"),
            CountryCode(id: 27, code: "+975", name: "Bhutan"),
            CountryCode(id: 28, code: "+591", name: "Bolivia"),
            CountryCode(id: 29, code: "+387", name: "Bosnia and Herzegovina"),
            CountryCode(id: 30, code: "+267", name: "Botswana"),
            CountryCode(id: 31, code: "+55", name: "Brazil"),
            CountryCode(id: 32, code: "+246", name: "British Indian Ocean Territory"),
            CountryCode(id: 33, code: "+1 284", name: "British Virgin Islands"),
            CountryCode(id: 34, code: "+673", name: "Brunei"),
            CountryCode(id: 35, code: "+359", name: "Bulgaria"),
            CountryCode(id: 36, code: "+226", name: "Burkina Faso"),
            CountryCode(id: 37, code: "+257", name: "Burundi"),
            CountryCode(id: 38, code: "+855", name: "Cambodia"),
            CountryCode(id: 39, code: "+237", name: "Cameroon"),
            CountryCode(id: 40, code: "+1", name: "Canada"),
            CountryCode(id: 41, code: "+238", name: "Cape Verde"),
            CountryCode(id: 42, code: "+ 345", name: "Cayman Islands"),
            CountryCode(id: 43, code: "+236", name: "Central African Republic"),
            CountryCode(id: 44, code: "+235", name: "Chad"),
            CountryCode(id: 45, code: "+56", name: "Chile"),
            CountryCode(id: 46, code: "+86", name: "China"),
            CountryCode(id: 47, code: "+61", name: "Christmas Island"),
            CountryCode(id: 48, code: "+61", name: "Cocos-Keeling Islands"),
            CountryCode(id: 49, code: "+57", name: "Colombia"),
            CountryCode(id: 50, code: "+269", name: "Comoros"),
            CountryCode(id: 51, code: "+242", name: "Congo"),
            CountryCode(id: 52, code: "+243", name: "Democratic Rep of Congo"),
            CountryCode(id: 53, code: "+682", name: "Cook Islands"),
            CountryCode(id: 54, code: "+506", name: "Costa Rica"),
            CountryCode(id: 55, code: "+385", name: "Croatia"),
            CountryCode(id: 56, code: "+53", name: "Cuba"),
            CountryCode(id: 57, code: "+599", name: "Curacao"),
            CountryCode(id: 58, code: "+537", name: "Cyprus"),
            CountryCode(id: 59, code: "+420", name: "Czech Republic"),
            CountryCode(id: 60, code: "+45", name: "Denmark"),
            CountryCode(id: 61, code: "+246", name: "Diego Garcia"),
            CountryCode(id: 62, code: "+253", name: "Djibouti"),
            CountryCode(id: 63, code: "+1 767", name: "Dominica"),
            CountryCode(id: 64, code: "+1 809", name: "Dominican Republic"),
            CountryCode(id: 65, code: "+670", name: "East Timor"),
            CountryCode(id: 66, code: "+56", name: "Easter Island"),
            CountryCode(id: 67, code: "+593", name: "Ecuador"),
            CountryCode(id: 68, code: "+20", name: "Egypt"),
            CountryCode(id: 69, code: "+503", name: "El Salvador"),
            CountryCode(id: 70, code: "+240", name: "Equatorial Guinea"),
            CountryCode(id: 71, code: "+291", name: "Eritrea"),
            CountryCode(id: 72, code: "+372", name: "Estonia"),
            CountryCode(id: 73, code: "+251", name: "Ethiopia"),
            CountryCode(id: 74, code: "+500", name: "Falkland Islands"),
            CountryCode(id: 75, code: "+298", name: "Faroe Islands"),
            CountryCode(id: 76, code: "+679", name: "Fiji"),
            CountryCode(id: 77, code: "+358", name: "Finland"),
            CountryCode(id: 78, code: "+33", name: "France"),
            CountryCode(id: 79, code: "+596", name: "French Antilles"),
            CountryCode(id: 80, code: "+594", name: "French Guiana"),
            CountryCode(id: 81, code: "+689", name: "French Polynesia"),
            CountryCode(id: 82, code: "+241", name: "Gabon"),
            CountryCode(id: 83, code: "+220", name: "Gambia"),
            CountryCode(id: 84, code: "+995", name: "Georgia"),
            CountryCode(id: 85, code: "+49", name: "Germany"),
            CountryCode(id: 86, code: "+233", name: "Ghana"),
            CountryCode(id: 87, code: "+350", name: "Gibraltar"),
            CountryCode(id: 88, code: "+30", name: "Greece"),
            CountryCode(id: 89, code: "+299", name: "Greenland"),
            CountryCode(id: 90, code: "+1 473", name: "Grenada"),
            CountryCode(id: 91, code: "+590", name: "Guadeloupe"),
            CountryCode(id: 92, code: "+1 671", name: "Guam"),
            CountryCode(id: 93, code: "+502", name: "Guatemala"),
            CountryCode(id: 94, code: "+224", name: "Guinea"),
            CountryCode(id: 95, code: "+245", name: "Guinea-Bissau"),
            CountryCode(id: 96, code: "+595", name: "Guyana"),
            CountryCode(id: 97, code: "+509", name: "Haiti"),
            CountryCode(id: 98, code: "+504", name: "Honduras"),
            CountryCode(id: 99, code: "+852", name: "Hong Kong SAR China"),
            CountryCode(id: 100, code: "+36", name: "Hungary"),
            CountryCode(id: 101, code: "+354", name: "Iceland"),
            CountryCode(id: 102, code: "+91", name: "India"),
            CountryCode(id: 103, code: "+62", name: "Indonesia"),
            CountryCode(id: 104, code: "+98", name: "Iran"),
            CountryCode(id: 105, code: "+964", name: "Iraq"),
            CountryCode(id: 106, code: "+353", name: "Ireland"),
            CountryCode(id: 107, code: "+972", name: "Israel"),
            CountryCode(id: 108, code: "+39", name: "Italy"),
            CountryCode(id: 109, code: "+225", name: "Ivory Coast"),
            CountryCode(id: 110, code: "+1 876", name: "Jamaica"),
            CountryCode(id: 111, code: "+81", name: "Japan"),
            CountryCode(id: 112, code: "+962", name: "Jordan"),
            CountryCode(id: 113, code: "+7 7", name: "Kazakhstan"),
            CountryCode(id: 114, code: "+254", name: "Kenya"),
            CountryCode(id: 115, code: "+686", name: "Kiribati"),
            CountryCode(id: 116, code: "+965", name: "Kuwait"),
            CountryCode(id: 117, code: "+996", name: "Kyrgyzstan"),
            CountryCode(id: 118, code: "+856", name: "Laos"),
            CountryCode(id: 119, code: "+371", name: "Latvia"),
            CountryCode(id: 120, code: "+961", name: "Lebanon"),
            CountryCode(id: 121, code: "+266", name: "Lesotho"),
            CountryCode(id: 122, code: "+231", name: "Liberia"),
            CountryCode(id: 123, code: "+218", name: "Libya"),
            CountryCode(id: 124, code: "+423", name: "Liechtenstein"),
            CountryCode(id: 125, code: "+370", name: "Lithuania"),
            CountryCode(id: 126, code: "+352", name: "Luxembourg"),
            CountryCode(id: 127, code: "+853", name: "Macau SAR China"),
            CountryCode(id: 128, code: "+389", name: "Macedonia"),
            CountryCode(id: 129, code: "+261", name: "Madagascar"),
            CountryCode(id: 130, code: "+265", name: "Malawi"),
            CountryCode(id: 131, code: "+60", name: "Malaysia"),
            CountryCode(id: 132, code: "+960", name: "Maldives"),
            CountryCode(id: 133, code: "+223", name: "Mali"),
            CountryCode(id: 134, code: "+356", name: "Malta"),
            CountryCode(id: 135, code: "+692", name: "Marshall Islands"),
            CountryCode(id: 136, code: "+596", name: "Martinique"),
            CountryCode(id: 137, code: "+222", name: "Mauritania"),
            CountryCode(id: 138, code: "+230", name: "Mauritius"),
            CountryCode(id: 139, code: "+262", name: "Mayotte"),
            CountryCode(id: 140, code: "+52", name: "Mexico"),
            CountryCode(id: 141, code: "+691", name: "Micronesia"),
            CountryCode(id: 142, code: "+1 808", name: "Midway Island"),
            CountryCode(id: 143, code: "+373", name: "Moldova"),
            CountryCode(id: 144, code: "+377", name: "Monaco"),
            CountryCode(id: 145, code: "+976", name: "Mongolia"),
            CountryCode(id: 146, code: "+382", name: "Montenegro"),
            CountryCode(id: 147, code: "+1664", name: "Montserrat"),
            CountryCode(id: 148, code: "+212", name: "Morocco"),
            CountryCode(id: 149, code: "+95", name: "Myanmar"),
            CountryCode(id: 150, code: "+264", name: "Namibia"),
            CountryCode(id: 151, code: "+674", name: "Nauru"),
            CountryCode(id: 152, code: "+977", name: "Nepal"),
            CountryCode(id: 153, code: "+31", name: "Netherlands"),
            CountryCode(id: 154, code: "+599", name: "Netherlands Antilles"),
            CountryCode(id: 155, code: "+1 869", name: "Nevis"),
            CountryCode(id: 156, code: "+687", name: "New Caledonia"),
            CountryCode(id: 157, code: "+64", name: "New Zealand"),
            CountryCode(id: 158, code: "+505", name: "Nicaragua"),
            CountryCode(id: 159, code: "+227", name: "Niger"),
            CountryCode(id: 160, code: "+234", name: "Nigeria"),
            CountryCode(id: 161, code: "+683", name: "Niue"),
            CountryCode(id: 162, code: "+672", name: "Norfolk Island"),
            CountryCode(id: 163, code: "+850", name: "North Korea"),
            CountryCode(id: 164, code: "+1 670", name: "Northern Mariana Islands"),
            CountryCode(id: 165, code: "+47", name: "Norway"),
            CountryCode(id: 166, code: "+968", name: "Oman"),
            CountryCode(id: 167, code: "+92", name: "Pakistan"),
            CountryCode(id: 168, code: "+680", name: "Palau"),
            CountryCode(id: 169, code: "+970", name: "Palestine"),
            CountryCode(id: 170, code: "+507", name: "Panama"),
            CountryCode(id: 171, code: "+675", name: "Papua New Guinea"),
            CountryCode(id: 172, code: "+595", name: "Paraguay"),
            CountryCode(id: 173, code: "+51", name: "Peru"),
            CountryCode(id: 174, code: "+63", name: "Philippines"),
            CountryCode(id: 175, code: "+48", name: "Poland"),
            CountryCode(id: 176, code: "+351", name: "Portugal"),
            CountryCode(id: 177, code: "+1 787", name: "Puerto Rico"),
            CountryCode(id: 178, code: "+974", name: "Qatar"),
            CountryCode(id: 179, code: "+262", name: "Reunion"),
            CountryCode(id: 180, code: "+40", name: "Romania"),
            CountryCode(id: 181, code: "+7", name: "Russia"),
            CountryCode(id: 182, code: "+250", name: "Rwanda"),
            CountryCode(id: 183, code: "+685", name: "Samoa"),
            CountryCode(id: 184, code: "+378", name: "San Marino"),
            CountryCode(id: 185, code: "+966", name: "Saudi Arabia"),
            CountryCode(id: 186, code: "+221", name: "Senegal"),
            CountryCode(id: 187, code: "+381", name: "Serbia"),
            CountryCode(id: 188, code: "+248", name: "Seychelles"),
            CountryCode(id: 189, code: "+232", name: "Sierra Leone"),
            CountryCode(id: 190, code: "+65", name: "Singapore"),
            CountryCode(id: 191, code: "+421", name: "Slovakia"),
            CountryCode(id: 192, code: "+386", name: "Slovenia"),
            CountryCode(id: 193, code: "+677", name: "Solomon Islands"),
            CountryCode(id: 194, code: "+27", name: "South Africa"),
            CountryCode(id: 195, code: "+500", name: "South Georgia and the South Sandwich Islands"),
            CountryCode(id: 196, code: "+82", name: "South Korea"),
            CountryCode(id: 197, code: "+34", name: "Spain"),
            CountryCode(id: 198, code: "+94", name: "Sri Lanka"),
            CountryCode(id: 199, code: "+249", name: "Sudan"),
            CountryCode(id: 200, code: "+597", name: "Suriname"),
            CountryCode(id: 201, code: "+268", name: "Swaziland"),
            CountryCode(id: 202, code: "+46", name: "Sweden"),
            CountryCode(id: 203, code: "+41", name: "Switzerland"),
            CountryCode(id: 204, code: "+963", name: "Syria"),
            CountryCode(id: 205, code: "+886", name: "Taiwan"),
            CountryCode(id: 206, code: "+992", name: "Tajikistan"),
            CountryCode(id: 207, code: "+255", name: "Tanzania"),
            CountryCode(id: 208, code: "+66", name: "Thailand"),
            CountryCode(id: 209, code: "+670", name: "Timor Leste"),
            CountryCode(id: 210, code: "+228", name: "Togo"),
            CountryCode(id: 211, code: "+690", name: "Tokelau"),
            CountryCode(id: 212, code: "+676", name: "Tonga"),
            CountryCode(id: 213, code: "+1 868", name: "Trinidad and Tobago"),
            CountryCode(id: 214, code: "+216", name: "Tunisia"),
            CountryCode(id: 215, code: "+90", name: "Turkey"),
            CountryCode(id: 216, code: "+993", name: "Turkmenistan"),
            CountryCode(id: 217, code: "+1 649", name: "Turks and Caicos Islands"),
            CountryCode(id: 218, code: "+688", name: "Tuvalu"),
            CountryCode(id: 219, code: "+1 340", name: "U.S. Virgin Islands"),
            CountryCode(id: 220, code: "+256", name: "Uganda"),
            CountryCode(id: 221, code: "+380", name: "Ukraine"),
            CountryCode(id: 222, code: "+971", name: "United Arab Emirates"),
            CountryCode(id: 223, code: "+44", name: "United Kingdom"),
            CountryCode(id: 225, code: "+598", name: "Uruguay"),
            CountryCode(id: 226, code: "+998", name: "Uzbekistan"),
            CountryCode(id: 227, code: "+678", name: "Vanuatu"),
            CountryCode(id: 228, code: "+58", name: "Venezuela"),
            CountryCode(id: 229, code: "+84", name: "Vietnam"),
            CountryCode(id: 230, code: "+1 808", name: "Wake Island"),
            CountryCode(id: 231, code: "+681", name: "Wallis and Futuna"),
            CountryCode(id: 232, code: "+967", name: "Yemen"),
            CountryCode(id: 233, code: "+260", name: "Zambia"),
            CountryCode(id: 234, code: "+255", name: "Zanzibar"),
            CountryCode(id: 235, code: "+263", name: "Zimbabwe")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isUserInteractionEnabled = true
        tableView.allowsSelection = true
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.register(CountryCell.self, forCellReuseIdentifier: "CountryCell")
        tableView.register(CountryPickerHeader.self, forHeaderFooterViewReuseIdentifier: "CountryPickerHeader")
        view.addSubview(tableView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CountryPickerOpen")
    }
}

extension CountryPickerController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return countries.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "CountryCell") as? CountryCell {
            cell.setUp(code: countries[indexPath.row])
            return cell
        } else { return UITableViewCell() }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "CountryPickerHeader") as? CountryPickerHeader {
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let code = countries[indexPath.row]
        delegate?.finishPassing(code: code)
        Mixpanel.mainInstance().track(event: "CountryPickerSelectCountry", properties: ["country": code.name])
        self.dismiss(animated: true, completion: nil)
    }
}

class CountryCell: UITableViewCell {
    var countryName: UILabel!
    var countryCode: UILabel!
    var bottomLine: UIView!
    
    var code: CountryCode! {
        didSet {
            countryName.text = code.name
            countryCode.text = code.code
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .none
        
        countryCode = UILabel {
            $0.textColor = UIColor.darkGray
            $0.font = UIFont(name: "SFCompactText-Regular", size: 16)
            contentView.addSubview($0)
        }
        countryCode.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.top.equalTo(20)
        }

        countryName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            contentView.addSubview($0)
        }
        countryName.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.trailing.equalTo(countryCode.snp.leading).offset(-10)
            $0.top.equalTo(20)
        }
            
        bottomLine = UIView {
            $0.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
            contentView.addSubview($0)
        }
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(code: CountryCode) {
        self.code = code
    }
}

class CountryPickerHeader: UITableViewHeaderFooterView {
    var label: UILabel!
    var exitButton: UIButton!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView
        
        label = UILabel {
            $0.text = "Select country"
            $0.textColor = .black
            $0.textAlignment = .center
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            addSubview($0)
        }
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(2)
        }
        
        exitButton = UIButton {
            $0.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(exit), for: .touchUpInside)
            addSubview($0)
        }
        exitButton.snp.makeConstraints {
            $0.leading.top.equalTo(10)
            $0.height.width.equalTo(35)
        }
    }
    
    @objc func exit() {
        if let vc = viewContainingController() as? CountryPickerController {
            vc.dismiss(animated: true, completion: nil)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
