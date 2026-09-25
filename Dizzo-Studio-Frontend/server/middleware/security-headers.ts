// Security headers on everything the Worker answers (pages, server routes,
// errors); static files get theirs from public/_headers.
// /embed/** is the mobile app's engine: loaded top-level in a WebView (and
// framed by the dev harness), so it gets no frame restrictions.
const COMMON = {
  'Strict-Transport-Security': 'max-age=31536000',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), payment=(), usb=(), geolocation=(self)',
};
const NO_FRAMING = {
  'X-Frame-Options': 'SAMEORIGIN',
  'Content-Security-Policy': 'frame-ancestors \'self\'',
};

export default defineEventHandler((event) => {
  setResponseHeaders(event, COMMON);
  if (!/^\/embed(?:[/?]|$)/.test(event.path)) setResponseHeaders(event, NO_FRAMING);
});
