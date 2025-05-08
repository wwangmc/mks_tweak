#ifndef TASK_H
#define TASK_H
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>


#define TASK_PERFORM_TOUCH 10
#define TASK_PROCESS_BRING_FOREGROUND 11
#define TASK_SHOW_ALERT_BOX 12
#define TASK_RUN_SHELL 13
#define TASK_TOUCH_RECORDING_START 14
#define TASK_TOUCH_RECORDING_STOP 15
#define TASK_CRAZY_TAP 16
#define TASK_RAPID_FIRE_TAP 17
#define TASK_USLEEP 18
#define TASK_PLAY_SCRIPT 19
#define TASK_PLAY_SCRIPT_FORCE_STOP 20
#define TASK_TEMPLATE_MATCH 21
#define TASK_SHOW_TOAST 22
#define TASK_COLOR_PICKER 23
#define TASK_TEXT_INPUT 24
#define TASK_GET_DEVICE_INFO 25
#define TASK_TOUCH_INDICATOR 26
#define TASK_TEXT_RECOGNIZER 27
#define TASK_COLOR_SEARCHER 28
#define TASK_HOME 29
#define TASK_SWITCH 30
#define TASK_SCREENSHOT 31

#define TASK_UPDATE_CACHE 90

#define TASK_TEST 99
@interface HttpTask : NSObject

@property (nonatomic, strong) NSString *taskType;
@property (nonatomic, strong) NSString *content;      // 用于普通文本内容
@property (nonatomic, strong) NSDictionary *jsonContent; // 用于 JSON 格式内容

- (instancetype)initWithTaskType:(NSString *)taskType 
                         content:(NSString *)content
                     jsonContent:(NSDictionary *)jsonContent;

@end
void processTask(UInt8 *buff, CFWriteStreamRef writeStreamRef = NULL);
static int getTaskType(UInt8* dataArray);

void processHttpTask(HttpTask *task,CFWriteStreamRef writeStreamRef = NULL);

#endif