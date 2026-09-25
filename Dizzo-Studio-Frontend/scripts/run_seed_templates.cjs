const { CATALOG, getPalettes, generateConcepts } = require('./seed_templates.cjs');

const API_BASE = 'https://api.dizzo.uz/api';

async function main() {
  console.log('=== DIZZO TEMPLATE LIBRARY SEEDER STARTING ===');

  // 1. Admin login
  console.log('Logging in as admin@gmail.com...');
  const loginRes = await fetch(`${API_BASE}/auth/login/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@gmail.com', password: 'qwerty' })
  });

  if (!loginRes.ok) {
    throw new Error(`Login failed with status ${loginRes.status}: ${await loginRes.text()}`);
  }

  const { access_token } = await loginRes.json();
  console.log('Admin authenticated successfully.');

  // 2. Prepare reusable preview WebP
  console.log('Preparing preview image in R2...');
  const base64Webp = 'UklGRkAAAABXRUJQVlA4IDQAAADwAQCdASoBAAEAAQAcJaACdLoB+AA/v396t//45b//45b//45b//45b//45b//45b//45b//4AAA==';
  const buffer = Buffer.from(base64Webp, 'base64');

  const ticketRes = await fetch(`${API_BASE}/media/uploads/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${access_token}`
    },
    body: JSON.stringify({
      purpose: 'design',
      content_type: 'image/webp',
      size_bytes: buffer.length,
      filename: 'template_preview.webp'
    })
  });

  const ticket = await ticketRes.json();
  await fetch(ticket.upload_url, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/webp' },
    body: buffer
  });

  await fetch(`${API_BASE}/media/${ticket.id}/complete/`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${access_token}` }
  });

  const previewMediaId = ticket.id;
  console.log('Preview media ready:', previewMediaId);

  let totalSaved = 0;
  let totalErrors = 0;

  // 3. Iterate through all products, variants, and colors
  for (const prod of CATALOG) {
    console.log(`\n========================================`);
    console.log(`Processing Product: ${prod.name} (id: ${prod.product_id}, slug: ${prod.slug})`);
    console.log(`========================================`);

    for (const v of prod.variants) {
      for (const c of v.colors) {
        console.log(`\n  -> Variant: [${v.name}] (id: ${v.id}) | Color: [${c.name}] (id: ${c.id}, hex: ${c.hex})`);

        const palette = getPalettes(c.hex);
        const concepts = generateConcepts(prod.slug, prod.w_mm, prod.h_mm, prod.area, palette);

        for (const concept of concepts) {
          const payload = {
            name: concept.name,
            category: concept.category,
            variant_ids: [v.id],
            color_id: c.id,
            in_gallery: true,
            preview_media_id: previewMediaId,
            images: [],
            translations: {
              ru: { name: concept.ruName },
              en: { name: concept.enName }
            },
            document: {
              version: 1,
              layers: concept.layers,
              links: [],
              strips: []
            }
          };

          try {
            const res = await fetch(`${API_BASE}/admin/catalog/products/${prod.product_id}/templates/`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${access_token}`
              },
              body: JSON.stringify(payload)
            });

            if (res.ok) {
              const created = await res.json();
              totalSaved++;
              process.stdout.write(`    ✓ Created #${created.id}: ${concept.name}\n`);
            } else {
              totalErrors++;
              const err = await res.text();
              console.error(`    ✗ Error creating ${concept.name}:`, res.status, err);
            }
          } catch (e) {
            totalErrors++;
            console.error(`    ✗ Request failed:`, e.message);
          }
        }
      }
    }
  }

  console.log(`\n========================================`);
  console.log(`SEEDING COMPLETED!`);
  console.log(`Total Templates Created: ${totalSaved}`);
  console.log(`Total Errors: ${totalErrors}`);
  console.log(`========================================\n`);
}

main().catch(err => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
