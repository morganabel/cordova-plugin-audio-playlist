import AVFoundation
import MediaPlayer

@objc(CordovaPluginAudioPlaylist) class CordovaPluginAudioPlaylist : CDVPlugin, JukeboxDelegate {
    var jukebox: Jukebox!

    @objc(initAudio:)
    func initAudio(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        do {
            // configure jukebox
            jukebox = Jukebox(delegate: self, items: [])!

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )
        } catch let error as NSError {
            print("an error occurred when setting audio session category.\n \(error)")
        }

        // MPNowPlayingInfoCenter
        UIApplication.shared.beginReceivingRemoteControlEvents()

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    deinit {

    }

    @objc(clearPlaylist:)
    func clearPlaylist(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        jukebox.removeAllItems();

        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(addItem:)
    func addItem(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        let data = JSON(command.arguments[0]);
        
        let title = data["title"].stringValue
        let artist = data["artist"].stringValue
        let album = data["album"].stringValue
        let cover = data["cover"].stringValue
        var autoPlay = data["autoPlay"].bool

        var image: UIImage? = nil
        var imageURL = URL(string: cover)
        do {
            var imageData = try Data(contentsOf: imageURL!)
            image = UIImage(data: imageData)
        } catch {
            print("error occurred loading image.\n \(error)")
        }

        let item = JukeboxItem(URL: URL(string: data["url"].stringValue)!)
        item.customMetaBuilder = JukeboxItemMetaBuilder({ (builder) in
            builder.title = title
            builder.artist = artist
            builder.artwork = image
            builder.album = album
        })

        jukebox.append(item: item, loadingAssets: true)

        if autoPlay {
            jukebox.play();
        }

        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(setMetadata:)
    func setMetadata(_ item: AVPlayerItem) {
        let asset = item.asset;
        var url = asset.url;

        var data = playerTracks[url]!

        let title = data["title"].stringValue
        let artist = data["artist"].stringValue
        let album = data["album"].stringValue
        let cover = data["cover"].stringValue

        //display now playing info on control center
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: title, MPMediaItemPropertyArtist: artist]

        //Load artwork.
        DispatchQueue.global(qos: .default).async(execute: {() -> Void in
            var image: UIImage? = nil
            if !cover.isEqual("") {
                if cover.hasPrefix("http://") || cover.hasPrefix("https://") {
                    var imageURL = URL(string: cover)
                    do {
                        var imageData = try Data(contentsOf: imageURL!)
                        image = UIImage(data: imageData)
                    } catch {
                        print("error occurred loading image.\n \(error)")
                    }
                }
                else if cover.hasPrefix("file://") {
                    var fullPath: String = cover.replacingOccurrences(of: "file://", with: "")
                    var fileExists: Bool = FileManager.default.fileExists(atPath: fullPath)
                    if fileExists {
                        image = UIImage(contentsOfFile: fullPath)
                    }
                }
                else {
                    var basePath: String? = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as? String)
                    var fullPath: String = "\(basePath)\(cover)"
                    var fileExists: Bool = FileManager.default.fileExists(atPath: fullPath)
                    if fileExists {
                        image = UIImage(named: fullPath)
                    }
                }
            }
            else {
                image = UIImage(named: "no-image")
            }
            var cgref: CGImage? = image?.cgImage
            var cim: CIImage? = image?.ciImage
            if cim != nil || cgref != nil {
                DispatchQueue.main.async(execute: {() -> Void in
                    if NSClassFromString("MPNowPlayingInfoCenter") != nil {
                        var artwork = MPMediaItemArtwork(image: image!)
                        var center = MPNowPlayingInfoCenter.default()
                        center.nowPlayingInfo = [
                            MPMediaItemPropertyArtist : artist,
                            MPMediaItemPropertyTitle : title,
                            MPMediaItemPropertyAlbumTitle : album,
                            MPMediaItemPropertyArtwork : artwork
                        ]
                    }
                })
            }
        })
    }

    @objc(toggle:)
    func toggle(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        if jukebox.state == .playing {
            jukebox.pause()
        } else {
            jukebox.play()
        }

        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(play:)
    func play(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        jukebox.play()
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(pause:)
    func pause(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        jukebox.pause();
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    func getCurrentSongStatus()) {
        let item = avQueuePlayer.currentItem;
        let asset = item!.asset;
        var url = asset.url;

        var data = playerTracks[url]!

        var output = [String, Any]()
        output["title"] = data["title"].stringValue
        output["artist"] = data["artist"].stringValue
        output["album"] = data["album"].stringValue
        output["cover"] = data["cover"].stringValue
        output["url"] = url
        output["currentTime"] = item.currentTime
        output["duration"] = item.duration
        
        switch item.status {
        case .readyToPlay:
            // Player item is ready to play.
            output["status"] = 1
        case .failed:
            // Player item failed. See error.
            output["status"] = 2
        case .unknown:
            // Player item is not yet ready.
            output["status"] = 0
        }

        return output
    }

    @objc func updateSongStatus(_ notification: Notification) {
        let songData: [String: Any] = getCurrentSongStatus()
        if callbackId {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: songData)
            result.keepCallbackAs = true
            commandDelegate.send(result, callbackId: self.callbackId)
        }
    }

    func jukeboxDidLoadItem(_ jukebox: Jukebox, item: JukeboxItem) {
        print("Jukebox did load: \(item.URL.lastPathComponent)")
    }

    func jukeboxPlaybackProgressDidChange(_ jukebox: Jukebox) {
        if let currentTime = jukebox.currentItem?.currentTime, let duration = jukebox.currentItem?.meta.duration {
            let value = Float(currentTime / duration)
        } else {

        }
    }

    func jukeboxStateDidChange(_ jukebox: Jukebox) {
        if jukebox.state == .ready {

        } else if jukebox.state == .loading  {

        } else {
            switch jukebox.state {
            case .playing, .loading:

            case .paused, .failed, .ready:

            }
        }

        print("Jukebox state changed to \(jukebox.state)")
    }

    func jukeboxDidUpdateMetadata(_ jukebox: Jukebox, forItem: JukeboxItem) {
        print("Item updated:\n\(forItem)")
    }

    override func remoteControlReceived(with event: UIEvent?) {
        if event?.type == .remoteControl {
            switch event!.subtype {
            case .remoteControlPlay :
                jukebox.play()
            case .remoteControlPause :
                jukebox.pause()
            case .remoteControlNextTrack :
                jukebox.playNext()
            case .remoteControlPreviousTrack:
                jukebox.playPrevious()
            case .remoteControlTogglePlayPause:
                if jukebox.state == .playing {
                    jukebox.pause()
                } else {
                    jukebox.play()
                }
            default:
                break
            }
        }
    }
}