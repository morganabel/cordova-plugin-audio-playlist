//
// Jukebox.swift
//
// Copyright (c) 2015 Teodor Patraş
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import AVFoundation
import MediaPlayer

// MARK: - Custom types -

public protocol JukeboxDelegate: class {
    func jukeboxStateDidChange(_ jukebox : Jukebox)
    func jukeboxTrackChange(_ jukebox : Jukebox)
    func jukeboxPlaybackProgressDidChange(_ jukebox : Jukebox)
    func jukeboxDidLoadItem(_ jukebox : Jukebox, item : JukeboxItem)
    func jukeboxDidUpdateMetadata(_ jukebox : Jukebox, forItem: JukeboxItem)
    func jukeboxError(_ jukebox : Jukebox, item: JukeboxItem)
}

// MARK: - Public methods extension -

extension Jukebox {
    
    /**
     Starts item playback.
     */
    public func play() {
        play(atIndex: playIndex)
    }
    
    /**
     Plays the item indicated by the passed index
     
     - parameter index: index of the item to be played
     */
    public func play(atIndex index: Int) {
        guard index < queuedItems.count && index >= 0 else {
            if queuedItems.count > 0 && autoLoop {
                replay()
            }
            return
        }
        
        configureBackgroundAudioTask()
        
        if queuedItems[index].playerItem != nil && playIndex == index {
            resumePlayback()
        } else {
            if let item = currentItem?.playerItem {
                unregisterForPlayToEndNotification(withItem: item)
            }
            playIndex = index
            
            if let asset = queuedItems[index].playerItem?.asset {
                playCurrentItem(withAsset: asset)
            } else {
                loadPlaybackItem()
            }
            
            delegate?.jukeboxTrackChange(self)
            preloadNextAndPrevious(atIndex: playIndex)
        }
        updateInfoCenter()
    }
    
    /**
     Pauses the playback.
     */
    public func pause() {
        stopProgressTimer()
        player?.pause()
        state = .paused
    }
    
    /**
     Stops the playback.
     */
    public func stop() {
        invalidatePlayback()
        state = .ready
        UIApplication.shared.endBackgroundTask(backgroundIdentifier)
        backgroundIdentifier = UIBackgroundTaskInvalid
        endBackgroundTask()
    }
    
    /**
     Starts playback from the beginning of the queue.
     */
    public func replay() {
        guard playerOperational else {return}
        stopProgressTimer()
        seek(toSecond: 0)
        play(atIndex: 0)
    }

    public func setAutoLoop(shouldAutoLoop shouldLoop: Bool) {
        autoLoop = shouldLoop
    }
    
    /**
     Plays the next item in the queue.
     */
    public func playNext() {
        guard playerOperational else {return}
        play(atIndex: playIndex + 1)
    }
    
    /**
     Restarts the current item or plays the previous item in the queue
     */
    public func playPrevious() {
        guard playerOperational else {return}
        play(atIndex: playIndex - 1)
    }
    
    /**
     Restarts the playback for the current item
     */
    public func replayCurrentItem() {
        guard playerOperational else {return}
        seek(toSecond: 0, shouldPlay: true)
    }

    /**
     Checks if the current track is the last track.
     */
    public func isLastTrack() -> Bool {
        if playIndex >= queuedItems.count - 1 {
            return true
        } else {
            return false
        }
    }

    /**
    Checks if playlist currently empty.
    */
    public func isEmpty() -> Bool {
        if (queuedItems != nil && queuedItems.count > 0) {
            return false
        } else {
            return true
        }
    }

    public func getPlayIndex() -> Int {
        return playIndex
    }

    public func getTotalTrackCount() -> Int {
        return queuedItems.count
    }
    
    /**
     Seeks to a certain second within the current AVPlayerItem and starts playing
     
     - parameter second: the second to seek to
     - parameter shouldPlay: pass true if playback should be resumed after seeking
     */
    public func seek(toSecond second: Int, shouldPlay: Bool = false) {
        guard let player = player, let item = currentItem else {return}
        
        player.seek(to: CMTimeMake(Int64(second), 1))
        item.update()
        if shouldPlay {
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: 1.0)
            } else {
                player.play()
            }

