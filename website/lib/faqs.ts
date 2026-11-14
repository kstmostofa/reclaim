/** The short FAQ on the home page; also its structured data. */
export const faqs = [
  { q: 'Is it really free?', a: 'Yes. Reclaim is open source under the MIT License, with no paid tier, account or tracking.' },
  { q: 'Why no “Are you sure?” for every file?', a: 'Cleaning a developer Mac means deleting hundreds of items, and a confirmation per item gets clicked through without reading. Reclaim explains each item instead, ticks only Safe ones, and can never delete protected folders. Want a safety net? Turn on Move to Trash.' },
  { q: 'Why does macOS block it the first time?', a: 'It isn’t notarized by Apple, which needs a paid developer membership. Open it once through System Settings › Privacy & Security › Open Anyway.' },
  { q: 'Does it need Full Disk Access?', a: 'To see everything, yes. Without it, Reclaim skips Desktop, Documents, Downloads and other protected folders so macOS doesn’t stop the scan to ask about each one.' },
];
