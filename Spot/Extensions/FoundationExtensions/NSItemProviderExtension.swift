//
//  NSItemProviderExtension.swift
//  Spot
//
//  Created by Kenny Barone on 8/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

extension NSItemProvider {
    func getPhoto(completion: @escaping (_ image: UIImage?) -> Void) {
        if canLoadObject(ofClass: UIImage.self) {
            loadObject(ofClass: UIImage.self) { object, error in
                if let error = error {
                    print(error.localizedDescription)
                }
                completion(object as? UIImage)
            }
        }
    }
}