            if state != .playing {
                state = .playing
            }
        }
        delegate?.jukeboxPlaybackProgressDidChange(self)
    }
    
    /**
     Appends and optionally loads an item
     
     - parameter item:            the item to be appended to the play queue
     - parameter loadingAssets:   pass true to load item's assets asynchronously
     */
    public func append(item: JukeboxItem, loadingAssets: Bool) {
        queuedItems.append(item)
        item.delegate = self
        if loadingAssets {
            if queuedItems.count == 1 {
                state = .loading
            }
            item.loadPlayerItem()
        }
        print("Item appended to jukebox playlist")
    }

    /**
    Removes an item from the play queue
    
    - parameter item: item to be removed
    */
    public func remove(item: JukeboxItem) {
        if let index = queuedItems.index(where: {$0.identifier == item.identifier}) {
            queuedItems.remove(at: index)
        }
    }
    
    /**
     Removes all items from the play queue matching the URL
     
     - parameter url: the item URL
     */
    public func removeItems(withURL url : URL) {
        let indexes = queuedItems.indexesOf({$0.URL as URL == url})
        for index in indexes {
            queuedItems.remove(at: index)
        }
    }

    /**
    Removes all items from the play queue.
     */
    public func removeAllItems(){
        queuedItems.removeAll(keepingCapacity: true)
        playIndex = 0
    }
}


// MARK: - Class implementation -

open class Jukebox: NSObject, JukeboxItemDelegate {
    
    public enum State: Int, CustomStringConvertible {
        case ready = 0
        case playing
        case paused
        case loading
        case failed
        case ended
        
        public var description: String {
            get{
                switch self
                {
                case .ready:
                    return "Ready"
                case .playing:
                    return "Playing"
                case .failed:
                    return "Failed"
                case .paused:
                    return "Paused"
                case .loading:
                    return "Loading"
                case .ended:
                    return "Ended"    
                }
            }
        }
    }
    
    // MARK:- Properties -
    
    fileprivate var player                       :   AVPlayer?
    fileprivate var progressObserver             :   AnyObject!
    fileprivate var backgroundIdentifier         =   UIBackgroundTaskInvalid
    fileprivate var backgroundTask               :   BackgroundTask?
    fileprivate var cacheDirectory               =   ""      
    fileprivate(set) open weak var delegate    :   JukeboxDelegate?
    
    fileprivate (set) open var playIndex       =   0
    fileprivate (set) open var queuedItems     :   [JukeboxItem]!
    fileprivate (set) open var autoLoop        =   false  
    fileprivate (set) open var state           =   State.ready {
        didSet {
            delegate?.jukeboxStateDidChange(self)
        }
    }
    // MARK:  Computed
    
    open var volume: Float{
        get {
            return player?.volume ?? 0
        }
        set {
            player?.volume = newValue
        }
    }
    
    open var currentItem: JukeboxItem? {
        guard playIndex >= 0 && playIndex < queuedItems.count else {
            return nil
        }
        return queuedItems[playIndex]
    }
    
    fileprivate var playerOperational: Bool {
        return player != nil && currentItem != nil
    }
    
    // MARK:- Initializer -
    
    /**
    Create an instance with a delegate and a list of items without loading their assets.
    
    - parameter delegate: jukebox delegate
    - parameter items:    array of items to be added to the play queue
    
    - returns: Jukebox instance
    */
    public required init?(delegate: JukeboxDelegate? = nil, items: [JukeboxItem] = [JukeboxItem]())  {
        self.delegate = delegate
        super.init()
        
        do {
            try configureAudioSession()
        } catch {
            print("[Jukebox - Error] \(error)")
            return nil
        }
        
        assignQueuedItems(items)
        configureObservers()
    }
    
