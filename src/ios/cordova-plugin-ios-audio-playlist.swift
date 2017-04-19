import AVFoundation
import MediaPlayer

@objc(CordovaPluginIosAudioPlaylist) class CordovaPluginIosAudioPlaylist : CDVPlugin {
    let avQueuePlayer:AVQueuePlayer = AVQueuePlayer();

    @objc(initAudio:)
    func initAudio(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )

        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            let _ = try AVAudioSession.sharedInstance().setActive(true)

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK,
                messageAs: "success"
            )
        } catch let error as NSError {
            print("an error occurred when audio session category.\n \(error)")
        }

        self.commandDelegate!.send(
            pluginResult,
            callbackId: command.callbackId
        )
    }
}