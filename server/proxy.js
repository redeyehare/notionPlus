const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

app.use(cors());

// 代理所有 /notion 请求到 Notion API
app.use('/notion', createProxyMiddleware({
  target: 'https://api.notion.com',
  changeOrigin: true,
  pathRewrite: {
    '^/notion': '/v1', // 重写路径
  },
  onProxyReq: (proxyReq, req, res) => {
    // 保留原始请求头
    console.log('Proxying:', req.method, req.url);
  },
}));

const PORT = 3001;
app.listen(PORT, () => {
  console.log(`代理服务器运行在 http://localhost:${PORT}`);
  console.log('使用方式: 将 Notion API 调用改为 http://localhost:3001/notion/...');
});
