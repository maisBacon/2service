'use strict';
module.exports = {
  app_name: [process.env.NEW_RELIC_APP_NAME || 'service-2'],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  logging: {
    level: process.env.NEW_RELIC_LOG_LEVEL || 'info'
  },
  distributed_tracing: {
    enabled: process.env.NEW_RELIC_DISTRIBUTED_TRACING_ENABLED === 'true' || true
  }
};

