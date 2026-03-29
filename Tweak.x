#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import "SSZipArchive/SSZipArchive.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Tweak.h"
#include <dlfcn.h>

@implementation ExtractionUIHandler

+ (instancetype)sharedHandler {
    static ExtractionUIHandler *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)showOverlayAndStartTask {
    UIWindow *window = [ExportManager getKeyWindow];
    
    // 1. 创建全屏遮罩 (毛玻璃效果)
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurEffectView.frame = window.bounds;
    blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayView = blurEffectView;

	UIView *container = blurEffectView.contentView;

	UIStackView *stackView = [[UIStackView alloc] init];
	stackView.axis = UILayoutConstraintAxisVertical;
	stackView.spacing = 10;
	stackView.alignment = UIStackViewAlignmentFill;
	stackView.frame = CGRectMake(50, window.center.y - 75, window.bounds.size.width - 100, 150);

	[container addSubview:stackView];
	stackView.center = container.center;

	// 添加状态标签
	self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.numberOfLines = 3;
	self.statusLabel.font = [UIFont systemFontOfSize:12];
    [stackView addArrangedSubview:self.statusLabel];

	// 添加标题标签
	self.titleLabel = [[UILabel alloc] init];
	self.titleLabel.text = @"准备抽取...";
	self.titleLabel.textColor = [UIColor whiteColor];
	self.titleLabel.textAlignment = NSTextAlignmentCenter;
	[stackView addArrangedSubview:self.titleLabel];
    
    // 添加总进度条
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(50, window.center.y, window.bounds.size.width - 100, 20);
    self.progressView.progress = 0;
    [stackView addArrangedSubview:self.progressView];
    
	// 添加副进度标签
	self.subStatusLabel = [[UILabel alloc] init];
	self.subStatusLabel.text = @"正在处理书籍...";
	self.subStatusLabel.textColor = [UIColor whiteColor];
	self.subStatusLabel.textAlignment = NSTextAlignmentCenter;
	[stackView addArrangedSubview:self.subStatusLabel];

	// 添加副进度条
	self.subProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	self.subProgressView.frame = CGRectMake(50, window.center.y + 30, window.bounds.size.width - 100, 20);
	self.subProgressView.progress = 0;
	[stackView addArrangedSubview:self.subProgressView];
    
    [window addSubview:self.overlayView];
}
@end



@implementation ExportManager
+ (instancetype)shared {
	static ExportManager *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[ExportManager alloc] init];
		instance.canceled = NO;
	});
	return instance;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (id)getRootViewController {
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

+ (id)getKeyWindow {
	return [UIApplication sharedApplication].keyWindow;
}
#pragma clang diagnostic pop

- (void)showExtractionAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"EbixDumper" 
                                                                   message:@"检测到Ebix文件，是否开始抽取？" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // 阻止抽取流程
		self.canceled = YES;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"开始" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[ExtractionUIHandler sharedHandler] showOverlayAndStartTask];
    }]];
    
    [[ExportManager getRootViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)showSuccessAlertWithCount:(NSInteger)count {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"抽取完成" 
																   message:[NSString stringWithFormat:@"成功抽取 %ld 本书籍！", (long)count] 
															preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];

	[[ExportManager getRootViewController] presentViewController:alert animated:YES completion:nil];
}

