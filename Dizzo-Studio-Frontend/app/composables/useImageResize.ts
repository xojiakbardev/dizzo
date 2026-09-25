import { i18nT } from '~/lib/i18n';
// Downscales+compresses an image before upload — category preview photos
// load on every product-listing page view, so keeping them small matters.
// `type` "image/webp" keeps transparency (product shots on no background);
// browsers that can't encode WebP return a PNG blob instead, and the upload
// uses the blob's real type.
export function resizeImageToBlob(file: Blob, maxDimension = 600, quality = 0.82, type = 'image/jpeg'): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file);
    const img = new Image();
    img.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error(i18nT('common.errors.imageOpen')));
    };
    img.onload = () => {
      URL.revokeObjectURL(objectUrl);
      const scale = Math.min(1, maxDimension / Math.max(img.width, img.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.round(img.width * scale);
      canvas.height = Math.round(img.height * scale);
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        reject(new Error(i18nT('common.errors.canvasUnavailable')));
        return;
      }
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      canvas.toBlob(
        blob => (blob ? resolve(blob) : reject(new Error(i18nT('common.errors.imageCompress')))),
        type,
        quality,
      );
    };
    img.src = objectUrl;
  });
}
