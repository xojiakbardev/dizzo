// /robots.txt: everything public is crawlable; the admin panel, the
// customer's cabinet and the mobile app's engine are not.
export default defineEventHandler((event) => {
  setResponseHeader(event, 'content-type', 'text/plain; charset=utf-8');
  setResponseHeader(event, 'cache-control', 'public, max-age=3600');
  return [
    'User-agent: *',
    'Allow: /',
    ...['', '/ru', '/en'].flatMap(prefix => [
      `Disallow: ${prefix}/admin`,
      `Disallow: ${prefix}/user`,
      `Disallow: ${prefix}/embed`,
    ]),
    '',
    `Sitemap: ${siteOrigin(event)}/sitemap.xml`,
    '',
  ].join('\n');
});
