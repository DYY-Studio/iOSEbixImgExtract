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

@interface EBIWrapperEbixFileInfo : NSObject
@property (nonatomic, assign) bool spineBlockValied;
@property (nonatomic, assign) bool thumbnailBlockValid;
@property (nonatomic, assign) bool coverBlockValid;
@property (nonatomic, assign) bool linkJumpBlockValid;
@property (nonatomic, assign) bool copyrightBlockValid;
@property (nonatomic, assign) bool addendumBlockValid;
@property (nonatomic, assign) bool navigationDocumentValid;
@property (nonatomic, assign) bool bodyBlockCryptValid;
@property (nonatomic, assign) int bodyBlockOffset;
@property (nonatomic, assign) int bodyBlockSize;
@property (nonatomic, assign) int addendumImageCount;
@property (nonatomic, assign) int pageCount;
@property (nonatomic, strong) NSString *bodyFormat;
@property (nonatomic, strong) NSString *bodyFormatVersion;
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
- (EBIWrapperEbixFileInfo *)getFileInfo;
- (void)closeInstance;
- (void)enableMultiThread;
- (void)setImageDataAsJpeg:(bool)asJpeg;
@end

@interface ExportManager : 	NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) NSString *currentTempDir;
@property (nonatomic, strong) UIWindow *floatingWindow;
@property (nonatomic, assign) BOOL canceled;
+ (instancetype)shared;
+ (id)getRootViewController;
+ (id)getKeyWindow;
- (void)showExtractionAlert;
- (void)startAutomatedDump;
- (NSString *)loadKeychainValueForKey:(NSString *)key service:(NSString *)service;
- (void)presentFolderPickerWithTempDir:(NSString *)tempDir;
@end

@interface ExtractionUIHandler : NSObject
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *subProgressView;
@property (nonatomic, strong) UILabel *subStatusLabel;

+ (instancetype)sharedHandler;
- (void)showOverlayAndStartTask;
@end