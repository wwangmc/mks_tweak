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

    // 创建不使用代理的Session配置
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.connectionProxyDictionary = @{}; // 关键设置：禁用代理
    config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData; // 忽略缓存
    
    // 创建自定义Session
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:10];
    [request setValue:@"no-proxy" forHTTPHeaderField:@"Proxy-Connection"]; // 额外声明不要代理
    
    // 发起请求
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // 处理响应
        id responseData = nil;
        
        if (error) {
            NSLog(@"Request failed: %@ | URL: %@", error.localizedDescription, urlString);
            if (completion) completion(nil, error);
            return;
        }
        
        if (!data || data.length == 0) {
            NSError *emptyError = [NSError errorWithDomain:@"NetworkError" 
                                                     code:-2 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Empty response data"}];
            if (completion) completion(nil, emptyError);
            return;
        }
        
        // 自动识别JSON/文本
        NSError *jsonError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        
        if (!jsonError) {
            responseData = jsonObject;
        } else {
            responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!responseData) responseData = data; // 保留原始数据
        }
        
        if (completion) completion(responseData, nil);
    }];

    [task resume];
    
    // 注意：不要忘记在适当的时候调用 [session finishTasksAndInvalidate]
    [session finishTasksAndInvalidate];
}