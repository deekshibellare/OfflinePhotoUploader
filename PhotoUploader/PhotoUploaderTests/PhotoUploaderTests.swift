//
//  PhotoUploaderTests.swift
//  PhotoUploaderTests
//
//  Created by Deekshith Bellare on 07/10/18.
//  Copyright © 2018 Deekshith Bellare. All rights reserved.
//

@testable import PhotoUploader
import Cloudinary
import XCTest

class PhotoUploaderTests: XCTestCase {
    
    
    //It is expected that image upload does not take more than 30 seconds
    let timeout: TimeInterval = 30.0
    //Image uploader class that takes images and uploads them
    var imageUploader:PhotoUploader?
    
    var uploadClient:MockUploader!
    //Local store on where all the images are stored
    var persistentStore: PersistentStore!
    
    // MARK: - Lifcycle
    override func setUp() {
        super.setUp()
        //setup the local store with test folder
        persistentStore = PersistentStore(folderName:"TestStore")
        uploadClient = MockUploader()
        imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
    
        
    }
    
    override func tearDown() {
        super.tearDown()
        _ = persistentStore.deleteStorage()
    }
    
    //Takes a image and uploads to cloudinary. Test should yield correct result. Note these tests depend on active network connection. API failure might happen which is failure use case for this test case
    func testUploadImage() {
        if let image = UnitTestHelper.imageToTest() {
            let expectation = self.expectation(description: "Upload should succeed")
            var result:[String:String]?
            var error: NSError?
            imageUploader?.upload(image: image, fileName: "123", progress: nil) { (response, inError) in
                result = response
                error = inError
                expectation.fulfill()
            }
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssertNotNil(result, "result should not be nil")
            XCTAssertNotNil(result?["remoteURL"]!, "result should not be nil")
            XCTAssertNil(error, "error should be nil")
        }
    }
    
    //Every upload request is stored in the form of jobs and after upload, job in pendigng state should be reduced.
    func testPendingJobCountAfterUploading() {
        if let image = UnitTestHelper.imageToTest() {
            let expectation = self.expectation(description: "Upload should succeed")
            var result:[String:String]?
            imageUploader?.upload(image: image, fileName: "123", progress: nil) { (response, inError) in
                result = response
                expectation.fulfill()
            }
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssertNotNil(result, "result should not be nil")
            XCTAssertNil(persistentStore.nextPendingJob(), "error should be nil")
        }
    }
    
    //It is expected server stores photoID as the name of the file and
    //returns it in response so that respective photo Item can be updated with reciept
    func testPhotoIDStored() {
        if let image = UnitTestHelper.imageToTest() {
            let expectation = self.expectation(description: "Upload should succeed")
            var result:[String:String]?
            imageUploader?.upload(image: image, fileName: "Test1234", progress: nil) { (response, inError) in
                result = response
                expectation.fulfill()
            }
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssertEqual(result!["photoId"],"Test1234")
        }
    }
    //If the image is sheduled for upload and deleted immeditely locally, the upload method returns not found method even if we got a correct response from the servers
    func testImageDeleteOnUploadProgress() {
        if let image = UnitTestHelper.imageToTest() {
            let expectation = self.expectation(description: "Upload should succeed")
            var result:[String:String]?
            var error: NSError?
            
            uploadClient.testCase = .sucessWithDelay(interwal: 3)
            imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
            imageUploader?.upload(image: image, fileName: "Test1234", progress: nil) { (response, inError) in
                result = response
                error = inError
                expectation.fulfill()
            }
            imageUploader?.delete(photoID: "Test1234")
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssertNil(result)
            XCTAssertEqual(error?.code, 404)
        }
    }
    
