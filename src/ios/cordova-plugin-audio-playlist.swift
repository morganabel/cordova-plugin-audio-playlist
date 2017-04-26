import AVFoundation
import MediaPlayer

@objc(CordovaPluginAudioPlaylist) class CordovaPluginAudioPlaylist : CDVPlugin {
    let avQueuePlayer:AVQueuePlayer = AVQueuePlayer();

    @objc(initAudio:)
    func initAudio(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        NotificationCenter.default.addObserver(self, selector: #selector(CordovaPluginAudioPlaylist.audioSessionInterrupted(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        //NotificationCenter.default.addObserver(self, selector: #selector(CordovaPluginAudioPlaylist.audioSessionInterrupted(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            let _ = try AVAudioSession.sharedInstance().setActive(true)

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK,
                messageAs: "success"
            )
        } catch let error as NSError {
            print("an error occurred when setting audio session category.\n \(error)")
            pluginResult.messageAs = "an error occurred when setting audio session category. \(error)";
        }

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(addItem:)
    func addItem(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        let data = command.arguments[0] as? Dictionary<String, AnyObject!> ?? [String:AnyObject!]()
        let song = AVPlayerItem(url: data["url"] as! String)
        let autoPlay = data["autoPlay"] as? Bool ?? false

        self!.avQueuePlayer.insert(avSongItem, after: nil)
        if autoPlay {
            self!.avQueuePlayer.play();
        }


        //display now playing info on control center
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: data["title"], MPMediaItemPropertyArtist: data["artist"]]

        //Load artwork.
        DispatchQueue.global(qos: .default).async(execute: {() -> Void in
            var image: UIImage? = nil
            if !cover.isEqual("") {
                if cover.hasPrefix("http://") || cover.hasPrefix("https://") {
                    var imageURL = URL(string: cover)
                    var imageData = Data(contentsOf: imageURL)
                    image = UIImage(data: imageData)
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
            var cgref: CGImageRef? = image?.cgImage
            var cim: CIImage? = image?.ciImage
            if cim != nil || cgref != nil {
                DispatchQueue.main.async(execute: {() -> Void in
                    if NSClassFromString("MPNowPlayingInfoCenter") {
                        var artwork = MPMediaItemArtwork(image: image)
                        var center = MPNowPlayingInfoCenter.default
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

        pluginResult.status = CDVCommandStatus_OK

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(play:)
    func play(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        avQueuePlayer.play();
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: "success"
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(pause:)
    func pause(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        avQueuePlayer.pause();
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: "success"
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    class func audioSessionInterrupted(_ notification:Notification)
    {
        print("interruption received: \(notification)")
    }

    func remoteControlReceivedWithEvent(_ receivedEvent:UIEvent)  {
        if (receivedEvent.type == .remoteControl) {
            switch receivedEvent.subtype {
            case .remoteControlTogglePlayPause:
                if avQueuePlayer.rate > 0.0 {
                    avQueuePlayer.pause()
                } else {
                    avQueuePlayer.play()
                }
            case .remoteControlPlay:
                avQueuePlayer.play()
            case .remoteControlPause:
                avQueuePlayer.pause()
            default:
                print("received sub type \(receivedEvent.subtype) Ignoring")
            }
        }
    }
}