    deinit{
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK:- JukeboxItemDelegate -
    
    func jukeboxItemDidFail(_ item: JukeboxItem) {
        stop()
        state = .failed
        self.delegate?.jukeboxError(self, item: item)
    }
    
    func jukeboxItemDidUpdate(_ item: JukeboxItem) {
        guard let item = currentItem else {return}
        updateInfoCenter()
        self.delegate?.jukeboxDidUpdateMetadata(self, forItem: item)
    }
    
    func jukeboxItemDidLoadPlayerItem(_ item: JukeboxItem) {
        delegate?.jukeboxDidLoadItem(self, item: item)
        let index = queuedItems.index(where: { (jukeboxItem) -> Bool in
            jukeboxItem.identifier == item.identifier
        })
        
        guard let playItem = item.playerItem
            , state == .loading && playIndex == index else {return}
        
        registerForPlayToEndNotification(withItem: playItem)
        startNewPlayer(forItem: playItem)
    }

    func jukeboxItemReadyToPlay(_ item: JukeboxItem) {
        play()
    }
    
    // MARK:- Private methods -
    
    // MARK: Playback
    
    fileprivate func updateInfoCenter() {
        guard let item = currentItem else {return}
        
        let title = (item.meta.title ?? item.localTitle) ?? item.URL.lastPathComponent
        let currentTime = item.currentTime ?? 0
        let duration = item.meta.duration ?? 0
        let trackNumber = playIndex
        let trackCount = queuedItems.count
        
        var nowPlayingInfo : [String : AnyObject] = [
            MPMediaItemPropertyPlaybackDuration : duration as AnyObject,
            MPMediaItemPropertyTitle : title as AnyObject,
            MPNowPlayingInfoPropertyElapsedPlaybackTime : currentTime as AnyObject,
            MPNowPlayingInfoPropertyPlaybackQueueCount :trackCount as AnyObject,
            MPNowPlayingInfoPropertyPlaybackQueueIndex : trackNumber as AnyObject,
            MPMediaItemPropertyMediaType : MPMediaType.anyAudio.rawValue as AnyObject
        ]
        
        if let artist = item.meta.artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist as AnyObject?
        }
        
        if let album = item.meta.album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album as AnyObject?
        }
        
