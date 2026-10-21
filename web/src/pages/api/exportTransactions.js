// web/src/pages/api/exportTransactions.js
import fetch from 'node-fetch';

export default async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).end();

  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) return res.status(401).json({ error: 'Unauthorized' });

  const FUNCTION_URL = process.env.EXPORT_TRANSACTIONS_URL;
  if (!FUNCTION_URL) return res.status(500).json({ error: 'Server misconfiguration: missing function URL' });

  const url = new URL(FUNCTION_URL);
  url.search = new URLSearchParams(req.query).toString();

  try {
    const r = await fetch(url.toString(), {
      method: 'GET',
      headers: { Authorization: authHeader },
    });

    if (!r.ok) {
      const text = await r.text();
      return res.status(r.status).send(text);
    }

    // نتوقع ملف CSV من الدالة أو رابط؛ إذا أعادت الدالة ملفًا، نمرره مباشرة
    const contentType = r.headers.get('content-type') || '';
    res.setHeader('Content-Type', contentType);
    const buffer = await r.arrayBuffer();
    res.status(200).send(Buffer.from(buffer));
  } catch (err) {
    console.error('export proxy error', err);
    res.status(500).json({ error: 'Proxy error' });
  }
}
