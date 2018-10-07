//
//  Persistence Store.swift
//  PhotoUploader
//
//  Created by Deekshith Bellare on 07/10/18.
//  Copyright © 2018 Deekshith Bellare. All rights reserved.
//

import Foundation
import UIKit

/// Persistence Store handles offline support for the jobs. A Job is image upload task which will consist of a reference to the image, current state of the task, the timestamp on which it is added etc. This class stores jobs in memory, as well as in document directory. Images are stored in document directory directly. Jobs are retrieved from the 'folderName' on app launch if any. It provides methods to enqueue the job and fetch next job, delete the job and other convenience methods
class PersistentStore {
    /// Name of the folder in document directory under which all the jobs and images should reside.
    var folderName: String = "ImageStore"

    /// Jobs that are enqueued. This is updated/populated from the document directory if app is relaunched after quitting
    private var jobs: [Job] = [Job]()

    /// Initialize persistence store with the folder name
    /// - Parameters:
    ///   - folderName: FolderName under which the data related to jobs need to be saved
    /// - shouldFetchJobs: Is used to fetch the jobs that are already in document directory. This need not be used for all the cases, for example - Image downloader which needs to access the image for the given photoID, does not need the jobs to to fetched.
    ///   - maximumImagesToQueue: Maximum jobs to queue in the Persistence  store
    /// - Returns: Fully initialized Persistence  store, nil if folderName is nil
    init?(folderName: String?, shouldFetchJobs: Bool = true) {
        guard let folderName = folderName else {
            return nil
        }
        self.folderName = folderName
        if shouldFetchJobs {
            _ = createStore(folderName: self.folderName)
            jobs = getJobsFromStore()
            // on launch assume all the image upload that were in processing state as pending
            resetStateForProcessingJobs()
        }
    }

    // MARK: Jobs

    /// Reset all the processing states to pending, should be called on first launch only
    func resetStateForProcessingJobs() {
        for job in jobs {
            if job.jobState == .processing {
                _ = updateStatus(forJobID: job.jobID, state: .pending)
            }
        }
    }

    /// Enqueue the job for sheduling
    ///
    /// - Parameters:
    ///   - jobID: Unique indentifer for the job
    ///   - priority: Priority for the jobs, if priority sheduling is used
    ///   - state: Current state of the job, see JobState enum
    ///   - image: Image that needs to be queued corresponding to the jobID
    /// - Returns: True if enqueue is sucessful , false if enqueue is failed. Reasons for failure would be jobID could be empty

    func enqueue(jobID: String, state: JobState, image: UIImage) -> Bool {
        let (isSucess, _) = enqueueImage(image: image, forJobID: jobID)
        if isSucess == true {
            removeJob(jobID: jobID)
            let job = Job(jobID: jobID)
            job.jobState = state
            jobs.append(job)
            return save(job: job)
        }
        return isSucess
    }

    /// Save the job to the document directory
    ///
    /// - Parameter job: Job that needs to be saved
    /// - Returns: True if job is saved to document directory else false. Job should have a valid jobID
    func save(job: Job) -> Bool {
        do {
            let encodedData = try JSONEncoder().encode(job)
            guard let url = urlforFile(withJobID: job.jobID, isImageFile: false) else {
                return false
            }
            try? encodedData.write(to: url)
            return true
        } catch {
            return false
        }
    }

    /// Remove job from the sheduled jobs
    /// Job is removed both from the array as well as document directory
    /// - Parameter: JobID: Id of the job that needs to be removed
    /// shouldDeleteImage: If true deletes the correponding image from the document directory
    /// - Warning: When shouldDeleteImage is true, it deletes images from persistence store even if there is no correponding job for it. A job will be there only till image is uploaded and destroyed when its completed. But image might be there in document directory for local use
    func removeJob(jobID: String, shouldDeleteImage: Bool = false) {
        if let index = jobs.index(where: { $0.jobID == jobID }) {
            jobs.remove(at: index)
        }

        if let url = urlforFile(withJobID: jobID, isImageFile: false) {
            if FileManager.default.fileExists(atPath: url.path) == true {
                try? FileManager.default.removeItem(at: url)
            }
        }
        if shouldDeleteImage == true {
            _ = removeImage(forJobID: jobID)
        }
    }