        if let img = currentItem?.meta.artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: img)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    fileprivate func playCurrentItem(withAsset asset: AVAsset) {
        queuedItems[playIndex].refreshPlayerItem(withAsset: asset)
        startNewPlayer(forItem: queuedItems[playIndex].playerItem!)
        guard let playItem = queuedItems[playIndex].playerItem else {return}
        registerForPlayToEndNotification(withItem: playItem)
    }
    
    fileprivate func resumePlayback() {
        if state != .playing {
            startProgressTimer()
            if let player = player {
                if #available(iOS 10.0, *) {
                    player.playImmediately(atRate: 1.0)
                } else {
                    player.play()
                }
            } else {
                currentItem!.refreshPlayerItem(withAsset: currentItem!.playerItem!.asset)
                startNewPlayer(forItem: currentItem!.playerItem!)
            }
            state = .playing
        }
    }
    
    fileprivate func invalidatePlayback(shouldResetIndex resetIndex: Bool = true) {
        stopProgressTimer()
        player?.pause()
        player = nil
        
        if resetIndex {
            playIndex = 0
        }
    }
    
    fileprivate func startNewPlayer(forItem item : AVPlayerItem) {
        invalidatePlayback(shouldResetIndex: false)
        player = AVPlayer(playerItem: item)
        player?.allowsExternalPlayback = false
        startProgressTimer()
        seek(toSecond: 0, shouldPlay: true)
        updateInfoCenter()
    }
    
    // MARK: Items related
    
    fileprivate func assignQueuedItems (_ items: [JukeboxItem]) {
        queuedItems = items
        for item in queuedItems {
            item.delegate = self
        }
    }
    
    fileprivate func loadPlaybackItem() {
        guard playIndex >= 0 && playIndex < queuedItems.count else {
            return
        }
        
        stopProgressTimer()
        player?.pause()
        queuedItems[playIndex].loadPlayerItem()
        state = .loading
    }
    
    fileprivate func preloadNextAndPrevious(atIndex index: Int) {
        guard !queuedItems.isEmpty else {return}
        
        if index - 1 >= 0 {
            queuedItems[index - 1].loadPlayerItem()
        }
        
        if index + 1 < queuedItems.count {
            queuedItems[index + 1].loadPlayerItem()
        }
    }
    
    // MARK: Progress tracking
    
    fileprivate func startProgressTimer(){
        guard let player = player , player.currentItem?.duration.isValid == true else {return}
        progressObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.5, Int32(NSEC_PER_SEC)), queue: nil, using: { [unowned self] (time : CMTime) -> Void in
            self.timerAction()
        }) as AnyObject!
    }
    
    fileprivate func stopProgressTimer() {
        guard let player = player, let observer = progressObserver else {
            return
        }
        player.removeTimeObserver(observer)
        progressObserver = nil
    }
    
    // MARK: Configurations
    
    fileprivate func configureBackgroundAudioTask() {
        backgroundIdentifier =  UIApplication.shared.beginBackgroundTask (expirationHandler: { () -> Void in
            UIApplication.shared.endBackgroundTask(self.backgroundIdentifier)
            self.backgroundIdentifier = UIBackgroundTaskInvalid
        })

        // End backup background task.
        endBackgroundTask()
    }
    
    fileprivate func configureAudioSession() throws {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeDefault)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    
    fileprivate func configureObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(Jukebox.handleStall), name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(Jukebox.handleEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    // MARK:- Notifications -
    
    func handleAudioSessionInterruption(_ notification : Notification) {
        guard self.currentItem != nil else { return } // ignore if we are not currently playing
        guard let userInfo = notification.userInfo as? [String: AnyObject] else { return }
        guard let rawInterruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber else { return }
        guard let interruptionType = AVAudioSessionInterruptionType(rawValue: rawInterruptionType.uintValue) else { return }

        switch interruptionType {
        case .began: //interruption started
            self.pause()
        case .ended: //interruption ended
            if let rawInterruptionOption = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber {
                let interruptionOption = AVAudioSessionInterruptionOptions(rawValue: rawInterruptionOption.uintValue)
                if interruptionOption == AVAudioSessionInterruptionOptions.shouldResume {
                    self.resumePlayback()
                }
            }
        }
    }
    
    func handleStall() {
        player?.pause()
        if #available(iOS 10.0, *) {
            player?.playImmediately(atRate: 1.0)
        } else {
            player?.play()
        }
    }

    func handleEnterBackground() {
        guard player?.currentItem != nil else {return}

        if !isBackgroundTimeLongEnough() || state == .loading {
            backgroundTask = BackgroundTask(application: UIApplication.shared)
            backgroundTask!.begin()
        } else {
            if state != .playing {
                endBackgroundTask()
            }
        }
    }
    
    func playerItemDidPlayToEnd(_ notification : Notification){
        if playIndex >= queuedItems.count - 1 {
            if (autoLoop) {
                replay()
            } else {
                stop()
                state = .ended
            }
        } else {
            play(atIndex: playIndex + 1)
        }
    }
    
    func timerAction() {
        guard player?.currentItem != nil else {return}
        currentItem?.update()
        guard currentItem?.currentTime != nil else {return}
        updateInfoCenter()
        delegate?.jukeboxPlaybackProgressDidChange(self)

        if !isBackgroundTimeLongEnough() {
            handleEnterBackground()
        }
    }

    func endBackgroundTask() {
        backgroundTask?.end()
        backgroundTask = nil
    }

    fileprivate func isBackgroundTimeLongEnough() -> Bool {
        guard player?.currentItem != nil else {return true}

        let timeLeft = (currentItem?.meta.duration ?? 0) - (currentItem?.currentTime ?? 0)
        let bgTimeRemaining =  UIApplication.shared.backgroundTimeRemaining

        return bgTimeRemaining > timeLeft
    }
    
    fileprivate func registerForPlayToEndNotification(withItem item: AVPlayerItem) {
        NotificationCenter.default.addObserver(self, selector: #selector(Jukebox.playerItemDidPlayToEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
    }
    
    fileprivate func unregisterForPlayToEndNotification(withItem item : AVPlayerItem) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
    }
}

private extension Collection {
    func indexesOf(_ predicate: (Iterator.Element) -> Bool) -> [Int] {
        var indexes = [Int]()
        for (index, item) in enumerated() {
            if predicate(item){
                indexes.append(index)
            }
        }
        return indexes
    }
}

private extension CMTime {
    var isValid : Bool { return (flags.intersection(.valid)) != [] }
}