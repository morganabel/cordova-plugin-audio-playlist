#import "MainViewController+Audio.h"

@implementation MainViewController (RemoteControls)

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"receivedEvent" object:receivedEvent];
}

@end