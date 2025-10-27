require('newrelic');
const express = require('express');
const axios = require('axios');
const winston = require('winston');
const newrelicFormatter = require('@newrelic/winston-enricher')(winston);

const app = express();
const PORT = 3001;

// Configurar Winston com New Relic integration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    newrelicFormatter(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

// URL do primeiro serviço (será resolvido pelo DNS do Kubernetes)
const SERVICE1_URL = process.env.SERVICE1_URL || 'http://meu-app-service';

// Middleware para logging de todas as requisições
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      service: 'service-2',
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: duration,
      durationMs: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('user-agent')
    });
  });
  
  next();
});

app.get('/', (req, res) => {
  logger.info('Root endpoint accessed', {
    service: 'service-2',
    hostname: require('os').hostname()
  });

  res.json({
    message: 'Hello from Service 2!',
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname(),
    service: 'service-2'
  });
});

app.get('/health', (req, res) => {
  logger.debug('Health check received', {
    service: 'service-2',
    status: 'healthy'
  });

  res.status(200).json({ status: 'healthy', service: 'service-2' });
});

// Endpoint que chama o primeiro serviço
app.get('/call-service1', async (req, res) => {
  try {
    logger.info('Calling service 1', {
      service: 'service-2',
      targetService: 'service-1',
      targetUrl: SERVICE1_URL
    });

    const response = await axios.get(SERVICE1_URL, { timeout: 5000 });
    
    logger.info('Service 1 call successful', {
      service: 'service-2',
      targetService: 'service-1',
      statusCode: response.status
    });

    res.json({
      message: 'Successfully called Service 1',
      service2Info: {
        hostname: require('os').hostname(),
        timestamp: new Date().toISOString()
      },
      service1Response: response.data
    });
  } catch (error) {
    logger.error('Error calling service 1', {
      service: 'service-2',
      targetService: 'service-1',
      error: error.message,
      errorCode: error.code,
      targetUrl: SERVICE1_URL
    });

    res.status(500).json({
      message: 'Error calling Service 1',
      error: error.message,
      service2Info: {
        hostname: require('os').hostname(),
        timestamp: new Date().toISOString()
      }
    });
  }
});

// Endpoint que faz múltiplas chamadas para demonstrar comunicação
app.get('/chain', async (req, res) => {
  try {
    logger.info('Starting chain of calls', {
      service: 'service-2',
      targetService: 'service-1',
      endpoints: ['/', '/health']
    });

    const calls = await Promise.all([
      axios.get(SERVICE1_URL, { timeout: 5000 }),
      axios.get(`${SERVICE1_URL}/health`, { timeout: 5000 })
    ]);
    
    logger.info('Chain of calls completed successfully', {
      service: 'service-2',
      targetService: 'service-1',
      callsCount: calls.length
    });

    res.json({
      message: 'Chain of calls completed',
      service2: {
        hostname: require('os').hostname(),
        timestamp: new Date().toISOString()
      },
      service1Root: calls[0].data,
      service1Health: calls[1].data
    });
  } catch (error) {
    logger.error('Error in chain', {
      service: 'service-2',
      targetService: 'service-1',
      error: error.message,
      errorCode: error.code
    });

    res.status(500).json({
      message: 'Error in chain',
      error: error.message
    });
  }
});

// Novo endpoint para testar logs de diferentes níveis
app.get('/test-logs', (req, res) => {
  logger.info('Test logs endpoint called - INFO level', {
    service: 'service-2'
  });
  
  logger.warn('This is a warning log for testing', {
    service: 'service-2',
    severity: 'warning',
    testData: { foo: 'bar' }
  });

  logger.error('This is an error log for testing (not a real error)', {
    service: 'service-2',
    severity: 'error',
    testData: { error: 'simulated' }
  });

  res.json({
    message: 'Logs sent to New Relic!',
    service: 'service-2',
    logsGenerated: ['info', 'warning', 'error'],
    tip: 'Check New Relic Logs UI'
  });
});

// Endpoint para simular erro
app.get('/error', (req, res) => {
  logger.error('Intentional error triggered', {
    service: 'service-2',
    path: req.path,
    errorType: 'simulated'
  });

  res.status(500).json({
    error: 'Internal Server Error',
    message: 'This is a simulated error',
    service: 'service-2'
  });
});

// Handler de erros global
app.use((err, req, res, next) => {
  logger.error('Unhandled error', {
    service: 'service-2',
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method
  });

  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
    service: 'service-2'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  logger.info('Service 2 started', {
    service: 'service-2',
    port: PORT,
    nodeVersion: process.version,
    platform: process.platform,
    service1Url: SERVICE1_URL,
    env: process.env.NODE_ENV || 'development'
  });
});

