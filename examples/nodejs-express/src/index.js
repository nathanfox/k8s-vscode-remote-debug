const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

app.get('/debug-test', async (req, res) => {
  const count = parseInt(req.query.count) || 3;
  const items = [];

  for (let i = 0; i < count; i++) {
    const item = `Item ${i + 1}`;
    items.push(item);

    await new Promise(resolve => setTimeout(resolve, 10));
  }

  res.json({
    count: count,
    items: items,
    timestamp: new Date().toISOString()
  });
});

app.get('/weatherforecast', (req, res) => {
  const summaries = [
    'Freezing', 'Bracing', 'Chilly', 'Cool', 'Mild',
    'Warm', 'Balmy', 'Hot', 'Sweltering', 'Scorching'
  ];

  const forecasts = [];
  for (let i = 1; i <= 5; i++) {
    const date = new Date();
    date.setDate(date.getDate() + i);

    const tempC = Math.floor(Math.random() * 75) - 20;
    const tempF = Math.floor(32 + (tempC / 0.5556));

    forecasts.push({
      date: date.toISOString().split('T')[0],
      temperatureC: tempC,
      temperatureF: tempF,
      summary: summaries[Math.floor(Math.random() * summaries.length)]
    });
  }

  res.json(forecasts);
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server listening on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});