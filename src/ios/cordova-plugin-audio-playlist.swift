import AVFoundation
import MediaPlayer

@objc(CordovaPluginAudioPlaylist) class CordovaPluginAudioPlaylist : CDVPlugin, JukeboxDelegate {
    var jukebox: Jukebox!
    var callbackId: String? = nil

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
        NotificationCenter.default.addObserver(self, selector: #selector(self.remoteControlReceived), name: NSNotification.Name(rawValue: "receivedEvent"), object: nil)

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    deinit {
        UIApplication.shared.endReceivingRemoteControlEvents()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "receivedEvent"), object: nil)
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
        var autoPlay = data["autoPlay"].bool ?? false

        var image: UIImage? = nil
        var imageURL = URL(string: cover)
        do {
            var imageData = try Data(contentsOf: imageURL!)
            image = UIImage(data: imageData)
        } catch {
            print("error occurred loading image.\n \(error)")
        }

        let item = JukeboxItem(URL: URL(string: data["url"].stringValue)!)
        item.customMetaBuilder = JukeboxItem.MetaBuilder({ (builder) in
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

    func getCurrentSongStatus() -> [String:Any] {
        let item = jukebox.currentItem;

        var output = [String:Any]()

        return output
    }

    @objc func updateSongStatus(_ notification: Notification) {
        let songData: [String: Any] = getCurrentSongStatus()
        if callbackId != nil {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: songData)
            result!.keepCallback = true
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
                break
            case .paused, .failed, .ready:
                break
            }
        }

        print("Jukebox state changed to \(jukebox.state)")
    }

    func jukeboxDidUpdateMetadata(_ jukebox: Jukebox, forItem: JukeboxItem) {
        print("Item updated:\n\(forItem)")
    }

    @objc func remoteControlReceived(_ notification: Notification) {
        let event: UIEvent? = notification.object as! UIEvent?
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