- (NSString *)loadKeychainValueForKey:(NSString *)key service:(NSString *)service {
    // 1. 创建查询字典
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword; // 指定数据类型
    query[(__bridge id)kSecAttrService] = service;                        // 服务的名字
    query[(__bridge id)kSecAttrAccount] = key;                            // 具体的键（Account）
    query[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;         // 要求返回原始数据
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;   // 只返回一个结果

    CFTypeRef result = NULL;
    // 2. 调用 API 进行匹配
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    if (status == errSecSuccess) {
        // 3. 将返回的 NSData 转换为字符串
        NSData *data = (__bridge_transfer NSData *)result;
        NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return value;
    } else {
        if (status == errSecItemNotFound) {
            NSLog(@"[EbookJapanDumper] Keychain 中未找到对应的键");
        } else {
            NSLog(@"[EbookJapanDumper] Keychain 读取错误，错误码: %d", (int)status);
        }
        return nil;
    }
}

- (void)startAutomatedDump {
    NSString *tempDir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"DumpedBooks"];
    // [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil]; // 清空旧数据
	NSLog(@"[EbookJapanDumper] Created temporary directory for dumping: %@", tempDir);
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];
	NSLog(@"[EbookJapanDumper] Starting scan of app data directory...");
    
    // 2. 扫描 App 数据目录 (假设书籍在 Documents)
    NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSLog(@"[EbookJapanDumper] Scanning directory: %@", docsPath);
    // 获取 URL 数组，跳过隐藏文件
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:[NSURL fileURLWithPath:docsPath]
                                          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsRegularFileKey]
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        errorHandler:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSMutableArray<NSURL *> *ebixFiles = [NSMutableArray array];
		for (NSURL *fileURL in enumerator) {
			NSString *filename = [fileURL lastPathComponent];
			if (![filename.pathExtension.lowercaseString isEqualToString:@"ebix"]) continue;
			[ebixFiles addObject:fileURL];
		}

		if (ebixFiles.count > 0) {
			// 询问用户是否开始抽取
			dispatch_async(dispatch_get_main_queue(), ^{
				[self showExtractionAlert];
			});
			// 等待用户响应后继续执行抽取流程
			while ([ExtractionUIHandler sharedHandler].overlayView == nil) {
				[NSThread sleepForTimeInterval:0.1];
				if (self.canceled) {
					NSLog(@"[EbookJapanDumper] User canceled the extraction process.");
					self.canceled = NO; // 重置状态以便下次使用
					return;
				}
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			[ExtractionUIHandler sharedHandler].statusLabel.text = [NSString stringWithFormat:@"发现 %lu 个Ebix文件...", (unsigned long)ebixFiles.count];
			[ExtractionUIHandler sharedHandler].progressView.progress = 0;
			[ExtractionUIHandler sharedHandler].subProgressView.progress = 0;
			[ExtractionUIHandler sharedHandler].subStatusLabel.text = @"等待抽取...";
		});

		for (int idx = 0; idx < ebixFiles.count; idx++) {
			NSURL *fileURL = ebixFiles[idx];
			NSString *filename = [fileURL lastPathComponent];

			NSString *uuid = [self loadKeychainValueForKey:@"uuid" service:@"jp.co.yahoo.ebookjapan"];
			NSString *uuidGenDate = [self loadKeychainValueForKey:@"generated_date" service:@"jp.co.yahoo.ebookjapan"];
			NSLog(@"[EbookJapanDumper] Loaded UUID: %@, Generated Date: %@", uuid, uuidGenDate);

			EBIWrapperEnvID *envIDGenerator = [[EBIWrapperEnvID alloc] init];
			NSArray *parts = [envIDGenerator createNewBuildIdentifier:uuid uuidGenDate:uuidGenDate];
			NSString *envID = [parts firstObject];
			NSLog(@"[EbookJapanDumper] Generated envID: %@", envID);

			EBIWrapperEbixFile *ebixFile = [[EBIWrapperEbixFile alloc] init];
			NSLog(@"[EbookJapanDumper] Attempting to open file: %@ with envID: %@", filename, envID);

			if ([ebixFile openInstanceWithPath:[fileURL path] envID:envID]) {
				[ebixFile enableMultiThread];
				[ebixFile setImageDataAsJpeg:YES];

				EBIWrapperEbixFileInfo *fileInfo = [ebixFile getFileInfo];
				if (![fileInfo.bodyFormat isEqualToString:@"ebi"] || ![fileInfo.bodyFormatVersion hasPrefix:@"HVQBOOK"]) {
					[ebixFile closeInstance];
					NSLog(@"[EbookJapanDumper] Currently unsupported format: %@, %@", fileInfo.bodyFormat, fileInfo.bodyFormatVersion);
					continue;
				}
				NSLog(@"[EbookJapanDumper] Successfully opened file: %@ with envID: %@", filename, envID);
				EBIWrapperEbixBookInfo *bookInfo = [ebixFile getBookInfo];
				NSLog(@"[EbookJapanDumper] Processing book: %@ by %@", bookInfo.bookName, bookInfo.writerName);
				NSString *bookDirName = [NSString stringWithFormat:@"%@ - %@", bookInfo.bookName, bookInfo.writerName];
				
				NSString *zipPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.cbz", bookDirName]];

				SSZipArchive *archive = [[SSZipArchive alloc] initWithPath:zipPath];
				BOOL isOpen = [archive open];

				if (!isOpen) {
					NSLog(@"[EbookJapanDumper] Failed to create zip archive at path: %@", zipPath);
					return;
				}

				dispatch_async(dispatch_get_main_queue(), ^{
					[ExtractionUIHandler sharedHandler].titleLabel.text = [NSString stringWithFormat:@"正在处理书籍 %d/%lu", idx + 1, (unsigned long)ebixFiles.count];
					[ExtractionUIHandler sharedHandler].statusLabel.text = [NSString stringWithFormat:@"%@", bookInfo.bookName];
				});

				int imageCount = [ebixFile getImageCount];
				for (int i = 0; i < imageCount; i++) {
					@autoreleasepool {

						dispatch_async(dispatch_get_main_queue(), ^{
							[ExtractionUIHandler sharedHandler].subStatusLabel.text = [NSString stringWithFormat:@"正在处理图像 %d/%lu", i + 1, (unsigned long)imageCount];
						});

						NSDictionary *imageData = [ebixFile imageDataDictAtIndex:i];
						NSString *fileName = nil;
						NSData *dataToWrite = nil;

						if (![imageData[@"error"] intValue]) {;
							NSData *data = imageData[@"data"];

							uint8_t *bytes = (uint8_t *)data.bytes;
							if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
								// JPEG Passby
								fileName = [NSString stringWithFormat:@"%04d.jpg", i + 1];
								dataToWrite = data;
							} 
							else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
								// BMP Conversion
								// Basic conversion using UIImage
								UIImage *bmpImage = [UIImage imageWithData:data];
								dataToWrite = UIImagePNGRepresentation(bmpImage);

								fileName = [NSString stringWithFormat:@"%04d.png", i + 1];
							} else {
								fileName = [NSString stringWithFormat:@"%04d.bin", i + 1];
								dataToWrite = data;
								NSLog(@"[EbookJapanDumper] Warning: Unrecognized image format for page %d, saving as .bin", i + 1);
							}
							NSLog(@"[EbookJapanDumper] Decrypted page %d/%d for book: %@", i + 1, imageCount, bookInfo.bookName);
						} else {
							NSLog(@"[EbookJapanDumper] 第 %d 页解密失败，跳过. ERROR: %@", i + 1, imageData[@"error"]);
							fileName = [NSString stringWithFormat:@"%04d_error.txt", i + 1];
							dataToWrite = [[NSString stringWithFormat:@"Failed to decrypt page %d. Error code: %@", i + 1, imageData[@"error"]] dataUsingEncoding:NSUTF8StringEncoding];
						}

						if (dataToWrite && fileName) {
							[archive writeData:dataToWrite filename:fileName withPassword:nil];
						}

						dispatch_async(dispatch_get_main_queue(), ^{
							float imgProgress = (float)(i + 1) / imageCount;
							[ExtractionUIHandler sharedHandler].progressView.progress = (float)(idx + imgProgress) / ebixFiles.count;
							[ExtractionUIHandler sharedHandler].subProgressView.progress = (float)(i + 1) / imageCount;
						});
					}
				}
				[ebixFile closeInstance];
				BOOL success = [archive close];

				if (success) {
					NSLog(@"[EbookJapanDumper] 成功导出: %@", zipPath);
				} else {
					NSLog(@"[EbookJapanDumper] 导出失败: %@", zipPath);
				}
				dispatch_async(dispatch_get_main_queue(), ^{
					[ExtractionUIHandler sharedHandler].progressView.progress = (float)(idx + 1) / ebixFiles.count;
				});
			} else {
				NSLog(@"[EbookJapanDumper] 无法打开文件: %@, envID: %@", filename, envID);
				[[NSString stringWithFormat:@"Failed to open file: %@ with %@", filename, envID] writeToFile:[tempDir stringByAppendingPathComponent:@"error_log.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
			}
		}
        
        // 3. 完成后切回主线程，触发文件选择器
        dispatch_async(dispatch_get_main_queue(), ^{
			[[ExtractionUIHandler sharedHandler].overlayView removeFromSuperview];
			// [self showSuccessAlertWithCount:ebixFiles.count];
			[self presentFolderPickerWithTempDir:tempDir];
        });
    });
}

