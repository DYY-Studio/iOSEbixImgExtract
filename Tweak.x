#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import "SSZipArchive/SSZipArchive.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <dlfcn.h>

@interface EBIWrapperEbixBookInfo : NSObject
@property (nonatomic, strong) NSString *bookName;
@property (nonatomic, strong) NSString *bookNameKana;
@property (nonatomic, strong) NSString *seriesName;
@property (nonatomic, strong) NSString *seriesNameKana;
@property (nonatomic, strong) NSString *writerName;
@property (nonatomic, strong) NSString *writerNameKana;
@property (nonatomic, strong) NSString *publisherName;
@property (nonatomic, strong) NSString *publisherNameKana;
@property (nonatomic, strong) NSString *bookClassID;
@property (nonatomic, strong) NSString *bookDate;
@property (nonatomic, strong) NSString *language;
@property (nonatomic, strong) NSString *isbn;
@property (nonatomic, strong) NSString *redistID;
@property (nonatomic, strong) NSString *bookID;
@property (nonatomic, strong) NSNumber *totalPages;
@property (nonatomic, strong) NSString *stitch;
@property (nonatomic, strong) NSString *volumeTitle;
@property (nonatomic, strong) NSString *volume;
@property (nonatomic, strong) NSNumber *titleID;
@property (nonatomic, strong) NSNumber *resolution;
@property (nonatomic, strong) NSNumber *volumeIndex;
@end

@interface EBIWrapperEnvID : NSObject
- (NSMutableArray *)createNewBuildIdentifier:(NSString *)uuid uuidGenDate:(NSString *)uuidGenDate;
@end

@interface EBIWrapperEbixFile : NSObject
- (bool)openInstanceWithPath:(NSString *)path envID:(NSString *)envID;
- (NSDictionary *)imageDataDictAtIndex:(int)index;
- (NSData *)imageDataAtIndex:(int)index;
- (int)getImageCount;
- (int)getMaxPage;
- (EBIWrapperEbixBookInfo *)getBookInfo;
- (void)closeInstance;
- (void)enableMultiThread;
- (void)setImageDataAsJpeg:(bool)asJpeg;
@end

@interface ExportManager : 	NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) NSString *currentTempDir;
@property (nonatomic, strong) UIWindow *floatingWindow;
+ (instancetype)shared;
- (void)startAutomatedDump;
- (NSString *)loadKeychainValueForKey:(NSString *)key service:(NSString *)service;
- (void)presentFolderPickerWithTempDir:(NSString *)tempDir;
@end

