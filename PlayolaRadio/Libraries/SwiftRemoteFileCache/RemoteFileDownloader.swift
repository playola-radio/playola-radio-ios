//
//  RemoteFileDownloader.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/19/24.
//

import Foundation
import Alamofire


// notification constants
let kAudioFileFinishedLoading:String = "audioFileFinishedLoading"

public class RemoteFileDownloader {
    var request:Alamofire.Request?
    public var downloadProgress:Double = 0.0
    public var remoteURL:URL
    public var localURL:URL
    public var suspended:Bool! = false
    public var updatedAt:Date!

    fileprivate var onCompletionBlocks:Array<((RemoteFileDownloader)->Void)> = Array()
    fileprivate var onProgressBlocks:Array<((RemoteFileDownloader)->Void)> = Array()
    fileprivate var onErrorBlocks:Array<((NSError)->Void)> = Array()


    public init(remoteURL:URL, localURL:URL) {
        self.remoteURL = remoteURL
        self.localURL = localURL
        self.updatedAt = Date()

        checkForFileExistence()
    }

    @discardableResult func checkForFileExistence() -> Bool {
        if (self.completeFileExists()) {
            self.downloadProgress = 1.0
            return true
        }
        return false
    }

    public func completeFileExists() -> Bool {
        return FileManager.default.fileExists(atPath: self.localURL.path)
    }

    @discardableResult public func onCompletion(_ onCompletionBlock:((RemoteFileDownloader)->Void)!) -> RemoteFileDownloader {
        self.onCompletionBlocks.append(onCompletionBlock)

        // go ahead and execute this one immediately if it's already complete
        if (self.downloadProgress == 1.0) {
            onCompletionBlock(self)
        }
        return self
    }

    @discardableResult public func onProgress(_ onProgressBlock:((RemoteFileDownloader)->Void)!) -> RemoteFileDownloader {
        self.onProgressBlocks.append(onProgressBlock)
        return self
    }

    @discardableResult public func onError(_ onErrorBlock:((NSError)->Void)!) -> RemoteFileDownloader {
        self.onErrorBlocks.append(onErrorBlock)
        return self
    }

    fileprivate func executeOnProgressBlocks() {
        for block in self.onProgressBlocks {
            block(self)
        }
    }

    fileprivate func executeOnErrorBlocks(_ error:NSError)
    {
        for block in self.onErrorBlocks {
            block(error)
        }
    }

    fileprivate func executeOnCompletionBlocks() {
        for block in self.onCompletionBlocks {
            block(self)
        }
    }

    public func beginDownload() {
        if (self.checkForFileExistence()) {
            self.executeOnCompletionBlocks()
        } else {
            let destination:DownloadRequest.Destination = { [localURL] _, _ in return (localURL, []) }

          self.request = AF.download(self.remoteURL, method: .get, to: destination)
                .downloadProgress {[weak self] (progress) -> Void in
                    self?.downloadProgress = progress.fractionCompleted
                    self?.updatedAt = Date()
                    self?.executeOnProgressBlocks()
                }.response {
                    [weak self] (response) -> Void in
                    if let error = response.error {
                        print("download error")
                        print(error)
                        self?.request?.cancel()
                        self?.request = nil
                        self?.executeOnErrorBlocks(error as NSError)

                    } else {
                        self?.executeOnCompletionBlocks()
                    }
                }
        }
    }

    public func pauseDownload() {
        if let _ = self.request {
            if (self.downloadProgress < 1.0) && !self.suspended {
                self.request?.suspend()
                self.suspended = true
            }
        }
    }

    public func resumeDownload() {
        // IF there's already a request
        if let _ = self.request {
            self.suspended = false
            self.request?.resume()
        } else if (self.downloadProgress < 1.0) {
            self.beginDownload()
        }
    }

    public func cancelDownload() {
        self.request?.cancel()
    }
}
