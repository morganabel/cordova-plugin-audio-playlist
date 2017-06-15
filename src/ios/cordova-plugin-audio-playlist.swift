import AVFoundation
import MediaPlayer

@objc(CordovaPluginAudioPlaylist) class CordovaPluginAudioPlaylist : CDVPlugin, JukeboxDelegate {
    var jukebox: Jukebox!
    var callbackId: String? = nil
    var errorCallbackId: String? = nil
    var autoLoopPlaylist: Bool = false

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
        self.commandDelegate!.run(inBackground: {() -> Void in
            var pluginResult = CDVPluginResult(
                status: CDVCommandStatus_ERROR
            )

            // Stop and deinitialize playlist.
            self.jukebox.stop();
            self.jukebox.removeAllItems();
            self.jukebox = nil

            self.jukebox = Jukebox(delegate: self, items: [])!
            self.jukebox.setAutoLoop(shouldAutoLoop: self.autoLoopPlaylist)

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )

            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        })
    }

    @objc(getPlayIndex:)
    func getPlayIndex(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        let result = jukebox.getPlayIndex();

        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(isLastTrack:)
    func isLastTrack(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        let result = jukebox.isLastTrack();

        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(addItem:)
    func addItem(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {() -> Void in
            var pluginResult = CDVPluginResult(
                status: CDVCommandStatus_ERROR
            )

            let data = JSON(command.arguments[0]);
            let autoPlay = data["autoPlay"].bool ?? false
            
            self.doAddItem(data);

            if autoPlay {
                self.jukebox.play();
            }

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )

            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        })
    }

    @objc(addManyItems:)
    func addManyItems(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {() -> Void in
            var pluginResult = CDVPluginResult(
                status: CDVCommandStatus_ERROR
            )

            let tracks = command.arguments[0] as! [Any]

            for track in tracks {
                let data = JSON(track)
                self.doAddItem(data)
            }

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )

            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        })
    }

    @objc(toggle:)
    func toggle(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {() -> Void in
            var pluginResult = CDVPluginResult(
                status: CDVCommandStatus_ERROR
            )

            if self.jukebox.state == .playing {
                self.jukebox.pause()
            } else {
                self.jukebox.play()
            }

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )

            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        })
    }

    @objc(play:)
    func play(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {() -> Void in
            var pluginResult = CDVPluginResult(
                status: CDVCommandStatus_ERROR
            )

            self.jukebox.play()
            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )

            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        })
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

    @objc(next:)
    func next(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {() -> Void in
            var pluginResult = CDVPluginResult(
                status: CDVCommandStatus_ERROR
            )

            self.jukebox.playNext();
            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )

            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        })
    }

    @objc(previous:)
    func previous(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        jukebox.playPrevious();
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(stop:)
    func stop(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        jukebox.stop();
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(setAutoLoop:)
    func setAutoLoop(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        let autoPlay = command.arguments[0] as! Bool
        autoLoopPlaylist = autoPlay

        jukebox.setAutoLoop(shouldAutoLoop: autoPlay)
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(loop:)
    func loop(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        jukebox.replay();
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(watch:)
    func watch(_ command: CDVInvokedUrlCommand) {
        callbackId = command.callbackId
    }

    @objc(onError:)
    func onError(_ command: CDVInvokedUrlCommand) {
        errorCallbackId = command.callbackId
    }

    func doAddItem(_ data: JSON) {
        let id = data["id"].stringValue
        let title = data["title"].stringValue
        let artist = data["artist"].stringValue
        let album = data["album"].stringValue
        let cover = data["cover"].stringValue
        

        var image: UIImage? = nil
        let imageURL = URL(string: cover)
        do {
            let imageData = try Data(contentsOf: imageURL!)
            image = UIImage(data: imageData)
        } catch {
            print("error occurred loading image.\n \(error)")
        }

        let item = JukeboxItem(URL: URL(string: data["url"].stringValue)!, remoteUrl: URL(string: data["remoteUrl"].stringValue)!, localTitle: nil, id: data["id"].stringValue)
        item.customMetaBuilder = JukeboxItem.MetaBuilder({ (builder) in
            builder.title = title
            builder.artist = artist
            builder.artwork = image
            builder.album = album
        })

        let shouldLoadAssets = jukebox.isEmpty()

        jukebox.append(item: item, loadingAssets: shouldLoadAssets)
    }

    func getCurrentSongStatus(item: JukeboxItem? = nil) -> [String:Any] {
        let item = item ?? jukebox.currentItem

        var output = [String:Any]()
        output["trackId"] = item?.localId ?? ""
        output["duration"] = item?.meta.duration ?? 0
        output["currentTime"] = item?.currentTime ?? 0
        output["title"] = item?.meta.title ?? ""
        output["playIndex"] = jukebox.playIndex
        output["isLastTrack"] = jukebox.isLastTrack()

        switch jukebox.state {
        case .ready:
            output["state"] = "ready"
            break
        case .playing:
            output["state"] = "playing"
            break
        case .failed:
            output["state"] = "failed"
            break
        case .paused:
            output["state"] = "paused"
            break
        case .loading:
            output["state"] = "loading"
            break
        case .ended:
            output["state"] = "ended"
            break
        }

        return output
    }

    @objc func updateSongStatus() {
        let songData: [String: Any] = getCurrentSongStatus()
        if callbackId != nil {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: songData)
            result!.keepCallback = true
            commandDelegate.send(result, callbackId: self.callbackId)
        }
    }

    @objc func notifyOfFailure(item: JukeboxItem) {
        let songData: [String: Any] = getCurrentSongStatus(item: item)
        if errorCallbackId != nil {
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: songData)
            result!.keepCallback = true
            commandDelegate.send(result, callbackId: self.errorCallbackId)
        }
    }

    func jukeboxDidLoadItem(_ jukebox: Jukebox, item: JukeboxItem) {
        updateSongStatus()
        print("Jukebox did load: \(item.URL.lastPathComponent)")
    }

    func jukeboxPlaybackProgressDidChange(_ jukebox: Jukebox) {
        if let currentTime = jukebox.currentItem?.currentTime, let duration = jukebox.currentItem?.meta.duration {
            let value = Float(currentTime / duration)
        } else {

        }

        //updateSongStatus()
    }

    func jukeboxStateDidChange(_ jukebox: Jukebox) {
        if jukebox.state == .ready {

        } else if jukebox.state == .loading  {

        } else {
            switch jukebox.state {
            case .playing, .loading:
                break
            case .paused, .ended, .failed, .ready:
                break
            default:
                break
            }
        }

        updateSongStatus()

        print("Jukebox state changed to \(jukebox.state)")
    }

    func jukeboxDidUpdateMetadata(_ jukebox: Jukebox, forItem: JukeboxItem) {
        updateSongStatus()

        print("Item updated:\n\(forItem)")
    }

    func jukeboxError(_ jukebox : Jukebox, item: JukeboxItem) {
        notifyOfFailure(item: item)
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
                print("Remote Control Play Next")
                jukebox.playNext()
            case .remoteControlPreviousTrack:
                print("Remote Control Play Previous")
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