- (void)presentFolderPickerWithTempDir:(NSString *)tempDir {
    self.currentTempDir = tempDir; // 记录下来供回调使用

	NSError *error = nil;
	NSArray<NSURLResourceKey> *keys = @[NSURLIsDirectoryKey];
    NSArray<NSURL *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:tempDir]
                                            includingPropertiesForKeys:keys
                                                               options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 error:&error];
    
    if (error) {
        NSLog(@"[EbookJapanDumper] %@", error.localizedDescription);
        return;
    }

    NSMutableArray<NSURL *> *filesToExport = [NSMutableArray array];
    for (NSURL *url in contents) {
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        
        if (isDirectory && ![isDirectory boolValue]) {
            [filesToExport addObject:url];
        }
    }

    if (filesToExport.count == 0) {
        NSLog(@"[EbookJapanDumper] No files found in temp directory to export.");
        return;
    }
    
    // 开启文件夹选择模式
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:filesToExport asCopy:NO];
	
    picker.delegate = self;
	picker.allowsMultipleSelection = NO;
    
    // 获取当前最顶层的 ViewController 来弹出
    [[ExportManager getRootViewController] presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *targetFolderURL = urls.firstObject;
	NSLog(@"[EbookJapanDumper] User selected folder: %@", targetFolderURL.path);

	[[NSFileManager defaultManager] removeItemAtPath:self.currentTempDir error:nil];
}
@end