    //Status of the upload job shoudld be in processing state on upload.
    //Otherwise it could trigger mutiple uploads for the same image.
    //Here we check that a job that was captured while upload in progress has state processing
    func testStatusofJobWhenUploadIsInProgress() {
        if let image = UnitTestHelper.imageToTest() {
            let expectation = self.expectation(description: "Upload should succeed")
            var job:(Job,UIImage)?
            
            uploadClient.testCase = .sucessWithDelay(interwal: 3)
            imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
            
            imageUploader?.upload(image: image, fileName: "Test1234", progress: { (progress) in
                if job == nil {
                    job = self.persistentStore.nextJob()
                    XCTAssertEqual(job?.0.jobState,JobState.processing)
                }
            }, completionHandler: { (result, error) in
                expectation.fulfill()
            })
            waitForExpectations(timeout: timeout, handler: nil)
        }
    }
    
    //Images are not deleted after upload, it is stored for the future use so that no need to download them again.
    //but if image is deleted from the app,delete method on the uploader is called which deletes the images from the persistance store. This test case tests the delete of photo
    func testDeleteOfPhoto() {
        if let image = UnitTestHelper.imageToTest() {
            let expectation = self.expectation(description: "Upload should succeed")
            imageUploader?.upload(image: image, fileName: "Test1234", progress: { (progress) in
            }, completionHandler: { (result, error) in
                expectation.fulfill()
            })
            waitForExpectations(timeout: timeout, handler: nil)
            let imageBeforeDelete = persistentStore.image(forJobID: "Test1234")
            XCTAssertTrue((imageBeforeDelete != nil))
            imageUploader?.delete(photoID: "Test1234")
            let imageAfterDelete = persistentStore.image(forJobID: "Test1234")
            XCTAssertNil(imageAfterDelete)
        }
    }
    
    //Test for the pending images after upload error
    func testUploadErrorAndPendingCount() {
        uploadClient.testCase = .sucessWithDelay(interwal: 0.3)
        imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
        if let image = UnitTestHelper.imageToTest() {
            let expectation = self.expectation(description: "Upload should succeed")
            var result:[String:String]?
            var error: NSError?
            uploadClient.testCase = .error
            imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
            imageUploader?.upload(image: image, fileName: "123") { (response, inError) in
                result = response
                error = inError
                expectation.fulfill()
            }
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssertNil(result, "result should be nil")
            XCTAssertNotNil(error, "error should not be nil")
            XCTAssertNotNil(self.persistentStore.nextPendingJob())
        }
    }
    
