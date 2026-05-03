'use strict';

const { isMainThread } = require('worker_threads');

if (isMainThread) {
  const { NodeSDK } = require('@opentelemetry/sdk-node');
  const {
    getNodeAutoInstrumentations,
  } = require('@opentelemetry/auto-instrumentations-node');
  const {
    OTLPTraceExporter,
  } = require('@opentelemetry/exporter-trace-otlp-http');
  const {
    OTLPMetricExporter,
  } = require('@opentelemetry/exporter-metrics-otlp-http');
  const {
    PeriodicExportingMetricReader,
  } = require('@opentelemetry/sdk-metrics');

  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter(),
    metricReader: new PeriodicExportingMetricReader({
      exporter: new OTLPMetricExporter(),
      exportIntervalMillis: 15_000,
    }),
    instrumentations: [getNodeAutoInstrumentations()],
  });

  sdk.start();
}
