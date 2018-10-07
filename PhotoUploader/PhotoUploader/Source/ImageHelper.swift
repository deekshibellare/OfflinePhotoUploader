//
//  ImageHelper.swift
//  PhotoUploader
//
//  Created by Deekshith Bellare on 07/10/18.
//  Copyright © 2018 Deekshith Bellare. All rights reserved.
//

import UIKit

extension UIImage {
    // Images stored from the photo gallery (taken though camera) are rotated by 90 degress, so before saving to document directory,we make sure that it is in correct orientation
    func fixOrientation() -> UIImage {
        if imageOrientation == UIImage.Orientation.up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        if let normalizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext() {
            UIGraphicsEndImageContext()
            return normalizedImage
        } else {
            return self
        }
    }
}
