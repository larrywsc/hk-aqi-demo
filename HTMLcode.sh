<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Hong Kong Air Quality Live Dashboard | HK AQI Dashboard</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script>
    tailwind.config = {
      theme: {
        extend: {
          colors: {
            aqhi: {
              low: '#22c55e',
              moderate: '#eab308',
              high: '#f97316',
              veryhigh: '#ef4444',
              serious: '#a855f7'
            }
          }
        }
      }
    }
  </script>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+TC:wght@400;500;600;700&display=swap');
    body { font-family: 'Noto Sans TC', system-ui, sans-serif; }
    .card-border-low { border-color: #22c55e; }
    .card-border-moderate { border-color: #eab308; }
    .card-border-high { border-color: #f97316; }
    .card-border-veryhigh { border-color: #ef4444; }
    .card-border-serious { border-color: #a855f7; }
    .badge-low { background-color: #22c55e; }
    .badge-moderate { background-color: #eab308; color: #1f2937; }
    .badge-high { background-color: #f97316; }
    .badge-veryhigh { background-color: #ef4444; }
    .badge-serious { background-color: #a855f7; }
    .aqhi-number { text-shadow: 0 1px 2px rgba(0,0,0,0.1); }
    .refresh-spin { animation: spin 0.8s linear infinite; }
    @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
  </style>
</head>
<body class="bg-slate-50 min-h-screen text-slate-800">
  <!-- Header -->
  <header class="bg-white border-b border-slate-200 sticky top-0 z-20 shadow-sm">
    <div class="max-w-6xl mx-auto px-4 py-4 sm:py-5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <div>
        <h1 class="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
          Hong Kong Air Quality Live Dashboard
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">
          Last updated: <span id="last-updated">—</span>
          <span id="data-source" class="ml-2 text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-600"></span>
        </p>
      </div>
      <button
        id="refresh-btn"
        class="inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-sky-600 hover:bg-sky-700 active:bg-sky-800 text-white font-medium text-sm shadow-sm transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
      >
        <svg id="refresh-icon" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
        Refresh data
      </button>
    </div>
  </header>

  <main class="max-w-6xl mx-auto px-4 py-6 sm:py-8">
    <!-- Status / Error -->
    <div id="status-msg" class="hidden mb-5 px-4 py-3 rounded-lg text-sm"></div>

    <!-- Cards Grid -->
    <div id="stations-grid" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
      <!-- Cards injected by JS -->
    </div>

    <!-- Legend -->
    <section class="mt-8 bg-white rounded-xl border border-slate-200 p-5 shadow-sm">
      <h2 class="text-sm font-semibold text-slate-700 mb-3">Health risk levels</h2>
      <div class="flex flex-wrap gap-3 text-xs sm:text-sm">
        <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-aqhi-low"></span> Low (1–3)</span>
        <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-aqhi-moderate"></span> Moderate (4–6)</span>
        <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-aqhi-high"></span> High (7)</span>
        <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-aqhi-veryhigh"></span> Very High (8–10)</span>
        <span class="inline-flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-aqhi-serious"></span> Serious (10+)</span>
      </div>
      <p class="mt-3 text-xs text-slate-500 leading-relaxed">
        Data source: Hong Kong Environmental Protection Department (EPD) Air Quality Health Index (AQHI). If the official API cannot be reached, the dashboard automatically loads simulated data for preview.
      </p>
    </section>
  </main>

  <footer class="max-w-6xl mx-auto px-4 py-6 text-center text-xs text-slate-400">
    HK AQI Dashboard · For reference only · Please refer to the <a href="https://www.aqhi.gov.hk" target="_blank" rel="noopener" class="underline hover:text-sky-600">official EPD website</a>
  </footer>

  <script>
    // ========== Config ==========
    const TARGET_STATIONS = ['中西區', '銅鑼灣', '旺角', '葵涌', '觀塘'];
    // Traditional Chinese RSS feed from EPD
    const API_URL = 'https://www.aqhi.gov.hk/epd/ddata/html/out/aqhi_ind_rss_ChT.xml';

    // Health risk mapping (AQHI scale)
    function getRiskLevel(aqhi) {
      const n = parseAqhi(aqhi);
      if (n === null) return { key: 'unknown', label: 'Unknown', advice: 'Unable to obtain a valid index.' };
      if (n >= 11) return { key: 'serious', label: 'Serious', advice: 'Everyone should avoid outdoor physical exertion and remaining outdoors, especially in areas with heavy traffic. Employers of outdoor workers should assess outdoor work risks and take appropriate precautions to protect employees’ health.' };
      if (n >= 8) return { key: 'veryhigh', label: 'Very High', advice: 'Children, the elderly, and persons with heart or respiratory illnesses should minimise outdoor physical exertion and time spent outdoors, especially in areas with heavy traffic. The general public should reduce outdoor physical exertion and time spent outdoors, especially in areas with heavy traffic.' };
      if (n === 7) return { key: 'high', label: 'High', advice: 'Children, the elderly, and persons with heart or respiratory illnesses should reduce outdoor physical exertion and time spent outdoors, especially in areas with heavy traffic.' };
      if (n >= 4) return { key: 'moderate', label: 'Moderate', advice: 'Under normal circumstances, no special measures are required. Persons with heart or respiratory illnesses who feel unwell should consider reducing outdoor physical exertion.' };
      return { key: 'low', label: 'Low', advice: 'Air quality is good and suitable for all types of outdoor activity.' };
    }

    function parseAqhi(val) {
      if (val === null || val === undefined) return null;
      const s = String(val).trim();
      if (s === '10+' || s === '10＋') return 11;
      const n = parseInt(s, 10);
      return isNaN(n) ? null : n;
    }

    function formatAqhiDisplay(aqhi) {
      const n = parseAqhi(aqhi);
      if (n === null) return '—';
      if (n >= 11) return '10+';
      return String(n);
    }

    // ========== Fallback mock data (5 core stations) ==========
    function getMockData() {
      const base = [
        { name: '中西區', aqhi: 4 },
        { name: '銅鑼灣', aqhi: 5 },
        { name: '旺角', aqhi: 6 },
        { name: '葵涌', aqhi: 4 },
        { name: '觀塘', aqhi: 5 }
      ];
      return base.map(s => ({
        name: s.name,
        aqhi: Math.min(10, Math.max(1, s.aqhi + (Math.random() > 0.7 ? (Math.random() > 0.5 ? 1 : -1) : 0))),
        type: s.name === '銅鑼灣' || s.name === '旺角' ? '路邊' : '一般',
        updated: new Date()
      }));
    }

    // ========== Parse RSS XML ==========
    function parseRssXml(xmlText) {
      const parser = new DOMParser();
      const doc = parser.parseFromString(xmlText, 'text/xml');
      const items = doc.querySelectorAll('item');
      const stations = [];
      items.forEach(item => {
        const title = item.querySelector('title')?.textContent?.trim() || '';
        const desc = item.querySelector('description')?.textContent?.trim() || '';
        const pubDate = item.querySelector('pubDate')?.textContent?.trim() || '';
        let aqhi = null;
        let type = '一般';
        const match = desc.match(/[:：]\s*(\d+|10\+|10＋)\s*/);
        if (match) aqhi = match[1];
        if (desc.includes('路邊') || 