import Foundation

class DownloadQueue : NSObject, DownloaderDelegate {
    var queuedFiles: [(url: String, destinationFileUrl: String, itemId: String)] = []
    var active = true;
    var downloading = false;
    var delegate: DownloaderDelegate?
    var activeDownloader : Downloader?

    init(delegate: DownloaderDelegate? = nil)
    {
        self.delegate = delegate
    }

    func resume() {
        active = true;
        downloadQueued()
    }

    func pause() {
        active = false;
    }

    func addFile(url: String, destinationFileUrl: String, itemId: String) {
        queuedFiles.append((url: url, destinationFileUrl: destinationFileUrl, itemId: itemId))
        downloadQueued()
    }

    func downloadQueued() {
        guard active && !downloading && queuedFiles.count > 0 else { return }

        let url = URL(string: queuedFiles[0].url)
        activeDownloader = Downloader(delegate: self, itemId: queuedFiles[0].itemId)
        activeDownloader!.download(url: url!, destination: URL(string: queuedFiles[0].destinationFileUrl)!)
        downloading = true
    }

    func downloaderOnProgress(_ downloader: Downloader) {
        self.delegate?.downloaderOnProgress(downloader)
    }

    func downloaderOnComplete(_ downloader: Downloader) {
        queuedFiles.remove(at: 0)
        downloading = false
        downloadQueued()
        self.delegate?.downloaderOnComplete(downloader)
    }

    func downloaderOnError(_ downloader: Downloader) {
        queuedFiles.remove(at: 0)
        downloading = false
        downloadQueued()
        self.delegate?.downloaderOnError(downloader)
    }
}