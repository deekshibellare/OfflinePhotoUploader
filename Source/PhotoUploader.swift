//
//  PhotoUploader.swift
//  PhotoUploader
//
//  Created by Deekshith Bellare on 07/10/18.
//  Copyright © 2018 Deekshith Bellare. All rights reserved.
//

import UIKit
// Completion handler of PhotoUploader
typealias ResponseCompletionHandler = (_ response: [String: String]?, _ error: NSError?) -> Void

// Request protocol
protocol ImageUploaderRequestProtocol {
    func cancel()
}

// Upload protocol
protocol ImageUploaderProtocol {
    func upload(data: Data, fileName: String, progress: ((Progress) -> Void)?, completionHandler: @escaping UploadCompletionHandler) -> ImageUploaderRequestProtocol?
}

/// PhotoUploader handles the job of uploading the image to the cloud ( for now it's cloudinary) and returns the response
class PhotoUploader {
    /// Instacne of cloudinary
    var uploadClient: ImageUploaderProtocol

    /// Holds the upload requests in memory so that if a image is deleted, request can be cancelled
    var requests = [String: ImageUploaderRequestProtocol]()

    /// An instace of persistacne store that is used for queing images for the upload
    var persistenceStore: PersistentStore!

    // completion closure that gets invoked on completing upload of all the pending images.
    var uploadCompletionBlock: ((_ error: NSError?) -> Void)?

    static let shared = PhotoUploader()
    init() {
        uploadClient = CloudinaryUploadClient()
        persistenceStore = PersistentStore(folderName: "iControl")
    }

    /// Create the photo uploader instance with configration and persistacne store
    ///
    /// - Parameters:
    ///   - configuration: Cloudinary configuration
    ///   - inPersistenceStore: PersistenceStore instance which will be used to store the enque images
    init(client: ImageUploaderProtocol, persistenceStore inPersistenceStore: PersistentStore) {
        uploadClient = client
        persistenceStore = inPersistenceStore
        uploadPendingImages()
    }

    /// Upload the image to the cloudinary and return the response
    ///
    /// - Parameters:
    ///   - image: Image to be uploaded
    ///   - fileName: Name of the image
    ///   - progress:  The closure that is called periodically during the data transfer.
    ///   - inCompletionHandler:  The closure to be called once the request has finished, holding either the customised response object or the error.
    /// - returns: ImageUploaderRequestProtocol which can be canceled
    @discardableResult func upload(image: UIImage, fileName: String,
                                   progress: ((Progress) -> Void)? = nil,
                                   completionHandler: ResponseCompletionHandler? = nil) -> ImageUploaderRequestProtocol? {
        // Setup cloudinary

        // Convert image to JPEG
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            let error = NSError(domain: "",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "Image not found or input is not a image"])
            completionHandler?(nil, error)
            return nil
        }

        // Enqueue job with image and filename
        _ = persistenceStore.enqueue(jobID: fileName, state: .pending, image: image)
        print("upload started for \(fileName)")

        let request = uploadClient.upload(data: data, fileName: fileName,
                                          progress: { currentProgress in

                                              // Update state of the task to uploading
                                              _ = self.persistenceStore.updateStatus(forJobID: fileName, state: .processing)

                                              // return the progress
                                              if let progress = progress {
                                                  progress(currentProgress)
                                              }

        }) { [weak self] result, error in

            // Check for self
            guard let weakself = self else {
                return
            }

            // Remove from requests cache
            if let _ = weakself.requests[fileName] {
                weakself.requests.removeValue(forKey: fileName)
            }

            // handle response
            if let response = result {
                weakself.handle(response: response, forFileName: fileName, completionHandler: completionHandler)
            } else if let error = error {
                weakself.handle(error: error, forFileName: fileName, completionHandler: completionHandler)
            }
        }

        // add the request to the cache
        requests["fileName"] = request
        return request
    }

    private func continueUpload() {
        uploadPendingImages()
    }

    // Cheks of all the images are uploaded by the photouploader
    func hasUploadedAllImages() -> Bool {
        return persistenceStore.hasAllJobsCompleted()
    }

    /// Uploads the pending images from the persistant store. Normally all the images are qued for upload immediately but if the app is offline, images will be stored to document directory and uploaded again if they are pending for upload
    func uploadPendingImages() {
        guard let (job, image) = persistenceStore.nextPendingJob() else {
            return
        }
        upload(image: image, fileName: job.jobID) { dictionary, _ in
            if let dictionary = dictionary,
                let _ = dictionary["remoteURL"],
                let _ = dictionary["photoId"] {
                // Call the delegate with the response
            }
        }
    }

    /// Delete the photo from the cloudinary
    /// Deletes the upload request for the photoID if any,removes the job from the peristance store
    /// - Parameter photoID: Public ID of the photo
    func delete(photoID: String) {
        if let request = requests[photoID] {
            request.cancel()
            requests.removeValue(forKey: photoID)
        }
        persistenceStore.removeJob(jobID: photoID, shouldDeleteImage: true)
    }

    // Mark: Private methods
    // Response handlers - Parse the upload response, update the reciept for the image, continue upload of other images
    private func handle(response: [String: AnyObject], forFileName fileName: String, completionHandler: ResponseCompletionHandler? = nil) {
        // Create response dictionary
        var dictionary = [String: String]()
        dictionary["remoteURL"] = response["secure_url"] as? String
        if let versionNo = response["version"] as? Int {
            dictionary["versionNo"] = "\(versionNo)"
        }
        dictionary["photoId"] = response["public_id"] as? String

        // Only if job(image) was not deleted, update the response to photoItem
        if let photoID = response["public_id"] as? String,
            let _ = self.persistenceStore.job(jobID: photoID) {
            // Completion handler where receipt needs to be updated in photo is called
            completionHandler?(dictionary, nil)
            _ = persistenceStore.updateStatus(forJobID: fileName, state: .complete)

            // Check for next pending images for upload
            continueUpload()
        } else {
            // Create a error for improper Json
            let error = NSError(domain: "",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "Server did not return required data or Image is deleted locally "])

            handle(error: error, forFileName: fileName, completionHandler: completionHandler)
        }
    }

    // handle the error
    private func handle(error: NSError, forFileName fileName: String, completionHandler: ResponseCompletionHandler? = nil) {
        // Reset the job state to pending as photoupload did not sucessed
        _ = persistenceStore.updateStatus(forJobID: fileName, state: .pending)

        // Completion handler where receipt needs to be updated in photo is called
        completionHandler?(nil, error)

        uploadCompletionBlock?(error)

        // If there is any error then try reupload after sometime
        let deadlineTime = DispatchTime.now() + .seconds(60)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
            self.continueUpload()
        })
    }
}
