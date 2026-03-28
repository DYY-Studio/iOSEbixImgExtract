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


// 假设这是我们的数据模型
@interface ExportBookItem : NSObject
@property (nonatomic, copy) NSString *bookTitle;
@property (nonatomic, strong) id rawBookObject; // 存放 App 原生的书籍对象
@property (nonatomic, assign) BOOL isSelected;
@end

@implementation ExportBookItem
@end

@interface ExportViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSMutableArray<ExportBookItem *> *dataSource;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *exportButton;

@end

@implementation ExportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"选择导出书籍";
    
    // 1. 导航栏按钮：全选/取消全选、关闭
    UIBarButtonItem *selectAllBtn = [[UIBarButtonItem alloc] initWithTitle:@"全选" style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelectAll:)];
    self.navigationItem.leftBarButtonItem = selectAllBtn;
    
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSelf)];
    self.navigationItem.rightBarButtonItem = closeBtn;
    
    // 2. 初始化 TableView
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 100)]; // 为底部按钮留白
    [self.view addSubview:self.tableView];
    
    // 3. 悬浮在底部的导出按钮
    [self setupExportButton];
}

- (void)setupExportButton {
    CGFloat btnHeight = 50;
    CGFloat bottomPadding = 30;
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.exportButton.frame = CGRectMake(20, self.view.frame.size.height - btnHeight - bottomPadding, self.view.frame.size.width - 40, btnHeight);
    self.exportButton.backgroundColor = [UIColor systemBlueColor];
    [self.exportButton setTitle:@"开始批量导出" forState:UIControlStateNormal];
    [self.exportButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.exportButton.layer.cornerRadius = 10;
    self.exportButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.exportButton addTarget:self action:@selector(startBatchExport) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.exportButton];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"BookCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }
    
    ExportBookItem *item = self.dataSource[indexPath.row];
    cell.textLabel.text = item.bookTitle;
    cell.detailTextLabel.text = @"专有格式文件";
    
    // 根据模型状态显示打勾
    cell.accessoryType = item.isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 1. 取消反选高亮动画
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // 2. 修改数据模型
    ExportBookItem *item = self.dataSource[indexPath.row];
    item.isSelected = !item.isSelected;
    
    // 3. 局部刷新 Cell 状态
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = item.isSelected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    [self updateTitleWithCount];
}

#pragma mark - Actions

- (void)toggleSelectAll:(UIBarButtonItem *)sender {
    static BOOL isAll = NO;
    isAll = !isAll;
    
    for (ExportBookItem *item in self.dataSource) {
        item.isSelected = isAll;
    }
    
    sender.title = isAll ? @"取消全选" : @"全选";
    [self.tableView reloadData];
    [self updateTitleWithCount];
}

- (void)updateTitleWithCount {
    NSArray *selected = [self.dataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isSelected == YES"]];
    self.title = selected.count > 0 ? [NSString stringWithFormat:@"已选 %lu 本", (unsigned long)selected.count] : @"选择导出书籍";
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)startBatchExport {
    NSArray *selectedItems = [self.dataSource filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isSelected == YES"]];
    if (selectedItems.count == 0) return;
    
    // 禁用按钮防止重复点击
    self.exportButton.enabled = NO;
    self.exportButton.alpha = 0.5;
    
    // 开启后台导出逻辑
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (ExportBookItem *item in selectedItems) {
            // 这里调用你 Hook 到的导出方法
            // [YourHookHelper dumpBook:item.rawBookObject];
            [NSThread sleepForTimeInterval:0.5]; // 模拟耗时
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.exportButton.enabled = YES;
            self.exportButton.alpha = 1.0;
            // 弹出完成提示
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出完成" message:@"书籍已保存至 App 沙盒 Documents/Export 目录" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
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
    
	NSMutableArray *foundBooks = [NSMutableArray array];
	NSString *uuid = [NSString initWithData:[loadKeychainValueForKey:@"uuid" service:@"jp.co.yahoo.ebookjapan"] encoding:NSUTF8StringEncoding];
	NSString *generated_date = [NSString initWithData:[loadKeychainValueForKey:@"generated_date" service:@"jp.co.yahoo.ebookjapan"] encoding:NSUTF8StringEncoding];

	NSArray *parts = [[[EBIWrapperEnvID alloc] init] createNewBuildIdentifier:uuid uuidGenDate:generated_date];
	NSString *envId = [parts componentsJoinedByString:@""];

    for (NSURL *fileURL in enumerator) {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        
        if ([fileURL.pathExtension.lowercaseString isEqualToString:@"ebix"]) {
			EBIWrapperEbixFile *ebixFile = [[EBIWrapperEbixFile alloc] init];
			[ebixFile initInstanceWithPath:fileURL envID:envId];
			EBIWrapperEbixBookInfo *bookInfo = [ebixFile getBookInfo];
            foundBooks.addObject(bookInfo);
			[ebixFile closeInstance];
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