import AVFoundation
import MediaPlayer
import SwiftyJSON

@objc(CordovaPluginAudioPlaylist) class CordovaPluginAudioPlaylist : CDVPlugin {
    let avQueuePlayer:AVQueuePlayer = AVQueuePlayer();

    @objc(initAudio:)
    func initAudio(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        //let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance(), queue: nil, using: audioSessionInterrupted)
        //NotificationCenter.default.addObserver(self, selector: #selector(audioSessionInterrupted), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        //NotificationCenter.default.addObserver(self, selector: #selector(CordovaPluginAudioPlaylist.audioSessionInterrupted(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            let _ = try AVAudioSession.sharedInstance().setActive(true)

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )
        } catch let error as NSError {
            print("an error occurred when setting audio session category.\n \(error)")
        }

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc(clearPlaylist:)
    func clearPlaylist(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        avQueuePlayer.removeAllItems();

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
        let url = URL(string: data["url"].stringValue)
        let song = AVPlayerItem(url: url!)
        let autoPlay = data["autoPlay"].bool ?? false

        avQueuePlayer.insert(song, after: nil)
        if autoPlay {
            avQueuePlayer.play();
        }

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

        avQueuePlayer.play();
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

        avQueuePlayer.pause();
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK
        )

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }

    @objc func audioSessionInterrupted(_ notification:Notification)
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