//
//  PersistenceStoreTests.swift
//  PhotoUploaderTests
//
//  Created by Deekshith Bellare on 07/10/18.
//  Copyright © 2018 Deekshith Bellare. All rights reserved.
//

import XCTest

@testable import PhotoUploader

class PersistenceStoreTests: XCTestCase {
    
    var persistentStore: PersistentStore!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        persistentStore = PersistentStore(folderName: "TestStore")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        _ = persistentStore.deleteStorage()
    }
    
    func testInit()
    {
        XCTAssertNotNil(persistentStore)
    }
    
    func testInitNilPath()
    {
        let persistentStore = PersistentStore(folderName:nil)
        XCTAssertNil(persistentStore)
    }
    
    func testInitNilPathWithMaximumImagesToQueue()
    {
        let persistentStore = PersistentStore(folderName: nil)
        XCTAssertNil(persistentStore)
    }
    
    func testInitWithPath()
    {
        let persistentStore = PersistentStore(folderName:"Test")
        XCTAssertNotNil(persistentStore)
    }
    
    //Image conversion to data test cases
    func testDeserialiseEmptyImage()
    {
        let data = persistentStore?.convertToData(image:UIImage())
        XCTAssertNil(data)
    }
    
    func testDeserialiseJPGImage()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let data = persistentStore?.convertToData(image:image)
            XCTAssertNotNil(data)
        }
    }
    
    func testDeserialisePNGImage()
    {
        let testBundle = Bundle(for: type(of: self))
        if let image = UIImage(named:"minisingle", in:testBundle, compatibleWith: nil)
        {
            let data = persistentStore?.convertToData(image:image)
            XCTAssertNotNil(data)
        }
    }
    
    func testCreateStoreFolder()
    {
        if let persistentStore = PersistentStore(folderName:"Test")
        {
            let (url,_) = persistentStore.createStore(folderName:"Test")
            XCTAssertNotNil(url)
            let (storeURL,_) = persistentStore.storeURL(folderName:"Test")
            XCTAssertTrue(isFolder(url))
            XCTAssertTrue(isFolder(storeURL!))
            XCTAssertEqual(url,storeURL)
            let isSucess = persistentStore.deleteStorage()
            XCTAssertTrue(isSucess)
        }
    }
    
    func testInvalidPathCreateStore()
    {
        
        let (_,isSucess) = persistentStore.createStore(folderName:"notafolder/test")
        XCTAssert(isSucess == false)
    }
    
    func testSaveJob()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            XCTAssertTrue(sucess)
        }
    }
    
    func testGetJobID()
    {
        if let image = UnitTestHelper.imageToTest() {
            _ = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            let job = persistentStore.job(jobID: "501")
            XCTAssert(job != nil, "Job with 501 not found")
        }
    }
    
    func testNilJobID()
    {
        if let image = UnitTestHelper.imageToTest(){
            _ = persistentStore.enqueue(jobID: "502", state: .pending, image: image)
            let job = persistentStore.job(jobID: "501")
            XCTAssert(job == nil, "Job with 501 not found")
        }
    }
    
    func testNextJobEquality()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            XCTAssertTrue(sucess)
            
            if let (job,_) = persistentStore.nextJob()
            {
                XCTAssert(job.jobID == "501" , "JobID's are equal")
            }
        }
    }
    
    func testNextJobNullability()
    {
        let job = persistentStore.nextJob()
        XCTAssertTrue(job == nil)
    }
    
    func testJobDelete()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            XCTAssertTrue(sucess)
            persistentStore.removeJob(jobID:"501")
            let job = persistentStore.nextJob()
            XCTAssertTrue(job == nil)
            
        }
    }
    
    func testNextJobWithTwoJobs()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            let sucess2 = persistentStore.enqueue(jobID: "502", state: .pending, image: image)
            XCTAssertTrue(sucess)
            XCTAssertTrue(sucess2)
            if let (job,_) = persistentStore.nextJob() {
                XCTAssert(job.jobID == "501" , "JobID's are equal")
            }
        }
    }
    
    
    func testNextJobWithTwoJobsAndRemoveFirst()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            let sucess2 = persistentStore.enqueue(jobID: "502", state: .pending, image: image)
            XCTAssertTrue(sucess)
            XCTAssertTrue(sucess2)
            persistentStore.removeJob(jobID: "501")
            if let (job,_) = persistentStore.nextJob() {
                XCTAssert(job.jobID == "502" , "JobID's are equal")
            }
        }
    }
    
    func testNextJobWithTwoJobsAndRemoveSecond()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            let sucess2 = persistentStore.enqueue(jobID: "502", state: .pending, image: image)
            XCTAssertTrue(sucess)
            XCTAssertTrue(sucess2)
            persistentStore.removeJob(jobID: "502")
            if let (job,_) = persistentStore.nextJob() {
                XCTAssert(job.jobID == "501" , "JobID's are equal")
            }
        }
    }
    
    func testNextJobWithTwoJobsAndRemoveAll()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            let sucess2 = persistentStore.enqueue(jobID: "502", state: .pending, image: image)
            XCTAssertTrue(sucess)
            XCTAssertTrue(sucess2)
            persistentStore.removeJob(jobID: "502")
            persistentStore.removeJob(jobID: "501")
            let job = persistentStore.nextJob()
            XCTAssertTrue(job == nil)
        }
    }
    
    func testStateUpdateToUploadingImage()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            let status = persistentStore.updateStatus(forJobID:  "501", state: .processing)
            XCTAssertTrue(sucess)
            XCTAssertTrue(status)
            if let job = persistentStore.job(jobID: "501") {
                XCTAssert(job.jobID == "501" , "JobID's are equal")
                XCTAssertTrue(job.jobState == .processing, "job states are equal")
                XCTAssertTrue(sucess)
            }
        }
    }
    
    func testStateUpdateToUploadedImage()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID: "501", state: .pending, image: image)
            let status = persistentStore.updateStatus(forJobID:  "501", state: .processing)
            XCTAssertTrue(sucess)
            XCTAssertTrue(status)
            if let job = persistentStore.job(jobID: "501") {
                XCTAssert(job.jobID == "501" , "JobID's are equal")
                XCTAssertTrue(job.jobState == .processing, "job states are equal")
                XCTAssertTrue(sucess)
            }
        }
    }
    
    func testEnqueJobWithEmptyJobID()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            let sucess = persistentStore.enqueue(jobID:"", state: .pending, image: image)
            XCTAssertFalse(sucess)
        }
    }
    
    
    func testDuplicateEnque()
    {
        if let image = UnitTestHelper.imageToTest() {
            
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            let count = persistentStore.allJobs().count
            XCTAssertEqual(count, 1)
        }
    }
    
    func testDuplicateEnqueAndDelete()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            persistentStore.removeJob(jobID: "123", shouldDeleteImage: true)
            let count = persistentStore.allJobs().count
            XCTAssertEqual(count, 0)
        }
    }
    
    func testNextPendingJob()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            let result = persistentStore.nextPendingJob()
            XCTAssertNotNil(result, "result should not be nil")
            XCTAssertEqual(result?.0.jobID,"123")
        }
    }
    
    func testNextPendingJobAfterStateUpdateForTheFirst()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "125", state: .pending, image: image)
            _ = persistentStore.updateStatus(forJobID: "123", state:.processing)
            let result = persistentStore.nextPendingJob()
            XCTAssertNotNil(result, "result should not be nil")
            XCTAssertEqual(result?.0.jobID,"125")
        }
    }
    
    func testNextPendingAfterStateUpdateAndDelete()
    {
        if let image = UnitTestHelper.imageToTest()
        {
            
            _ = persistentStore.enqueue(jobID: "123", state: .pending, image: image)
            _ = persistentStore.enqueue(jobID: "125", state: .pending, image: image)
            _ = persistentStore.updateStatus(forJobID: "123", state:.processing)
            persistentStore.removeJob(jobID: "125", shouldDeleteImage: true)
            let result = persistentStore.nextPendingJob()
            XCTAssertNil(result, "result should be nil")
        }
    }
    
    //Utitlity functions
    private func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return true
            }
        }
        return false
    }
}
