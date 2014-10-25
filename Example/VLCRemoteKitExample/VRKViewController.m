/*
 * VLCRemoteKit
 *
 * Copyright 2014-present Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import "VRKViewController.h"
#import "VRKPlaylistViewController.h"
#import "VLCRemoteKit.h"
#import "Colours.h"

static NSString * const CONFIGURATION_SEGUE_NAME = @"VRKConfigurationSegue";
static NSString * const PLAYLIST_SEGUE_NAME      = @"VRKPlaylistSegue";

@interface VRKViewController () <VRKPlaylistViewControllerDelegate>
@property (nonatomic, strong) UIPopoverController *popover;
@property (nonatomic, strong) VLCHTTPClient       *vlcClient;
@property (nonatomic, strong) VLCRemotePlayer     *player;

@end

@implementation VRKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self client:nil connectionStatusDidChanged:VLCClientConnectionStatusDisconnected];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:CONFIGURATION_SEGUE_NAME]) {
        if ([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
            _popover                   = [(UIStoryboardPopoverSegue *)segue popoverController];
            _popover.delegate          = self;
            _editBarButtonItem.enabled = NO;
        }
        
        VRKConfigurationViewController *configViewConfiguration = [segue destinationViewController];
        configViewConfiguration.delegate                        = self;
    }
    else if ([[segue identifier] isEqualToString:PLAYLIST_SEGUE_NAME]) {
        VRKPlaylistViewController *vc = segue.destinationViewController;
        vc.playlist                   = _vlcClient.playlist;
        vc.delegate                   = self;
    }
}

#pragma mark - Public Methods

- (IBAction)connectAction:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *ip                 = [userDefaults stringForKey:@"ip"];
    NSString *password           = [userDefaults stringForKey:@"password"];
    
    if (_vlcClient.connectionStatus == VLCClientConnectionStatusDisconnected && ip && password) {
        _vlcClient          = [VLCHTTPClient clientWithHostname:ip port:8080 username:nil password:password];
        _vlcClient.delegate = self;
        _player             = _vlcClient.player;
        _player.delegate    = self;
        
        [_vlcClient connectWithCompletionHandler:NULL];
    }
    else if (!ip || !password) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"The VLC Remote Kit IP and/or password is not configured" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)disconnectAction:(id)sender
{
    if (_vlcClient.connectionStatus != VLCClientConnectionStatusDisconnected) {
        [_vlcClient disconnectWithCompletionHandler:NULL];
    }
}

- (IBAction)playAction:(id)sender
{
    [_player playItemWithId:5];
}

- (IBAction)stopAction:(id)sender
{
    [_player stop];
}

- (IBAction)togglePauseAction:(id)sender
{
    if ([_player isPlaying]) {
        [_player pause];
    }
    else {
        [_player play];
    }
}

- (IBAction)toggleFullScreenAction:(id)sender
{
    _player.fullscreen = ![_player isFullscreen];
}

- (IBAction)seekAction:(id)sender
{
    NSTimeInterval seekTime       = _player.duration * _progressSlider.value;
    _player.currentTime = seekTime;
}

- (IBAction)volumeAction:(id)sender
{
    _player.volume = _volumeSlider.value;
}

#pragma mark - Private Methods

#pragma mark - UIPopoverController Delegate Methods

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    _editBarButtonItem.enabled = YES;
}

#pragma mark - VRKConfiguration Delegate Methods

- (void)configurationDidChanged
{
    if (_popover) {
        _editBarButtonItem.enabled = YES;
        [_popover dismissPopoverAnimated:YES];
    }
    else {
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
    
    [self disconnectAction:_connectButton];
}

- (void)needsDismissConfiguration
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - VLCRemoteClient Delegate Methods

- (void)client:(id)client connectionStatusDidChanged:(VLCClientConnectionStatus)status
{
    switch (status) {
        case VLCClientConnectionStatusDisconnected:
            _statusLabel.text            = @"Status: disconnected";
            _filenameLabel.text          = @"disconnected";
            _progressSlider.value        = 0;
            _volumeSlider.value          = 0;
            _statusLabel.textColor       = [UIColor whiteColor];
            _statusLabel.backgroundColor = [UIColor black25PercentColor];
            break;
        case VLCClientConnectionStatusConnecting:
            _statusLabel.text            = @"Status: connecting...";
            _statusLabel.textColor       = [UIColor black25PercentColor];
            _statusLabel.backgroundColor = [UIColor buttermilkColor];
            break;
        case VLCClientConnectionStatusConnected:
            _statusLabel.text            = @"Status: connected";
            _statusLabel.textColor       = [UIColor black25PercentColor];
            _statusLabel.backgroundColor = [UIColor moneyGreenColor];
            break;
        case VLCClientConnectionStatusUnauthorized:
            _statusLabel.text            = @"Status: unauthorized";
            _filenameLabel.text          = @"unauthorized";
            _statusLabel.textColor       = [UIColor black25PercentColor];
            _statusLabel.backgroundColor = [UIColor tomatoColor];
            break;
        case VLCClientConnectionStatusUnreachable:
            _statusLabel.text            = @"Status: unreachable";
            _filenameLabel.text          = @"unreachable";
            _statusLabel.textColor       = [UIColor black25PercentColor];
            _statusLabel.backgroundColor = [UIColor tomatoColor];
            break;
        default:
            break;
    }
    
    _stopButton.enabled             = (status == VLCClientConnectionStatusConnected);
    _toogePauseButton.enabled       = (status == VLCClientConnectionStatusConnected);
    _toggleFullscreenButton.enabled = (status == VLCClientConnectionStatusConnected);
    _progressSlider.enabled         = (status == VLCClientConnectionStatusConnected);
    _volumeSlider.enabled           = _progressSlider.enabled;
    
    if (status == VLCClientConnectionStatusDisconnected) {
        [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        [_connectButton removeTarget:self action:@selector(disconnectAction:) forControlEvents:UIControlEventTouchUpInside];
        [_connectButton addTarget:self action:@selector(connectAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    else {
        [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        [_connectButton removeTarget:self action:@selector(connectAction:) forControlEvents:UIControlEventTouchUpInside];
        [_connectButton addTarget:self action:@selector(disconnectAction:) forControlEvents:UIControlEventTouchUpInside];
    }
}

#pragma mark - VLCRemote Delegate Methods

- (void)remoteObjectDidChanged:(id<VLCRemoteProtocol>)remote
{
    if (_player == remote) {
        NSString *fullscreenTitle = (_player.fullscreen) ? @"Exit Full-Screen Mode" : @"Enter Full-Screen Mode";
        [_toggleFullscreenButton setTitle:fullscreenTitle forState:UIControlStateNormal];
        
        NSString *pauseTitle = (_player.playing) ? @"Pause Playback" : @"Resume Playback";
        [_toogePauseButton setTitle:pauseTitle forState:UIControlStateNormal];
        
        _filenameLabel.text = _player.filename ?: @"No Media Currently Playing";
        
        NSInteger currentTime = (NSInteger)_player.currentTime;
        NSInteger ctSeconds   = currentTime % 60;
        NSInteger ctMinutes   = (currentTime / 60) % 60;
        NSInteger ctHours     = (currentTime / 3600);
        
        NSInteger duration = _player.duration;
        NSInteger dSeconds = duration % 60;
        NSInteger dMinutes = (duration / 60) % 60;
        NSInteger dHours   = (duration / 3600);
        
        _currentTimeLabel.text  = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)ctHours, (long)ctMinutes, (long)ctSeconds];
        _durationLabel.text     = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)dHours, (long)dMinutes, (long)dSeconds];
        _progressSlider.value   = currentTime / (duration * 1.0f);
        _progressSlider.enabled = !(_player.playbackState == VLCRemotePlayerPlaybackStateStopped);
        
        _volumeLabel.text     = [NSString stringWithFormat:@"Volume: %d%%", (int)(_player.volume * 100)];
        _volumeSlider.value   = _player.volume;
        _volumeSlider.enabled = _progressSlider.enabled;
    }
}

#pragma mark - VRKPlaylistViewController Delegate Methods

- (void)itemDidSelected:(VLCPlaylistItem *)item {
    [_player playItemWithId:item.identifier];
    
    [self dismissViewControllerAnimated:true completion:nil];
}

@end
