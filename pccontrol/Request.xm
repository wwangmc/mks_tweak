#import "Request.h"


void sendGETRequest(NSString *urlString, RequestCompletionHandler completion) {
    // 检查 URL 是否有效
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"NetworkError" 
                                            code:-1 
                                        userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
        if (completion) completion(nil, error);
        return;
    }

    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:10]; // 设置超时时间为 10 秒

    // 发起请求
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Request failed: %@ | URL: %@", error.localizedDescription, urlString);
            if (completion) completion(nil, error);
            return;
        }

        // 检查数据有效性
        if (!data || data.length == 0) {
            NSError *emptyError = [NSError errorWithDomain:@"NetworkError" 
                                                     code:-2 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Empty response data"}];
            if (completion) completion(nil, emptyError);
            return;
        }

        // 尝试解析JSON
        NSError *jsonError = nil;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        
        if (jsonError) {
            // 如果不是JSON格式，返回原始字符串
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (completion) completion(responseString, nil);
        } else {
            // 成功解析JSON
            if (completion) completion(jsonObject, nil);
        }
    }];

    [task resume];
}