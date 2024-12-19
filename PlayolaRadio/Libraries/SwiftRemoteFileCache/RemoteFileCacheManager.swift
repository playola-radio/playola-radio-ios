//
//  RemoteFileCacheManager.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/19/24.
//

import Foundation

public class RemoteFileCacheManager {
    /// a dictionary of all RemoteFileDownloaders currently being downloaded.  The remoteFileURL is used as the key.
    var inProgress:Dictionary<URL, RemoteFileDownloader>! = Dictionary()

    /// the folder to store the files in.
    public var fileDirectoryURL:URL!

    /// a dictionary that holds all currently active RemoteFilePriorityLevels for this service.  remoteFileURL is used as the key
    public var filePriorities:Dictionary<URL,RemoteFilePriorityLevel>! = Dictionary()


    /// a soft size limit for the folder in bytes.  Once this is reached files with lower priority will be deleted.  Default is 52428800 (50 MB)
    public var maxFolderSize:Int = 52428800

    public init(subFolder:String! = "AudioFiles") {
        // create folder if it does not already exist
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectoryURL:URL = URL(fileURLWithPath: paths[0])
        fileDirectoryURL = documentsDirectoryURL.appendingPathComponent(subFolder)

        let fileManager = FileManager.default
        do
        {
            try fileManager.createDirectory(atPath: fileDirectoryURL.path, withIntermediateDirectories: false, attributes: nil)
        }
        catch let error as NSError
        {
            print(error.localizedDescription);
        }
    }

    public func localURLFromRemoteURL(_ remoteURL:URL) -> URL {
        let filename = remoteURL.lastPathComponent
        return fileDirectoryURL.appendingPathComponent(filename)
    }

    func reportDownloadComplete(_ remoteURL:URL) {
        self.inProgress.removeValue(forKey: remoteURL)
    }

    public func pauseDownloads() {
        for (_, cachedObject) in self.inProgress
        {
            cachedObject.pauseDownload()
        }
    }

    // adapted from http://stackoverflow.com/questions/32814535/how-to-get-directory-size-with-swift-on-os-x
    func calculateFolderCacheSize() -> Int {
        // check if the url is a directory
        var bool: ObjCBool = false
        var folderFileSizeInBytes = 0

        if FileManager().fileExists(atPath: self.fileDirectoryURL.path, isDirectory: &bool) {
            if bool.boolValue {
                // lets get the folder files
                let fileManager =  FileManager.default
                let files = try! fileManager.contentsOfDirectory(at: self.fileDirectoryURL, includingPropertiesForKeys: nil, options: [])
                for file in files {
                    folderFileSizeInBytes +=  try! (fileManager.attributesOfItem(atPath: file.path) as NSDictionary).fileSize().hashValue
                }
                // format it using NSByteCountFormatter to display it properly
                let  byteCountFormatter =  ByteCountFormatter()
                byteCountFormatter.allowedUnits = .useBytes
                byteCountFormatter.countStyle = .file
                return folderFileSizeInBytes
            }
        }
        return folderFileSizeInBytes
    }

    public func pruneCache() {
        var currentSize = self.calculateFolderCacheSize()
        while (currentSize > self.maxFolderSize) {
            if let fileTuples = self.getDeletableFiles() {
                for i in 0..<fileTuples.count {
                    if (fileTuples[i].2 == RemoteFilePriorityLevel.doNotDelete) {
                        continue
                    } else {
                        self.deleteFile(fileTuples[i].0)
                        currentSize = self.calculateFolderCacheSize()
                        if (currentSize < self.maxFolderSize) {
                            break
                        }
                    }
                }
            }
        }
    }

    public func deleteFile(_ localURL:URL) {
        // Create a FileManager instance
        let fileManager = FileManager.default

        do {
            try fileManager.removeItem(atPath: localURL.path)
        } catch let error as NSError {
            print("Error trying to delete file from audioCache: \(error)")
        }
    }

    // Adapted from http://stackoverflow.com/questions/33032293/swift-2-ios-get-file-list-sorted-by-creation-date-more-concise-solution
    func getDeletableFiles() -> Array<(URL, TimeInterval, RemoteFilePriorityLevel)>? {
        // comparison
        func deletability(_ tuple1:(URL, TimeInterval, RemoteFilePriorityLevel), tuple2:(URL, TimeInterval, RemoteFilePriorityLevel)) -> Bool {
            if (tuple1.2 == tuple2.2) {
                return tuple1.1 < tuple2.1
            } else {
                return tuple1.2.rawValue < tuple2.2.rawValue
            }
        }

        if let urlArray = try? FileManager.default.contentsOfDirectory(at: fileDirectoryURL,
                                                                       includingPropertiesForKeys: [URLResourceKey.localizedNameKey, URLResourceKey.contentModificationDateKey], options:.skipsHiddenFiles) {
            var tupleMap = urlArray.map {
                url -> (URL, TimeInterval, RemoteFilePriorityLevel) in
                var lastModified : AnyObject?
                _ = try? (url as NSURL).getResourceValue(&lastModified, forKey: URLResourceKey.contentModificationDateKey)
                return (url, lastModified?.timeIntervalSinceReferenceDate ?? 0, self.filePriorities[url] ?? RemoteFilePriorityLevel.unspecified)
            }

            tupleMap = tupleMap.sorted(by: deletability) // sort descending modification dates
            return tupleMap
        } else {
            return nil
        }
    }

    public func downloadFile(_ remoteURL:URL) -> RemoteFileDownloader {
        // if a downloader is already in progress for that file
        if let downloader = self.inProgress[remoteURL] {
            downloader.resumeDownload()
            return downloader
        }

        let downloader = RemoteFileDownloader(remoteURL: remoteURL, localURL: self.localURLFromRemoteURL(remoteURL))
        .onCompletion {
            (downloader) -> Void in
            self.inProgress[downloader.remoteURL] = nil
            self.pruneCache()
        }

        downloader.beginDownload()
        self.inProgress[remoteURL] = downloader
        return downloader
    }

    public func completeFileExists(remoteFileURL:URL) -> Bool {
        let localURL = self.localURLFromRemoteURL(remoteFileURL)
        return FileManager.default.fileExists(atPath: localURL.path)
    }
}
