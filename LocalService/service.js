const express = require('express');
const os = require('os');
const app = express();

app.set('etag', false);

app.use((req, res, next) => {
    const currentTime = new Date();
    const formattedTime = currentTime.toLocaleString('zh-CN', { hour12: false });
    res.setHeader('X-Response-Time', formattedTime);
    next();
});

app.get('/cache', (req, res) => {
    const cacheControl = req.query['Cache-Control'];

    // 设置 Cache-Control 响应头
    res.setHeader('Cache-Control', cacheControl || 'no-cache');

    // 返回不同的 JSON 数据
    switch (cacheControl) {
        case 'public':
            setTimeout(() => {
                res.json({ message: 'Public cache', cacheControl });
            }, 1200);
            break;
        case 'private':
            setTimeout(() => {
                res.json({ message: 'Private cache', cacheControl });
            }, 1500);
            break;
        case 'max-age=3600':
            setTimeout(() => {
                res.json({ message: 'Cache for 3600 seconds', cacheControl });
            }, 2000);
            break;
        case 'max-age=0':
            setTimeout(() => {
                res.json({ message: 'No cache', cacheControl });
            }, 3000);
            break;
        case 'no-cache':
            setTimeout(() => {
                res.json({ message: 'No cache directive', cacheControl });
            }, 1600);
            break;
        case 'no-store':
            setTimeout(() => {
                res.json({ message: 'No store directive', cacheControl });
            }, 2400);
            break;
        default:
            res.json({ message: 'Default no-cache', cacheControl: 'no-cache' });
    }
});

const port = 3000;
app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});

// 获取本机 IP 地址的函数
function getLocalIpAddress() {
    const interfaces = os.networkInterfaces();
    for (const devName in interfaces) {
        const iface = interfaces[devName];
        for (let i = 0; i < iface.length; i++) {
            const alias = iface[i];
            if (alias.family === 'IPv4' && alias.address !== '127.0.0.1' && !alias.internal) {
                return alias.address;
            }
        }
    }
    return 'localhost';
}

const localIpAddress = getLocalIpAddress();
console.log('Server IP Address:', localIpAddress);