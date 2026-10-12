<script setup>
import { ref, onMounted, onBeforeUnmount, defineProps } from 'vue';
import {baseUrl} from "@/apis/mksApi.js";

// WebSocket 相关状态
const ws = ref(null);
const isConnected = ref(false);
const messages = ref([]); // 用于存储接收的消息

// 连接 WebSocket 当网络卡顿时获取截图基本会一直占用网络导致点击等其它功能请求延时
const connectWebSocket = () => {
  // 替换为你的 WebSocket 服务器地址
  const currentHost = window.location.host; // 包含域名和端口（如 "example.com:8080"）
  const wsUrl = `ws://${currentHost}`;
  // const wsUrl = `ws://`;

  // 创建 WebSocket 连接
  ws.value = new WebSocket(wsUrl);

  ws.value.onopen = () => {
    isConnected.value = true;
    console.log('WebSocket 连接已建立');
  };

  ws.value.onmessage = (event) => {
    messages.value.push(event.data);
    console.log('收到消息:', event.data);
    // 这里可以添加处理接收消息的逻辑
  };

  ws.value.onerror = (error) => {
    console.error('WebSocket 错误:', error);
  };

  ws.value.onclose = () => {
    isConnected.value = false;
    console.log('WebSocket 连接已关闭');
    // 可以在这里实现自动重连逻辑
  };
};
const props = defineProps({
  initialInterval: {
    type: Number,
    default: 100
  }
});

const animationCanvas = ref(null);
const canvasContainer = ref(null);
const ctx = ref(null);

const isRunning = ref(false);
const interval = ref(props.initialInterval);
const currentImage = ref(null);
const animationInterval = ref(null);

// 初始化Canvas
const initCanvas = () => {
  if (!animationCanvas.value) return;
  ctx.value = animationCanvas.value.getContext('2d');

  // 添加事件监听
  animationCanvas.value.addEventListener('mousedown', handleDown);
  animationCanvas.value.addEventListener('mousemove', handleMove);
  animationCanvas.value.addEventListener('mouseup', handleUp);
  animationCanvas.value.addEventListener('mouseleave', handleLeave);
  // 禁止右键原来的行为 会弹出菜单
  animationCanvas.value.addEventListener('contextmenu', (e) => {
    e.preventDefault();
  });
};

let isDragging = false;
function touchCommon(originalX, originalY, type) {
  ws.value.send(JSON.stringify({
    type:"touch",
    data:{
      "x": originalX,
      "y": originalY,
      "index": 1,
      "type": type
    }
  }))
}
function home(){
  ws.value.send(JSON.stringify({
    type:"home"
  }))
}

function inputText(text){
  ws.value.send(JSON.stringify({
    type: "inputText",
    data: text
  }))
}
function moveCursor(num){
  ws.value.send(JSON.stringify({
    type: "moveCursor",
    data: num
  }))
}
function backspace(num){
  ws.value.send(JSON.stringify({
    type: "backspace",
    data: num
  }))
}
const handleDown = (event) => {
  if (event.button === 2) {
    home()
  }else if (event.button === 0) {
    isDragging = true;
    let {originalX, originalY} = currentPointOnDevice(event);
    touchCommon(originalX, originalY, "down");
  }

}


let lastMoveTime = 0; // 新增节流计时器
const MOVE_THROTTLE_MS = 50; // 推荐50-100ms的节流间隔
const handleMove = (event) => {
  const now = Date.now();
  if (isDragging && now - lastMoveTime >= MOVE_THROTTLE_MS) {
    lastMoveTime = now;
    let {originalX, originalY} = currentPointOnDevice(event);
    touchCommon(originalX, originalY, "move");
  }
}
const handleLeave = (event)=>{
  if(isDragging){
    isDragging = false;
    let {originalX, originalY} = currentPointOnDevice(event);
    touchCommon(originalX, originalY, "up");
  }
}
const handleUp = (event) => {
  if (event.button === 0){
    isDragging = false;
    let {originalX, originalY} = currentPointOnDevice(event);
    touchCommon(originalX, originalY, "up");
  }
}

// 核心修复：正确的坐标转换
function currentPointOnDevice(event) {
  if (!animationCanvas.value || !currentImage.value) {
    return { originalX: 0, originalY: 0, canvasX: 0, canvasY: 0 };
  }

  const canvas = animationCanvas.value;
  const rect = canvas.getBoundingClientRect();
  const img = currentImage.value;

  // 1. 转换为画布坐标系（考虑CSS缩放）
  const canvasX = (event.clientX - rect.left) * (canvas.width / rect.width);
  const canvasY = (event.clientY - rect.top) * (canvas.height / rect.height);

  // 2. 严格的边界检查
  const clampedX = Math.max(0, Math.min(canvasX, img.width));
  const clampedY = Math.max(0, Math.min(canvasY, img.height));

  // 3. 应用设备缩放因子
  const originalX = Math.floor(clampedX);
  const originalY = Math.floor(clampedY);

  return {
    originalX,
    originalY,
    canvasX: clampedX,
    canvasY: clampedY
  };
}
let width_cache = 0
let height_cache = 0
function resizeCanvas(container,canvas,img){
  // 同一手机的图片大小不会变 缓存一下 避免重复修改canvas的尺寸
  if(width_cache === img.width && height_cache === img.height) return;
  width_cache = img.width
  height_cache = img.height
  // 设置容器尺寸为图片原始尺寸
  container.style.width = `${img.width}`;
  container.style.height = `${img.height}`;

  // 设置画布内存尺寸为图片原始尺寸
  canvas.width = img.width;
  canvas.height = img.height;
}
// 简化后的图片绘制逻辑
const drawImage = () => {
  if ( !ctx.value || !currentImage.value ) return;
  const canvas = animationCanvas.value;
  const img = currentImage.value;
  const container = canvasContainer.value;

  resizeCanvas(container,canvas,img)

  // 清除并绘制图像
  ctx.value.clearRect(0, 0, canvas.width, canvas.height);
  ctx.value.drawImage(img, 0, 0);
};

