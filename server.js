const express = require('express');
const axios = require('axios');
const app = express();
const PORT = 3001;

// URL do primeiro serviço (será resolvido pelo DNS do Kubernetes)
const SERVICE1_URL = process.env.SERVICE1_URL || 'http://meu-app-service';

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Service 2!',
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname(),
    service: 'service-2'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'service-2' });
});

// Endpoint que chama o primeiro serviço
app.get('/call-service1', async (req, res) => {
  try {
    console.log(`Calling service 1 at ${SERVICE1_URL}`);
    const response = await axios.get(SERVICE1_URL, { timeout: 5000 });
    
    res.json({
      message: 'Successfully called Service 1',
      service2Info: {
        hostname: require('os').hostname(),
        timestamp: new Date().toISOString()
      },
      service1Response: response.data
    });
  } catch (error) {
    console.error('Error calling service 1:', error.message);
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
    const calls = await Promise.all([
      axios.get(SERVICE1_URL, { timeout: 5000 }),
      axios.get(`${SERVICE1_URL}/health`, { timeout: 5000 })
    ]);
    
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
    console.error('Error in chain:', error.message);
    res.status(500).json({
      message: 'Error in chain',
      error: error.message
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Service 2 running on port ${PORT}`);
  console.log(`Will communicate with Service 1 at: ${SERVICE1_URL}`);
});