    //This tests offline upload/adding images in offline where images are queued in persistance store as the first step, upload pending images method uploads to server when network comes online or app is launched again
    func testUploadPendingImage() {
        if let image = UnitTestHelper.imageToTest() {
            //If an image is added for upload, if app is offline- image is enqueued. When test is running in online, if we call  imageUploader?.upload() method, it will finish the upload immediately. Hence we are performing enqueue operation directly which is exactly the upload() function does in offline state
            _ = persistentStore.enqueue(jobID: "123",state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "145", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "125", state: .pending, image: image)
            imageUploader?.uploadPendingImages()
            let expectation = self.expectation(description: "Upload should succeed")
            DispatchQueue.main.asyncAfter(deadline:.now() + .seconds(6), execute: {
                expectation.fulfill()
            })
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssertNil(persistentStore.nextPendingJob())
        }
    }
    
    
    //Basically if there is a failure, nextPendingJob() should not be in procesing state
    func testUploadPendingImageFailure() {
        uploadClient.testCase = .error
        imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
        if let image = UnitTestHelper.imageToTest(){
            
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            imageUploader?.uploadPendingImages()
            let expectation = self.expectation(description: "Upload should succeed")
            DispatchQueue.main.asyncAfter(deadline:.now() + .seconds(1), execute: {
                expectation.fulfill()
            })
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssert(persistentStore.nextJob()?.0.jobState != .processing)
        }
    }

    
    //Test bulk upload where every every enqueued is uploaded immediately
    func testBulkUpload() {
        if let image = UnitTestHelper.imageToTest() {
            
            _ = persistentStore.enqueue(jobID: "1TestReport1", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "2TestReport2", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "2TestReport1", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "3TestReport2", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "100TestReport5", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "101TestReport7", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "102TestReport8", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "103TestReport9", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "100TestReport10", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "101TestReport21", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "3TestReport1", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "109TestReport2", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "4TestReport1", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "115TestReport2", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "5TestReport1", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "117TestReport2", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "6TestReport1", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "119TestReport2", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "7TestReport1", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "122TestReport2", state: .pending, image: image)
            
            uploadClient.testCase = .sucessWithDelay(interwal: 0.1)
            imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
            imageUploader?.uploadPendingImages()
            let expectation = self.expectation(description: "Upload should succeed")
            DispatchQueue.main.asyncAfter(deadline:.now() + .seconds(10), execute: {
                expectation.fulfill()
            })
            waitForExpectations(timeout: timeout, handler: nil)
            XCTAssertTrue((imageUploader?.hasUploadedAllImages())!)
        }
    }
    
    
    
    
    //Test upload under delay from network
    func testLatencyInNetwork() {
        if let image = UnitTestHelper.imageToTest() {
            _ = persistentStore.enqueue(jobID: "101", state: .pending, image: image)
            uploadClient.testCase = .sucessWithDelay(interwal:2)
            imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
            imageUploader?.upload(image: image, fileName: "123") { (response, inError) in
            }
            let expectation = self.expectation(description: "Upload should succeed")
            DispatchQueue.main.asyncAfter(deadline:.now() + .seconds(4), execute: {
                expectation.fulfill()
            })
            waitForExpectations(timeout: timeout, handler: nil)
            guard let isSucess = imageUploader?.hasUploadedAllImages() else {
                XCTFail()
                return
            }
            XCTAssertTrue(isSucess)
        }
    }
    
    /// Tests how uploader behaves under network latency and network error
    func testNetworkErrorAndRetry() {
        if let image = UnitTestHelper.imageToTest() {
            _ = persistentStore.enqueue(jobID: "101", state: .pending, image: image)
            uploadClient.testCase = .errorWithDelay(interwal:1)
            imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
            imageUploader?.upload(image: image, fileName: "123") { (response, inError) in
            }
            uploadClient.testCase = .success
            imageUploader = PhotoUploader(client: uploadClient, persistenceStore: persistentStore)
            imageUploader?.upload(image: image, fileName: "123") { (response, inError) in
            }
            let expectation = self.expectation(description: "Upload should succeed")
            DispatchQueue.main.asyncAfter(deadline:.now() + .seconds(4), execute: {
                expectation.fulfill()
            })
            waitForExpectations(timeout: timeout, handler: nil)
            guard let isSucess = imageUploader?.hasUploadedAllImages() else {
                XCTFail()
                return
            }
            XCTAssertTrue(isSucess)
        }
    }
    
    
    /// Creates a mockuploader object which will be used to stimulate different network situations
    class MockUploader:ImageUploaderProtocol
    {
        enum TestCase {
            //Immediate return with success
            case success
            //Return success with specified delay
            case sucessWithDelay(interwal:TimeInterval)
            //Return error immediately
            case error
            //Return error with delay
            case errorWithDelay(interwal:TimeInterval)
        }
        
        var testCase: TestCase = .success
        