const resetDirtyFrameCount = () => {
  fetch(`${baseUrl}/resetDirtyFrameCount`)
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.text();
    })
    .then(result => {
      console.log("resetDirtyFrameCount response:", result);
    })
    .catch(error => {
      console.error("Failed to reset dirty frame count:", error);
    });
};
// 获取最新图片
const fetchImage = () => {
  const timestamp = Date.now();
  // 后面加上时间戳防止缓存
  const url = `${baseUrl}/screenshot?quality=0.1&timestamp=${timestamp}`;

  return fetch(url)
    .then(response => {
      // 处理 204 No Content - 屏幕内容未变化
      if (response.status === 204) {
        return { changed: false, message: '屏幕内容未变化' };
      }

      // 处理其他错误状态
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      // 正常情况，处理图像数据
      return response.blob().then(blob => {
        if (blob.size === 0) {
          return { changed: false, message: '收到空图像数据' };
        }

        return createImageBitmap(blob).then(imageBitmap => {
          // 释放旧资源
          if (currentImage.value) {
            currentImage.value.close?.();
          }

          currentImage.value = imageBitmap;
          drawImage();
          return { changed: true, imageBitmap };
        });
      });
    })
    .catch(error => {
      console.error('图片加载失败:', error.message);
      return { changed: false, error: error.message };
    });
};

const startOrStopAnimation = ()=>{
  if(isRunning.value){
    isRunning.value = false
    if (animationInterval.value) {
      clearInterval(animationInterval.value);
    }
  }else{
    isRunning.value = true;
    fetchImage();
    animationInterval.value = setInterval(fetchImage, interval.value);
  }
}

// 键盘按下事件处理
let keyPressTimestamp = 0; // 记录按键时间戳
const SHORTCUT_TIMEOUT = 300; // 检测快捷键的时间窗口（毫秒）
const handleKeyDown = async (event) => {
  const now = Date.now();
  // 检测粘贴键 ctrl和v不可能在同一个事件中出现所有有如下处理
  if (event.ctrlKey || event.metaKey) {
    keyPressTimestamp = now;
  }
  if ((event.key === 'v' || event.key === 'V') && now - keyPressTimestamp < SHORTCUT_TIMEOUT) {
    // 此应用的场景是局域网非https应用 出于对最新浏览器安全策略这里是无法获取到截切板读写权限的
    // 创建临时 textarea 来处理粘贴
    const tempInput = document.createElement('textarea');
    tempInput.style.position = 'fixed';
    tempInput.style.left = '-9999px';
    tempInput.style.top = '-9999px';
    document.body.appendChild(tempInput);
    tempInput.focus();

    // 等待一帧后获取内容
    setTimeout(async () => {
      const text = tempInput.value;
      document.body.removeChild(tempInput);
      if (text) {
        inputText(text);
      }
    }, 10);

    return;
  }
  if(event.key.length === 1){
    inputText(event.key)
  }else if(event.key === 'Backspace'){
    backspace(1)
  }else if(event.key === "ArrowLeft"){
    moveCursor(-1)
  }else if(event.key === "ArrowRight"){
    moveCursor(1)
  }
};



// 生命周期钩子
onMounted(() => {
  initCanvas();
  connectWebSocket();
  resetDirtyFrameCount();
  window.addEventListener('keydown', handleKeyDown);
});
const disconnectWebSocket = () => {
  if (ws.value) {
    ws.value.close();
  }
};
onBeforeUnmount(() => {
  startOrStopAnimation();
  disconnectWebSocket();
  if (currentImage.value) {
    currentImage.value.close();
  }
  if (animationCanvas.value) {
    animationCanvas.value.removeEventListener('mousedown', handleDown);
    animationCanvas.value.removeEventListener('mousemove', handleMove);
    animationCanvas.value.removeEventListener('mouseup', handleUp);
  }
  window.removeEventListener('keydown', handleKeyDown);
});
</script>

<template>
  <div class="animation-container">
    <div ref="canvasContainer" class="canvas-container">
      <canvas ref="animationCanvas"></canvas>
    </div>

    <div class="controls">
      <button @click="startOrStopAnimation" >{{ isRunning?'停止':'开始' }}</button>
      <span>刷新间隔: {{ interval }}ms</span>
      <input
          type="range"
          v-model.number="interval"
          min="10"
          max="1000"
          step="10"
          @change="()=>{
            if(isRunning){
              // 运行中 将其停止再打开 停止的不管
              startOrStopAnimation()
              startOrStopAnimation()
            }
          }"
      >
    </div>
  </div>
</template>

<style scoped>
.animation-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 93vh;
}

.canvas-container {
  flex: 1;
  border: 1px solid #ccc;
  margin: 10px 0;
  display: flex;
  justify-content: center;
  align-items: center;
  overflow: auto;
  background-color: #f0f0f0;
  position: relative;
}

canvas {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}

.controls {
  padding: 10px;
  background: #f5f5f5;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 15px;
  flex-wrap: wrap;
}

button {
  padding: 6px 12px;
  min-width: 60px;
}

input[type="range"] {
  width: 200px;
}
</style>