    /// Fetch the next job that needs to be executed
    ///
    /// - Returns: Tuple which contains job and corresponding image related to that job that needs to be uploaded. If next job does not exist, returns empty
    func nextJob() -> (Job, UIImage)? {
        if jobs.count == 0 {
            return nil
        }

        if let job = jobs.first, let imageOfJob = image(forJobID: job.jobID) {
            return (job, imageOfJob)
        }
        return nil
    }

    /// Fetches and returns the sorted jobs based on timestamp
    ///
    /// - Returns: Sorted jobs based on timestamp
    private func sortedJobs() -> [Job] {
        let jobs = self.jobs.sorted { (job1, job2) -> Bool in
            return job1.timeStamp < job2.timeStamp
        }

        return jobs
    }

    /// Fetch the job that has image to be uploaded to the cloudinary server
    /// If the image is under uploading stage for more than 2 minutes, we attempt the upload again. Hence this also returns the jobs that are in uploading stage for more than 2 minutes
    /// - Returns: Tuple which contains job and corresponding imageURL related to that job that needs to be uploaded. If next job does not exist, returns empty
    func nextPendingJob() -> (Job, UIImage)? {
        let allJobs = sortedJobs()

        let pendingJobs = allJobs.filter { (job) -> Bool in
            return job.jobState == .pending
        }

        if let job = pendingJobs.first, let image = image(forJobID: job.jobID) {
            return (job, image)
        }

        let uploadingJobs = allJobs.filter { (job) -> Bool in
            return (job.jobState == .processing && Date().isGreaterThanTwoMinutes(timeStamp: job.uploadingTimeStamp))
        }

        if let job = uploadingJobs.first, let image = image(forJobID: job.jobID) {
            return (job, image)
        }
        return nil
    }

    /// Fetch all jobs
    /// - Returns: all jobs
    func allJobs() -> [Job] {
        return sortedJobs()
    }

    /// Fetch the next job that needs to be executed
    ///
    /// - Returns: Tuple which contains job and corresponding imageURL related to that job that needs to be uploaded. If next job does not exist, returns empty
    func nextJobURL() -> (Job, URL)? {
        if self.jobs.count == 0 {
            return nil
        }
        let jobs = self.jobs.sorted { (job1, job2) -> Bool in
            return job1.timeStamp < job2.timeStamp
        }
        if let job = jobs.first, let imageURL = imageURL(forJobID: job.jobID) {
            return (job, imageURL)
        }
        return nil
    }

    /// Update the state of the job
    ///
    /// - Parameters:
    ///   - jobID: Unique ID to indentify the job
    ///   - state: Current state of the task, see JobState
    /// - Returns: Rrue of job state is updated, false if job is not found for the specified jobID
    func updateStatus(forJobID jobID: String, state: JobState) -> Bool {
        guard let job = job(jobID: jobID) else {
            return false
        }
        job.jobState = state
        // Store the time when uploading began
        if state == .processing {
            job.uploadingTimeStamp = Date().toMillis()
        }
        jobs[0].jobState = state
        return save(job: job)
    }

    /// Fetch job for the specified job ID
    ///
    /// - Parameter jobID:
    /// - Returns: Job matching the job ID, nil if the job is not found for the specified job ID
    func job(jobID: String) -> Job? {
        if let index = jobs.index(where: { $0.jobID == jobID }) {
            let job = jobs[index]
            return job
        } else {
            return nil
        }
    }

