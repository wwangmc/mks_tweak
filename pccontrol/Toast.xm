#import "Toast.h"
#import "Screen.h"
#import <mach/mach.h>

#define TOAST_HIDE 0
#define TOAST_ERROR 1
#define TOAST_WARNING 2
#define TOAST_MESSAGE 3
#define TOAST_SUCCESS 4

#define TOAST_TOP 0
#define TOAST_BOTTOM 1
#define TOAST_LEFT 2
#define TOAST_RIGHT 3

static int windowWidth = 200;
static int windowHeight = 200;
static NSDictionary* backgroundColorDict = @{@"4":[UIColor colorWithRed:0.282f green:0.78f blue:0.45f alpha:1.0f], @"1":[UIColor colorWithRed:0.945f green:0.275f blue:0.408f alpha:1.0f],@"2":[UIColor colorWithRed:1.0f green:0.867f blue:0.341f alpha:1.0f],@"3":[UIColor whiteColor]};
static NSDictionary* fontColorDict = @{@"4":[UIColor whiteColor], @"1":[UIColor whiteColor],@"2":[UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.7f],@"3":[UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.7f]};
static UIWindow *_window;
void showToastFromRawData(UInt8 *eventData, NSError **error)
{
    @autoreleasepool {
        // 使用 UTF-8 编码将 `eventData` 转换为 NSString
        NSString *rawData = [[NSString alloc] initWithBytes:eventData 
                                                     length:strlen((char *)eventData) 
                                                   encoding:NSUTF8StringEncoding];
        if (!rawData) {
            *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                         code:999
                                     userInfo:@{NSLocalizedDescriptionKey: @"-1;;Failed to decode data as UTF-8.\r\n"}];
            return;
        }

        // 按照 ";;" 分割字符串
        NSArray *data = [rawData componentsSeparatedByString:@";;"];
        if ([data count] < 3) {
            *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                         code:999
                                     userInfo:@{NSLocalizedDescriptionKey: @"-1;;The data format should be \"type;;content;;duration(in seconds)[];;position(0: top, 1: bottom, 2: left, 3: right)]\". For example, 0;;success;;1.5;;0.\r\n"}];
            return;
        }

        int type = [data[0] intValue];
        int duration = [data[2] intValue];
        int position = 0;
        int fontSize = 0;
        if ([data count] >= 4) {
            position = [data[3] intValue];
        }
        if ([data count] >= 5) {
            fontSize = [data[4] intValue];
        }

        if (type > 4 || type < 0) {
            *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                         code:999
                                     userInfo:@{NSLocalizedDescriptionKey: @"-1;;Unknown type. The type ranges from 0-3. Please refer to the documentation on Github.\r\n"}];
            return;
        }
        if (duration <= 0 && type != 0) {
            *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                         code:999
                                     userInfo:@{NSLocalizedDescriptionKey: @"-1;;Duration should be a positive float number.\r\n"}];
            return;
        }

        // 异步处理显示 Toast
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (type == 0) {
                [Toast hideToast];
            } else {
                [Toast showToastWithContent:data[1] 
                                       type:type 
                                   duration:duration 
                                   position:position 
                                   fontSize:fontSize];
            }
        });
    }
}
/**
 * @brief Parses a JSON string to extract Toast parameters and displays the Toast.
 * @param jsonString An NSString containing the JSON data.
 * @param error Pointer to an NSError pointer to capture any errors.
 */
