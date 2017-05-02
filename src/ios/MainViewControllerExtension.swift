extension NSNotification.Name {
    static let onRecievedEvent = Notification.Name("on-recieved-event")
}

extension MainViewController {
    override func remoteControlReceived(withEvent receivedEvent: UIEvent) {
        NotificationCenter.default.post(name: .onRecievedEvent, object: receivedEvent)
    }
}