    /// Fetches all the persistated Jobs from the document diretory
    /// This method is called on init of Persistence  store
    /// - Returns: An arry of jobs, returns empty array if no jobs are persisted.
    func getJobsFromStore() -> [Job] {
        var jobs = [Job]()
        guard let urls = getURLsForFiles(folderName: self.folderName, isImages: false) else {
            return jobs
        }

        for url in urls {
            if let job = self.getJob(for: url) {
                jobs.append(job)
            }
        }
        return jobs
    }

    /// Fetch the job for the specified URL
    ///
    /// - Parameter url: URL in which the job is stored
    /// - Returns: Decoded job if job is present in the URL specified, returns nil othewise
    private func getJob(for url: URL) -> Job? {
        do {
            let data = try Data(contentsOf: url)
            let job = try JSONDecoder().decode(Job.self, from: data)
            return job
        } catch {
            return nil
        }
    }

    /// The number of jobs left to uplaod
    ///
    /// - Returns: The number of jobs left to uplaod
    func hasAllJobsCompleted() -> Bool {
        let activeJobsCount = jobs.filter({ (job) -> Bool in
            job.jobState == .pending || job.jobState == .processing
        }).count
        return activeJobsCount == 0
    }

    // MARK: Images

    /// Enque the job for the sheduling
    ///
    /// - Parameters:
    ///   - image: image that needs to be queued
    ///   - jobID: unique ID of the job under which this image was queued.
    /// - Returns: true if enqueue is sucessful,othewise returns false along with error message
    private func enqueueImage(image: UIImage, forJobID jobID: String) -> (Bool, String?) {
        let corretImage = image.fixOrientation()
        guard let imageData = convertToData(image: corretImage) else {
            return (false, "Failed to deserialise the image")
        }

        guard let url = urlforFile(withJobID: jobID) else {
            return (false, "Specify proper jobID")
        }
        do {
            try imageData.write(to: url)
        } catch {
            return (false, "Failed to save the image")
        }
        return (true, nil)
    }

    /// Convert Image into Data
    ///
    /// - Parameter image: The image that needs to be converrted into data
    /// - Returns: Data represnetation of image, nil if the input is invalid image
    func convertToData(image: UIImage) -> Data? {
        var _imageData: Data?
        if let data = image.pngData() {
            _imageData = data
        }
        return _imageData
    }

