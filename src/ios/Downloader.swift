// Adapted from https://stackoverflow.com/questions/28219848/how-to-download-file-in-swift

import Foundation

protocol DownloaderDelegate : class {
    func downloaderOnProgress(_ downloader: Downloader)
    func downloaderOnComplete(_ downloader: Downloader)
    func downloaderOnError(_ downloader: Downloader)
}

class Downloader : NSObject, URLSessionDownloadDelegate {

    var url : URL?
    var destinationUrl : URL?
    var delegate: DownloaderDelegate?
    var itemId : String?
    var progress = 0.0

    init(delegate: DownloaderDelegate? = nil, itemId: String)
    {
        self.delegate = delegate
        self.itemId = itemid
    }

    //is called once the download is complete
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    {
        //copy downloaded data to your documents directory with same names as source file
        let dataFromURL = NSData(contentsOf: location)
        dataFromURL?.write(to: self.destinationUrl, atomically: true)

        self.delegate?.downloaderOnComplete(self)
    }

    //this is to track progress
    private func URLSession(session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    {
        progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite) * 100
        self.delegate?.downloaderOnProgress(self)
    }

    // if there is an error during download this will be called
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        if error != nil
        {
            //handle the error
            print("Download completed with error: \(error!.localizedDescription)");
        }

        self.delegate?.downloaderOnError(self)
    }

    //method to be called to download
    func download(url: URL, destination: URL)
    {
        self.url = url
        self.destinationUrl = destination

        //download identifier can be customized. I used the "ulr.absoluteString"
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: url.absoluteString)
        let session = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()
    }
}