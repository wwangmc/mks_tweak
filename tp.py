import requests
import cv2
import numpy as np
import time

class HTTPMirrorClient:
    def __init__(self, server_url, target_fps=15):
        self.server_url = server_url
        self.target_fps = target_fps
        self.running = False
        self.window_name = "Screen Mirror"
        self.original_resolution = None  # 存储原始分辨率
        
    def start(self):
        """启动客户端"""
        self.running = True
        frame_interval = 1.0 / self.target_fps
        
        try:
            # 首次请求获取分辨率
            self.initialize_resolution()
            
            # 创建窗口，设置为原始分辨率
            if self.original_resolution:
                cv2.namedWindow(
                    self.window_name, 
                    cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO
                )
                cv2.resizeWindow(
                    self.window_name,
                    self.original_resolution[0],
                    self.original_resolution[1]
                )
            
            while self.running:
                start_time = time.time()
                
                try:
                    # 发送HTTP请求获取图像
                    response = requests.get(self.server_url, timeout=1.0)
                    
                    if response.status_code == 200:
                        # 获取分辨率信息
                        res_width = int(response.headers.get('X-Resolution-Width', 0))
                        res_height = int(response.headers.get('X-Resolution-Height', 0))
                        
                        # 将字节数据转换为numpy数组
                        image_array = np.frombuffer(response.content, dtype=np.uint8)
                        # 解码图像
                        image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
                        
                        if image is not None:
                            # 按原始分辨率显示
                            cv2.imshow(self.window_name, image)
                            
                            # 如果窗口大小被改变，恢复原始分辨率
                            if self.original_resolution:
                                current_size = cv2.getWindowImageRect(self.window_name)
                                if (current_size[2] != self.original_resolution[0] or 
                                    current_size[3] != self.original_resolution[1]):
                                    cv2.resizeWindow(
                                        self.window_name,
                                        self.original_resolution[0],
                                        self.original_resolution[1]
                                    )
                except requests.exceptions.RequestException as e:
                    print(f"Request failed: {e}")
                
                # 计算剩余时间并等待
                elapsed = time.time() - start_time
                sleep_time = max(0, frame_interval - elapsed)
                time.sleep(sleep_time)
                
                # 计算实际FPS
                actual_fps = 1.0 / (time.time() - start_time)
                print(f"Target FPS: {self.target_fps} | Actual FPS: {actual_fps:.1f}", end='\r')
                
                # 按q退出
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
                    
        except KeyboardInterrupt:
            pass
        finally:
            self.stop()
    
    def initialize_resolution(self):
        """初始化获取原始分辨率"""
        try:
            response = requests.get(self.server_url, timeout=1.0)
            if response.status_code == 200:
                width = 414
                height = 896
                if width > 0 and height > 0:
                    self.original_resolution = (width, height)
                    print(f"Original resolution: {width}x{height}")
        except Exception as e:
            print(f"Failed to get resolution: {e}")
    
    def stop(self):
        """停止客户端"""
        self.running = False
        cv2.destroyAllWindows()
        print("\nClient stopped")

if __name__ == "__main__":
    # 使用示例 - 替换为你的服务器地址
    SERVER_URL = "http://192.168.31.177:8081/screenshot?quality=0.3"  # 例如: "http://localhost:5000"
    # SERVER_URL = "http://192.168.31.177:58586/screenCapture"
    TARGET_FPS = 30  # 设置目标帧率
    
    client = HTTPMirrorClient(SERVER_URL, TARGET_FPS)
    client.start()