    /// Fetches the image for the jobID
    ///
    /// - Parameter jobID: Unique ID for the job for which this image was saved
    /// - Returns: Image for the jobIID, otherwise returns nil
    func image(forJobID jobID: String) -> UIImage? {
        guard let url = urlforFile(withJobID: jobID) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            if let image = UIImage(data: data) {
                return image
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Fetches the image URL for the jobID
    ///
    /// - Parameter jobID: Unique ID for the job for which this image was saved
    /// - Returns: Image URL for the jobIID, otherwise returns nil
    func imageURL(forJobID jobID: String) -> URL? {
        guard let url = urlforFile(withJobID: jobID) else {
            return nil
        }
        return url
    }

    /// Removes the image for the specified jobID
    ///
    /// - Parameter jobID: Unique ID to idenitfy the job
    /// - Returns: True if the image was found for the specified JobID and removal was sucessful, false if removal of image was not sucessful
    func removeImage(forJobID jobID: String) -> Bool {
        guard let url = urlforFile(withJobID: jobID) else {
            return false
        }
        return removeImage(at: url)
    }

    /// Removes the image for the specified URL
    ///
    /// - Parameter url: Unique ID to identify the job
    /// - Returns: True if the image was found for the specified URL and removal was sucessful, false if removal of image was not sucessful
    private func removeImage(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    /// Removes all the images in the persistence store's folder
    ///
    /// - Returns: True if all the images are removed, otherwise returns false
    func removeAllImages() -> Bool {
        guard let urls = self.getURLsForFiles(folderName: self.folderName) else {
            return false
        }

        for url in urls {
            _ = removeImage(at: url)
        }
        return true
    }

    // MARK: URLS

    /// Returns the document directory url for the specified JobImage and data type
    /// Under document directory in the folder name specified for the Persistence  store, two subfolders are made. One is reserved for the images and another one for the job
    /// - Parameters:
    ///   - jobID: Unique ID to indentity the Job
    ///   - isImageFile: Flag indicating if the URL shoulkd be for the Job or for the image correponding to the job
    /// - Returns: URL for the image or Job if it is present else nil
    func urlforFile(withJobID jobID: String, isImageFile: Bool = true) -> URL? {
        if jobID.isEmpty == true {
            return nil
        }
        var url = doumentDirectoryURL()
        url.appendPathComponent(folderName)
        if isImageFile == true {
            url.appendPathComponent("Images", isDirectory: true)
        } else {
            url.appendPathComponent("Jobs", isDirectory: true)
        }
        url.appendPathComponent(jobID)
        url.appendPathExtension("png")
        return url
    }

    /// Gives the document directory for the current app
    ///
    /// - Returns: Document directory URL
    private func doumentDirectoryURL() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count - 1] as URL
    }

    /// Creates directories and subdirectories in document directory for the Persistence  of the data
    ///
    /// - Parameter folderName: name of the folder under which the Jobs and Images need to be stored in the document directory. Under the directory, two sub directories are created, Images and Jobs respectively
    /// - Returns: True if folders are created, returns false if folders are not created
    func createStore(folderName: String) -> (URL, Bool) {
        let documentDirectoryURL = doumentDirectoryURL()
        var dbDirectoryURL = documentDirectoryURL.appendingPathComponent(folderName)
        var isSucess = true
        if FileManager.default.fileExists(atPath: dbDirectoryURL.path) == false {
            do {
                try FileManager.default.createDirectory(at: dbDirectoryURL, withIntermediateDirectories: false, attributes: nil)
                dbDirectoryURL.appendPathComponent("Images", isDirectory: true)
                try? FileManager.default.createDirectory(at: dbDirectoryURL, withIntermediateDirectories: false, attributes: nil)
                dbDirectoryURL.deleteLastPathComponent()
                dbDirectoryURL.appendPathComponent("Jobs", isDirectory: true)
                try? FileManager.default.createDirectory(at: dbDirectoryURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                isSucess = false }
        } else {
            isSucess = true
        }
        return (dbDirectoryURL, isSucess)
    }

    /// Returns the folder URL in the document diretory
    ///
    /// - Parameter folderName: Name of the folder to which URL needs to be fetched
    /// - Returns: URL of the folder in the document directory, if folder does not exist returns URL as nil and false flag
    func storeURL(folderName: String) -> (URL?, Bool) {
        let documentDirectoryURL = doumentDirectoryURL()
        let dbDirectoryURL = documentDirectoryURL.appendingPathComponent(folderName)
        if FileManager.default.fileExists(atPath: dbDirectoryURL.path) == true {
            return (dbDirectoryURL, true)
        }
        return (nil, false)
    }

    /// Returns the Persistence  store's folder URL in the document diretory
    ///
    /// - Parameter folderName: Name of the folder to which URL needs to be fetched
    /// - Returns: URL of the folder in the document directory, if folder does not exist returns URL as nil and false flag
    func storeURL() -> (URL?, Bool) {
        return storeURL(folderName: folderName)
    }

    /// Deletes the data and folders on the Persistence  store's folder
    ///
    /// - Returns: True if the data and folders are deleted for the persistence store, False if deletion failed
    func deleteStorage() -> Bool {
        let (url, _) = storeURL(folderName: folderName)
        guard let dbDirectoryURL = url else {
            return false
        }
        try? FileManager.default.removeItem(at: dbDirectoryURL)
        return true
    }

    /// Gets the urls for all the files in the folder
    ///
    /// - Parameters:
    ///   - folderName: folder name under which urls of files needs to be fetched
    ///   - isImages: Flag to indicate if urls of images or jobs that needs to be fetched
    /// - Returns: array of urls for the given folders
    private func getURLsForFiles(folderName: String, isImages: Bool = true) -> [URL]? {
        do {
            let (url, _) = storeURL(folderName: folderName)

            guard var dbDirectoryURL = url else {
                return nil
            }
            if isImages == true {
                dbDirectoryURL.appendPathComponent("Images")
            } else {
                dbDirectoryURL.appendPathComponent("Jobs")
            }
            let fileUrls = try FileManager.default.contentsOfDirectory(at: dbDirectoryURL, includingPropertiesForKeys: nil, options: [])
            let sortedFileUrls = fileUrls.sorted(by: { (url1, url2) -> Bool in
                if let fileNameInt1 = self.fileName(url1), let fileNameInt2 = fileName(url2) {
                    return fileNameInt1 <= fileNameInt2
                }
                return true
            })
            return sortedFileUrls
        } catch {
            return nil
        }
    }

    /// Fetches file name from the url excluding extension
    ///
    /// - Parameter url: URL of the files
    /// - Returns: File name from the url excluding extension
    private func fileName(_ url: URL) -> String? {
        let fileExtension = url.pathExtension
        let filePath = url.lastPathComponent
        return filePath.replacingOccurrences(of: fileExtension, with: "")
    }
}

// MARK: Job

/// Job is entity that used for uploading image, states and maintaining Persistence
class Job: Codable {
    /// Unique ID used to indentify the job
    var jobID: String

    /// Timestamp to indentify the job
    var timeStamp: Double
    /// enums are not codable items, hence this variable is used to hold the jobState enums raw value
    private var internalState: String = "pending"

    /// The time when error occured when uploading last time
    var lastErrorTimeStamp: Double?
    /// Number of retries made for the upload
    var retryCount: Int = 0

    /// The timestamp when uploading of the job began
    var uploadingTimeStamp: Double?
    /// Initializes and creates Job with jobID and priority
    ///
    /// - Parameters:
    ///   - jobID: Unique ID to indentify the job
    ///   - priority: priority of the job
    init(jobID: String) {
        self.jobID = jobID
        timeStamp = Date().toMillis()
    }

    /// Current state of the job
    var jobState: JobState {
        get {
            if let state = JobState(rawValue: internalState) {
                return state
            } else {
                return .pending
            }
        }
        set {
            internalState = newValue.rawValue
        }
    }

    /// Keys for the coding protocol
    /// as we need to exlude the Job state enums. See the properties for the explanation
    enum CodingKeys: String, CodingKey {
        case jobID
        case internalState
        case timeStamp
        case lastErrorTimeStamp
        case retryCount
        case uploadingTimeStamp
    }
}

/// Each job moves through set of states on the image upload process
///
/// - pending: Job just queued
/// - uploadingImage: image is being uploaded to cloudinary
/// - uploadedImage: image is uploaded to cloudinary
enum JobState: String {
    case pending
    case processing
    case complete
}

// MARK: - Date extension to handle timestamp

extension Date {
    /// Gives time stamp in milli seconds
    ///
    /// - Returns: Timestamp in milliseconds
    func toMillis() -> Double {
        return Double(timeIntervalSince1970 * 1000)
    }

    /// Checks if the current date in milliseconds is five minutes greater than timeStamp input
    ///
    /// - Parameter timeStamp: Saved timestamp on which current date needs to be compared
    /// - Returns: True if the time is five minutes more and false otherwise
    func isGreaterThanTwoMinutes(timeStamp: Double?) -> Bool {
        guard let timeStamp = timeStamp else {
            return false
        }
        let currentTimeInMillis = toMillis()
        let twoMinutesInMills: Double = 120_000
        return (currentTimeInMillis - timeStamp) >= twoMinutesInMills
    }
}
