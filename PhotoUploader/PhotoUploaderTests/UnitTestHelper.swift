//
//  UnitTestHelper.swift
//  PhotoUploaderTests
//
//  Created by Deekshith Bellare on 09/10/18.
//  Copyright © 2018 Deekshith Bellare. All rights reserved.
//

import UIKit

class UnitTestHelper {
    static func imageToTest(imageName: String = "test") -> UIImage? {
        let testBundle = Bundle(for: self)
        return UIImage(named: imageName, in: testBundle, compatibleWith: nil)
    }
}

