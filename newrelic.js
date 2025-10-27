'use strict';

const { application } = require("express");

module.exports = {
  app_name: [process.env.NEW_RELIC_APP_NAME],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  logging: {
    level: process.env.NEW_RELIC_LOG_LEVEL || 'info'
  },
  distributed_tracing: {
    enabled: process.env.NEW_RELIC_DISTRIBUTED_TRACING_ENABLED === 'true'
  },
  application_logging: {
    enabled: true,
    forwarding: {
      enabled: true
    }
  }
};