// web/src/pages/api/getAgencyTransactions.js
import fetch from 'node-fetch';

export default async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).end();

  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Unauthorized' });

  const FUNCTION_URL = process.env.GET_AGENCY_TRANSACTIONS_URL;
  if (!FUNCTION_URL) return res.status(500).json({ error: 'Server misconfiguration: missing function URL' });

  const url = new URL(FUNCTION_URL);
  url.search = new URLSearchParams(req.query).toString();

  try {
    const r = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        Authorization: authHeader,
      },
    });
    const text = await r.text();
    res.status(r.status).send(text);
  } catch (err) {
    console.error('proxy error', err);
    res.status(500).json({ error: 'Proxy error' });
  }
}
