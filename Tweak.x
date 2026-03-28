#import <UIKit/UIKit.h>
#import <Security/Security.h>
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
- (instancetype)openInstanceWithPath:(NSURL *)path envID:(NSString *)envID;
- (NSDictionary *)imageDataDictAtIndex:(int)index;
- (NSData *)imageDataAtIndex:(int)index;
- (int)getImageCount;
- (int)getMaxPage;
- (EBIWrapperEbixBookInfo *)getBookInfo;
- (void)closeInstance;
@end

@interface ExportFloatingBall : UIButton
@property (nonatomic, copy) void (^onTapBlock)(void);
@end

@implementation ExportFloatingBall {
    CGPoint _startPoint;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor systemBlueColor];
        self.layer.cornerRadius = frame.size.width / 2;
        [self setTitle:@"导出" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:12];
        
        // 添加拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        [self addTarget:self action:@selector(clicked) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint point = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + point.x, self.center.y + point.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (void)clicked {
    if (self.onTapBlock) self.onTapBlock();
}
@end

static UIWindow *floatingWindow;
static ExportFloatingBall *ball;
typedef void (*MSHookMessageEx_t)(Class _class, SEL message, IMP hook, IMP *old);
static MSHookMessageEx_t MSHookMessageEx_p = NULL;

typedef void (*UIWindow_makeKeyAndVisible_t)(id self, SEL _cmd);
static UIWindow_makeKeyAndVisible_t UIWindow_makeKeyAndVisible_p = NULL;

- (NSString *)loadKeychainValueForKey:(NSString *)key service:(NSString *)service {
    // 1. 创建查询字典
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword; // 指定数据类型
    query[(__bridge id)kSecAttrService] = service;                        // 服务的名字
    query[(__bridge id)kSecAttrAccount] = key;                            // 具体的键（Account）
    query[(__bridge id)kSecReturnData] = (__bridge id)kValueTrue;         // 要求返回原始数据
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
            NSLog(@"Keychain 中未找到对应的键");
        } else {
            NSLog(@"Keychain 读取错误，错误码: %d", (int)status);
        }
        return nil;
    }
}

- (NSMutableArray *)bookFinder:(NSURL *)folderURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:folderURL
                                          includingPropertiesForKeys:@[NSURLNameKey, IsRegularFileKey]
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        errorHandler:nil];
    
	NSMutableArray<NSURL *> *foundBooks = [NSMutableArray array];
	NSString *uuid = [NSString initWithData:[loadKeychainValueForKey:@"uuid" service:@"jp.co.yahoo.ebookjapan"] encoding:NSUTF8StringEncoding];
	NSString *generated_date = [NSString initWithData:[loadKeychainValueForKey:@"generated_date" service:@"jp.co.yahoo.ebookjapan"] encoding:NSUTF8StringEncoding];

	NSArray *parts = [[[EBIWrapperEnvID alloc] init] createNewBuildIdentifier:uuid uuidGenDate:generated_date];
	NSString *envId = [parts componentsJoinedByString:@""];

    for (NSURL *fileURL in enumerator) {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        
        if ([fileURL.pathExtension.lowercaseString isEqualToString:@"ebix"]) {
			EBIWrapperEbixFile *ebixFile = [[EBIWrapperEbixFile alloc] init];
			if ([ebixFile initInstanceWithPath:fileURL envID:envId]) {
				EBIWrapperEbixBookInfo *bookInfo = [ebixFile getBookInfo];
				foundBooks.addObject(fileURL);
				[ebixFile closeInstance];
			}
        }
    }
	return foundBooks;
}

- (void)makeKeyAndVisible {
	UIWindow_makeKeyAndVisible_p(self, _cmd);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 创建悬浮窗口
        floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
        floatingWindow.windowLevel = UIWindowLevelAlert + 1;
        floatingWindow.backgroundColor = [UIColor clearColor];
        
        ball = [[ExportFloatingBall alloc] initWithFrame:floatingWindow.bounds];
        ball.onTapBlock = ^{
            // 点击悬浮球，弹出列表
            ExportViewController *vc = [[ExportViewController alloc] init];
            // 这里需要从 App 原生单例获取书籍列表并填充 dataSource
            // vc.dataSource = [self fetchBooksFromApp]; 
            
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:nav animated:YES completion:nil];
        };
        
        [floatingWindow addSubview:ball];
        [floatingWindow makeKeyAndVisible];
    });
}


__attribute__((constructor))
static void tweakConstructor() {
    MSHookMessageEx_p = (MSHookMessageEx_t)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    if (!MSHookMessageEx_p) {
        return;
    }

	MSHookMessageEx_p(UIWindow.class, @selector(makeKeyAndVisible), (IMP)makeKeyAndVisible, (IMP *)&UIWindow_makeKeyAndVisible_p);
}