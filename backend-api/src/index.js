import express from 'express';

const app = express();
app.use(express.json());
app.get('/health', (_request, response) => response.json({ status: 'ok' }));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Backend API listening on ${port}`));