void showToastFromJson(NSDictionary *jsonDict, NSError **error) {
    @autoreleasepool {;
        if (!jsonDict) {
            NSLog(@"JSON Parsing Error: %@", *error);
            return;
        }

        // Extract required fields
        NSString *typeString = jsonDict[@"type"];
        NSString *content = jsonDict[@"content"];
        NSNumber *duration = jsonDict[@"duration"];
        NSString *positionString = jsonDict[@"position"];
        NSNumber *fontSize = jsonDict[@"fontSize"]; // Optional

        if (!typeString || !content || !duration) {
            *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                         code:999
                                     userInfo:@{NSLocalizedDescriptionKey: @"JSON missing required fields: type, content, or duration.\r\n"}];
            return;
        }

        // Map string type to integer value using constants
        int type = TOAST_HIDE; // Default to hide
        if ([typeString isEqualToString:@"error"]) {
            type = TOAST_ERROR;
        } else if ([typeString isEqualToString:@"warning"]) {
            type = TOAST_WARNING;
        } else if ([typeString isEqualToString:@"message"]) {
            type = TOAST_MESSAGE;
        } else if ([typeString isEqualToString:@"success"]) {
            type = TOAST_SUCCESS;
        }

        // Validate type
        if (type < TOAST_HIDE || type > TOAST_SUCCESS) {
            *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                         code:999
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid type. Type must be 'error', 'warning', 'message', or 'success'.\r\n"}];
            return;
        }

        // Validate duration
        if ([duration floatValue] <= 0 && type != TOAST_HIDE) {
            *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                         code:999
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid duration. Duration must be positive.\r\n"}];
            return;
        }

        // Map position string to integer values
        int toastPosition = TOAST_TOP; // Default to top if no position is provided
        if (positionString) {
            if ([positionString isEqualToString:@"top"]) {
                toastPosition = TOAST_TOP;
            } else if ([positionString isEqualToString:@"bottom"]) {
                toastPosition = TOAST_BOTTOM;
            } else if ([positionString isEqualToString:@"left"]) {
                toastPosition = TOAST_LEFT;
            } else if ([positionString isEqualToString:@"right"]) {
                toastPosition = TOAST_RIGHT;
            } else {
                *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp"
                                             code:999
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid position. Position must be 'top', 'bottom', 'left', or 'right'.\r\n"}];
                return;
            }
        }

        int toastFontSize = fontSize ? [fontSize intValue] : 14; // Default font size

        // Asynchronously display Toast
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (type == TOAST_HIDE) {
                [Toast hideToast];
            } else {
                [Toast showToastWithContent:content
                                       type:type
                                   duration:[duration floatValue]
                                   position:toastPosition
                                   fontSize:toastFontSize];
            }
        });
    }
}


@implementation Toast
{
    int duration;
    UIColor *backgroundColor;
    int type; // 0 hide 1 error 2 warning 3 message 4 success
}

+ (void) hideToast
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_window != NULL)
        {
            _window.hidden = YES;
            _window = nil;
        }
    });
}

+ (void) showToastWithContent:(NSString*)content type:(int)type duration:(float)duration position:(int)position fontSize:(int)afontSize
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // 1. 清理旧窗口
        if (_window) {
            _window.hidden = YES;
            _window = nil;
        }
        
        // 2. 获取屏幕尺寸
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat screenWidth = screenBounds.size.width;
        CGFloat screenHeight = screenBounds.size.height;
        
        // 3. 计算字体大小
        int fontSize = afontSize ?: MAX(15, MIN((int)(0.015 * screenWidth), 30));
        
        // 4. 获取活跃窗口场景（iOS 16+关键修改）
        UIWindowScene *activeScene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    activeScene = (UIWindowScene *)scene;
                    break;
                }
            }
        }
        
        // 5. 计算文本尺寸（使用现代API）
        UIFont *font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightLight];
        CGSize contentSize = [content sizeWithAttributes:@{NSFontAttributeName: font}];
        
        // 6. 计算窗口尺寸和位置
        windowWidth = contentSize.width + 40;
        windowHeight = contentSize.height + 20;
        
        CGFloat windowX = (screenWidth - windowWidth) / 2;
        CGFloat windowY = (position == 1) ? (screenHeight - windowHeight - 50) : 30;
        
        // 7. 调整安全区域（关键修改）
        UIEdgeInsets safeArea = UIEdgeInsetsZero;
        if (@available(iOS 11.0, *)) {
            safeArea = activeScene ? activeScene.keyWindow.safeAreaInsets : [UIApplication sharedApplication].windows.firstObject.safeAreaInsets;
            windowY = (position == 1) ? (windowY - safeArea.bottom) : (windowY + safeArea.top);
        }
        
        // 8. 创建窗口（iOS 16+需要关联场景）
        _window = activeScene ? [[UIWindow alloc] initWithWindowScene:activeScene] : [[UIWindow alloc] initWithFrame:screenBounds];
        _window.frame = CGRectMake(windowX, windowY, windowWidth, windowHeight);
        _window.windowLevel = UIWindowLevelStatusBar + 1;
        _window.backgroundColor = backgroundColorDict[[@(type) stringValue]];
        _window.layer.cornerRadius = 10;
        _window.hidden = NO;
        
        // 9. 添加文本标签
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, windowWidth, windowHeight)];
        label.text = content;
        label.font = font;
        label.textColor = fontColorDict[[@(type) stringValue]];
        label.textAlignment = NSTextAlignmentCenter;
        [_window addSubview:label];
        
        // 10. 自动隐藏
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (_window) {
                _window.hidden = YES;
                _window = nil;
            }
        });
    });
}

- (void) show {

    
}

- (void) setContent:(NSString*)content {
    self.content = content;
}

- (void) setBackgroundColor:(UIColor*)color{

}

- (void) setDuration:(int)d {
    duration = d;
}






@end