@implementation ExportManager
+ (instancetype)shared {
	static ExportManager *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[ExportManager alloc] init];
	});
	return instance;
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
		for (NSURL *fileURL in enumerator) {
			NSString *filename = [fileURL lastPathComponent];
			if (![filename.pathExtension.lowercaseString isEqualToString:@"ebix"]) continue;

			NSString *uuid = [self loadKeychainValueForKey:@"uuid" service:@"jp.co.yahoo.ebookjapan"];
			NSString *uuidGenDate = [self loadKeychainValueForKey:@"generated_date" service:@"jp.co.yahoo.ebookjapan"];
			NSLog(@"[EbookJapanDumper] Loaded UUID: %@, Generated Date: %@", uuid, uuidGenDate);

			EBIWrapperEnvID *envIDGenerator = [[EBIWrapperEnvID alloc] init];
			NSArray *parts = [envIDGenerator createNewBuildIdentifier:uuid uuidGenDate:uuidGenDate];
			NSString *envID = [parts firstObject];
			NSLog(@"[EbookJapanDumper] Generated envID: %@", envID);

			EBIWrapperEbixFile *ebixFile = [[EBIWrapperEbixFile alloc] init];
			NSLog(@"[EbookJapanDumper] Attempting to open file: %@ with envID: %@", filename, envID);
			[ebixFile enableMultiThread];
			[ebixFile setImageDataAsJpeg:YES];

			if ([ebixFile openInstanceWithPath:[fileURL path] envID:envID]) {
				NSLog(@"[EbookJapanDumper] Successfully opened file: %@ with envID: %@", filename, envID);
				EBIWrapperEbixBookInfo *bookInfo = [ebixFile getBookInfo];
				NSLog(@"[EbookJapanDumper] Processing book: %@ by %@", bookInfo.bookName, bookInfo.writerName);
				NSString *bookDirName = [NSString stringWithFormat:@"%@ - %@", bookInfo.bookName, bookInfo.writerName];
				NSString *bookDirPath = [tempDir stringByAppendingPathComponent:bookDirName];
				NSLog(@"[EbookJapanDumper] Created directory: %@", bookDirPath);
				[[NSFileManager defaultManager] createDirectoryAtPath:bookDirPath withIntermediateDirectories:YES attributes:nil error:nil];

				int imageCount = [ebixFile getImageCount];
				@autoreleasepool {
					for (int i = 0; i < imageCount; i++) {
						NSDictionary *imageData = [ebixFile imageDataDictAtIndex:i];
						NSLog(@"[EbookJapanDumper] Decrypting page %d/%d for book: %@", i + 1, imageCount, bookInfo.bookName);
						if (![imageData[@"error"] intValue]) {;
							NSData *data = imageData[@"data"];

							uint8_t *bytes = (uint8_t *)data.bytes;
							if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
								// JPEG Passby
								[data writeToFile:[bookDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%04d.jpg", i + 1]] atomically:YES];
							} 
							else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
								// BMP Conversion -> PNG
								UIImage *bmpImage = [UIImage imageWithData:data];
								NSData *pngData = UIImagePNGRepresentation(bmpImage);
								[pngData writeToFile:[bookDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%04d.png", i + 1]] atomically:YES];
							}
						} else {
							NSLog(@"[EbookJapanDumper] 第 %d 页解密失败，跳过. ERROR: %@", i + 1, imageData[@"error"]);
							NSString *errorPath = [bookDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%04d_error.txt", i + 1]];
							[errorPath writeToFile:errorPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
						}
					}
				}
				[ebixFile closeInstance];
				NSLog(@"[EbookJapanDumper] Please wait for compression: %@", bookInfo.bookName);
				NSString *zipPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.cbz", bookDirName]];
				BOOL success = [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:bookDirPath];

				if (success) {
					[[NSFileManager defaultManager] removeItemAtPath:bookDirPath error:nil]; // 删除临时文件夹
					NSLog(@"[EbookJapanDumper] 成功导出: %@", zipPath);
				} else {
					NSLog(@"[EbookJapanDumper] 导出失败: %@", zipPath);
				}
			} else {
				NSLog(@"[EbookJapanDumper] 无法打开文件: %@, envID: %@", filename, envID);
				[[NSString stringWithFormat:@"Failed to open file: %@ with %@", filename, envID] writeToFile:[tempDir stringByAppendingPathComponent:@"error_log.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
			}
		}
        
        // 3. 完成后切回主线程，触发文件选择器
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentFolderPickerWithTempDir:tempDir];
        });
    });
}

- (void)presentFolderPickerWithTempDir:(NSString *)tempDir {
    self.currentTempDir = tempDir; // 记录下来供回调使用
    
    // 开启文件夹选择模式
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    picker.delegate = self;
	picker.allowsMultipleSelection = NO;
    
    // 获取当前最顶层的 ViewController 来弹出
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
	#pragma clang diagnostic pop
    [rootVC presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *targetFolderURL = urls.firstObject;
	NSLog(@"[EbookJapanDumper] User selected folder: %@", targetFolderURL.path);
    
    // 1. 开启安全访问权限
    if ([targetFolderURL startAccessingSecurityScopedResource]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *dumpedFiles = [fm contentsOfDirectoryAtPath:self.currentTempDir error:nil];
        NSLog(@"[EbookJapanDumper] Found %lu dumped files in: %@", (unsigned long)dumpedFiles.count, self.currentTempDir);
        
        for (NSString *fileName in dumpedFiles) {
            NSString *srcPath = [self.currentTempDir stringByAppendingPathComponent:fileName];
            NSURL *destURL = [targetFolderURL URLByAppendingPathComponent:fileName];
            
            // 2. 执行拷贝
            NSError *error;
            if ([fm fileExistsAtPath:destURL.path]) {
                [fm removeItemAtURL:destURL error:nil]; // 如果已存在则覆盖
            }
            [fm copyItemAtPath:srcPath toPath:destURL.path error:&error];
			if (error) {
				NSLog(@"[EbookJapanDumper] Failed to copy %@ to %@. Error: %@", srcPath, destURL.path, error);
			} else {
				NSLog(@"[EbookJapanDumper] Successfully copied %@ to %@", srcPath, destURL.path);
			}
        }
        
        // 3. 停止访问
        [targetFolderURL stopAccessingSecurityScopedResource];
        
        // 4. 清理临时目录
        [fm removeItemAtPath:self.currentTempDir error:nil];
        
        // 提示成功
        NSLog(@"[EbookJapanDumper] Dump 成功，共导出 %ld 本书籍", (unsigned long)dumpedFiles.count);
    }
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