typedef void (*MSHookMessageEx_t)(Class _class, SEL message, IMP hook, IMP *old);
static MSHookMessageEx_t MSHookMessageEx_p = NULL;

typedef void (*UIWindow_makeKeyAndVisible_t)(id self, SEL _cmd);
static UIWindow_makeKeyAndVisible_t UIWindow_makeKeyAndVisible_p = NULL;

static void makeKeyAndVisible(id self, SEL _cmd) {
	UIWindow_makeKeyAndVisible_p(self, _cmd);
	
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		NSLog(@"[EbookJapanDumper] UIWindow makeKeyAndVisible called, setting up floating button...");
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[[ExportManager shared] startAutomatedDump];
		});
	});
}


// id __cdecl -[EBIWrapperEnvID makeSeedDataBlock](EBIWrapperEnvID *self, SEL)
typedef NSString* (*EBIWrapperEnvID_makeSeedDataBlock_p)(id self, SEL _cmd);
static EBIWrapperEnvID_makeSeedDataBlock_p EBIWrapperEnvID_makeSeedDataBlock_o = NULL;
static NSString* EBIWrapperEnvID_makeSeedDataBlock_hook(id self, SEL _cmd) {
	return @"1145001145001145001145000000000000000000000000DD";
}

__attribute__((constructor))
static void tweakConstructor() {
	if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"jp.co.yahoo.ebookjapan"]) {
		return;
	}

    MSHookMessageEx_p = (MSHookMessageEx_t)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (!MSHookMessageEx_p) {
        return;
    }

	MSHookMessageEx_p(
		NSClassFromString(@"EBIWrapperEnvID"), 
		@selector(makeSeedDataBlock), 
		(IMP)EBIWrapperEnvID_makeSeedDataBlock_hook, 
		(IMP *)&EBIWrapperEnvID_makeSeedDataBlock_o
	);

	MSHookMessageEx_p(UIWindow.class, @selector(makeKeyAndVisible), (IMP)makeKeyAndVisible, (IMP *)&UIWindow_makeKeyAndVisible_p);
}