        //Mock upload request
        func upload(data: Data, fileName: String, progress: ((Progress) -> Void)?, completionHandler: @escaping UploadCompletionHandler) -> ImageUploaderRequestProtocol? {
            
            var response = [String:AnyObject]()
            response["secure_url"] = "https://testurl.com" as AnyObject
            response["public_id"] = fileName as AnyObject
            response["versionNo"] = "123" as AnyObject
            
            let error = NSError(domain: "",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "testError"])
            switch testCase {
            case .success:
                completionHandler(response,nil)
            case .sucessWithDelay(let interwal):
                DispatchQueue.main.asyncAfter(deadline: .now() + interwal) {
                    completionHandler(response,nil)
                }
            case .error:
                completionHandler(nil,error)
                
            case .errorWithDelay(let interwal):
                DispatchQueue.main.asyncAfter(deadline: .now() + interwal) {
                    completionHandler(response,nil)
                }
            }
            return MockRequest()
        }
    }
    
    class MockRequest:ImageUploaderRequestProtocol
    {
        func cancel() {
        }
    }
}
    
    
    //Tests the integration of image uploader with cloudinary client.
    //Here actual API call is made. These API's will fail if there is no network.
    class PhotoUploaderIntegrationTests: XCTestCase {
        
        //It is expected that image upload does not take more than 30 seconds
        let timeout: TimeInterval = 30.0
        
        //Image uploader class that takes images and uploads them
        var imageUploader:PhotoUploader?
        
        //Local store on where all the images are stored
        var persistentStore: PersistentStore!
        
        
        // MARK: - Lifcycle
        override func setUp() {
            super.setUp()
            //setup the local store with test folder
            persistentStore = PersistentStore(folderName:"TestStore")
            if let config = CLDConfiguration(cloudinaryUrl: "cloudinary://425626134859393:7V2WaZcYzniWxvSm9Qi1BfKsWG4@deekshith") {
                let client = CloudinaryUploadClient(config:config)
                imageUploader = PhotoUploader(client: client, persistenceStore: persistentStore)
            }
        }
        
        override func tearDown() {
            super.tearDown()
            _ = persistentStore.deleteStorage()
        }
        
        //Takes a image and uploads to cloudinary. Test should yield correct result. Note these tests depend on active network connection. API failure might happen which is failure use case for this test case
        func testUploadImage() {
            if let image = UnitTestHelper.imageToTest() {
                let expectation = self.expectation(description: "Upload should succeed")
                var result:[String:String]?
                var error: NSError?
                imageUploader?.upload(image: image, fileName: "123") { (response, inError) in
                    result = response
                    error = inError
                    expectation.fulfill()
                }
                waitForExpectations(timeout: timeout, handler: nil)
                XCTAssertNotNil(result, "result should not be nil")
                XCTAssertNotNil(result?["remoteURL"]!, "result should not be nil")
                XCTAssertNil(error, "error should be nil")
            }
        }
        
        //Every upload request is stored in the form of jobs and after upload, job in pendigng state should be reduced.
        func testPendingJobCountAfterUploading() {
            if let image = UnitTestHelper.imageToTest() {
                let expectation = self.expectation(description: "Upload should succeed")
                var result:[String:String]?
                imageUploader?.upload(image: image, fileName: "123") { (response, inError) in
                    result = response
                    expectation.fulfill()
                }
                waitForExpectations(timeout: timeout, handler: nil)
                XCTAssertNotNil(result, "result should not be nil")
                XCTAssertNil(persistentStore.nextPendingJob(), "error should be nil")
            }
        }
       
        
        //Images are not deleted after upload, it is stored for the future use so that no need to download them again.
        //but if image is deleted from the app,delete method on the uploader is called which deletes the images from the persistance store. This test case tests the delete of photo
        func testDeleteOfPhoto() {
            if let image = UnitTestHelper.imageToTest() {
                let expectation = self.expectation(description: "Upload should succeed")
                imageUploader?.upload(image: image, fileName: "Test1234", progress: { (progress) in
                }, completionHandler: { (result, error) in
                    expectation.fulfill()
                })
                waitForExpectations(timeout: timeout, handler: nil)
                let imageBeforeDelete = persistentStore.image(forJobID: "Test1234")
                XCTAssertTrue((imageBeforeDelete != nil))
                imageUploader?.delete(photoID: "Test1234")
                let imageAfterDelete = persistentStore.image(forJobID: "Test1234")
                XCTAssertNil(imageAfterDelete)
            }
        }
}
