#import <Foundation/Foundation.h>

@interface Song : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong) UIImage *artwork;

- (instancetype)initWithFilePath:(NSString *)path;

@end
