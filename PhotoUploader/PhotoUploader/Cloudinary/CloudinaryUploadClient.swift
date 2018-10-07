//
//  CloudinaryUploadClient.swift
//  PhotoUploader
//
//  Created by Deekshith Bellare on 07/10/18.
//  Copyright © 2018 Deekshith Bellare. All rights reserved.
//

import Cloudinary
import Foundation

enum PhotoUploaderConstants: String {
    case cloudinaryUrl = "cloudinary://key:secret@name"
}

// Completion handler of ImageUploaderProtocol
typealias UploadCompletionHandler = (_ response: [String: AnyObject]?, _ error: NSError?) -> Void

extension CLDUploadRequest: ImageUploaderRequestProtocol {}

class CloudinaryUploadClient: ImageUploaderProtocol {
    var cloudinary: CLDCloudinary!

    static var defaultConfig: CLDConfiguration? {
        guard let config = CLDConfiguration(cloudinaryUrl: PhotoUploaderConstants.cloudinaryUrl.rawValue) else {
            return nil
        }
        return config
    }

    init() {}

    init(config: CLDConfiguration) {
        cloudinary = CLDCloudinary(configuration: config)
    }

    func upload(data: Data, fileName: String, progress: ((Progress) -> Void)?, completionHandler: @escaping UploadCompletionHandler) -> ImageUploaderRequestProtocol? {
        // Setup cloudinary
        let params = CLDUploadRequestParams()
        params.setPublicId(fileName)
        let uploader = cloudinary.createUploader()
        let request = uploader.signedUpload(data: data, params: params, progress: progress) { result, error in
            completionHandler(result?.resultJson, error)
        }
        return request
    }
}
