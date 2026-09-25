// Where an order is collected or delivered: the chosen branch for pickup,
// the customer's pin for courier. Used on both the admin and cabinet pages.
import type { OrderDetail } from '~/types/commerce';
import { pickupPoint } from '~/utils/pickup';

export function orderMapHref(lat: number, lon: number, zoom = 16) {
  return `https://yandex.uz/maps/?pt=${lon},${lat}&z=${zoom}&l=map`;
}

export function orderCoords(order: Pick<OrderDetail, 'latitude' | 'longitude' | 'branch'> | null | undefined) {
  const lat = Number(order?.latitude ?? order?.branch?.latitude);
  const lon = Number(order?.longitude ?? order?.branch?.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  return { lat, lon };
}

export function orderPickupPlace(order: OrderDetail | null | undefined) {
  const branch = order?.branch;
  if (branch) {
    return {
      name: branch.name,
      address: [branch.address, branch.city].filter(Boolean).join(', '),
      hours: branch.work_hours || '',
    };
  }
  if (order?.branch_name) {
    return {
      name: order.branch_name,
      address: [order.shipping_address, order.shipping_city].filter(Boolean).join(', '),
      hours: '',
    };
  }
  const hq = pickupPoint();
  return { name: hq.name, address: hq.address, hours: hq.hours };
}

export function orderCustomerAddress(order: OrderDetail | null | undefined) {
  if (!order) return '';
  return [order.shipping_address, order.shipping_city, order.shipping_state, order.shipping_postal_code]
    .filter(Boolean)
    .join(', ');
}
