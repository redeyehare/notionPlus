const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

// 更宽松的 CORS 配置
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Notion-Version', 'Accept'],
  credentials: true,
  preflightContinue: false,
  optionsSuccessStatus: 204
}));

// 处理预检请求
app.options('*', cors());

// 代理所有 /notion 请求到 Notion API
app.use('/notion', createProxyMiddleware({
  target: 'https://api.notion.com',
  changeOrigin: true,
  pathRewrite: {
    '^/notion': '/v1',
  },
  onProxyReq: (proxyReq, req, res) => {
    console.log('Proxying:', req.method, req.url);
    console.log('Headers:', JSON.stringify(req.headers, null, 2));
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log('Response:', proxyRes.statusCode);
    // 添加 CORS 头到响应
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
    proxyRes.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, PATCH, OPTIONS';
    proxyRes.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, Notion-Version, Accept';
  },
  onError: (err, req, res) => {
    console.error('Proxy Error:', err);
    res.status(500).json({ error: 'Proxy error', message: err.message });
  },
}));

// 健康检查端点
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// 测试 Notion 连接
app.get('/test-notion', async (req, res) => {
  try {
    const response = await fetch('https://api.notion.com/v1/users/me', {
      headers: {
        'Authorization': req.headers.authorization || '',
        'Notion-Version': '2022-06-28',
      }
    });
    const data = await response.json();
    res.json({ 
      status: response.status, 
      notionResponse: data,
      message: response.ok ? 'Connection successful' : 'Connection failed' 
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = 3001;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ 代理服务器运行在 http://localhost:${PORT}`);
  console.log(`✅ 健康检查: http://localhost:${PORT}/health`);
  console.log(`✅ Notion API 代理: http://localhost:${PORT}/notion/...`);
  console.log('');
  console.log('📋 使用步骤：');
  console.log('   1. 启动 Flutter Web: flutter run -d chrome --web-browser-flag "--disable-web-security"');
  console.log('   2. 或在生产环境部署到同源域名');
  console.log('');
});
