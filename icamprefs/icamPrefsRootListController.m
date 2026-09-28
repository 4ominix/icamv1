#import "icamPrefsRootListController.h"
#import <spawn.h>

@implementation icamPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateLabelText];
}

- (void)updateLabelText {
    // Read from preferences
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.yourcompany.icamv1.plist"];
    NSString *path = prefs[@"kMediaPath"];
    
    PSSpecifier *labelSpec = [self specifierForID:@"kMediaPathLabel"];
    if (labelSpec) {
        if (path && path.length > 0) {
            [labelSpec setProperty:[path lastPathComponent] forKey:@"label"];
        } else {
            [labelSpec setProperty:@"Chưa có (Dùng mặc định)" forKey:@"label"];
        }
        [self reloadSpecifier:labelSpec];
    }
}

- (void)selectMedia:(PSSpecifier *)specifier {
    NSArray *types = @[ UTTypeImage, UTTypeMovie, UTTypeVideo, UTTypeMPEG4Movie ];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        NSURL *url = urls.firstObject;
        
        BOOL canAccess = [url startAccessingSecurityScopedResource];
        
        // Target directory: /var/jb/Library/icamv1
        NSString *targetDir = @"/var/jb/Library/icamv1";
        NSFileManager *fm = [NSFileManager defaultManager];
        
        if (![fm fileExistsAtPath:targetDir]) {
            [fm createDirectoryAtPath:targetDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0777} error:nil];
        }
        
        NSString *ext = [url pathExtension];
        NSString *targetPath = [targetDir stringByAppendingPathComponent:[NSString stringWithFormat:@"custom_media.%@", ext]];
        
        if ([fm fileExistsAtPath:targetPath]) {
            [fm removeItemAtPath:targetPath error:nil];
        }
        
        NSError *error = nil;
        [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:targetPath] error:&error];
        
        if (canAccess) {
            [url stopAccessingSecurityScopedResource];
        }
        
        if (!error) {
            // Chmod 0777 so apps can read it
            [fm setAttributes:@{NSFilePosixPermissions: @0777} ofItemAtPath:targetPath error:nil];
            
            // Save to prefs
            NSString *prefsPath = @"/var/jb/var/mobile/Library/Preferences/com.yourcompany.icamv1.plist";
            NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath] ?: [NSMutableDictionary dictionary];
            prefs[@"kMediaPath"] = targetPath;
            [prefs writeToFile:prefsPath atomically:YES];
            [fm setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:prefsPath error:nil];
            
            // Notify tweak
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourcompany.icamv1/ReloadPrefs"), NULL, NULL, YES);
            
            [self updateLabelText];
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thành công" message:@"Đã cập nhật media ảo mới!" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi" message:[error localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

- (void)respring {
    pid_t pid;
    const char* args[] = {"killall", "backboardd", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
}

@end
