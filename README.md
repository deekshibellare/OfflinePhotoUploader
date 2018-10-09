# Offline Photo Uploader

Supports image upload in offline. The library uploads the images to any source which confirms to `ImageUploaderRequestProtocol` when network is found.

Has two modules 

1. PersistentStore - Backing layer for storing images
2. PhotoUploader - Picks up images from persitent store and shedules for upload


Example app uses cloudinary SDK to demonstate upload using `ImageUploaderRequestProtocol` protocol

Unit tests are added with dependency injection principle.
Integration tests with cloudinary SDK also added

