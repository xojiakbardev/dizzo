// Shared commerce types — mirrors the shape of the backend API responses.
// Ported from the old Next.js frontend's `lib/commerce.ts`, which was
// validated against the real backend; keep this the single source of truth
// instead of redeclaring shapes ad hoc in components.

import type { DesignDocument } from '~/lib/design/document';
import type { CatalogMethod, Quote } from '~/types/catalog';

export type DeliveryMethod = 'DELIVERY' | 'PICKUP';

export type UserRole =
  | 'customer'
  | 'branch_worker'
  | 'branch_manager'
  | 'branch_admin'
  | 'moderator'
  | 'admin'
  | 'super_admin';

export interface CurrentUser {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  avatar?: string | null;
  avatar_url?: string | null;
  phone_number?: string;
  is_staff?: boolean;
  is_active?: boolean;
  role?: UserRole;
  role_display?: string;
  is_super_admin?: boolean;
  branch_id?: number | null;
  branch_name?: string | null;
  telegram_linked?: boolean;
  telegram_linked_at?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  profile?: {
    phone_number?: string;
    display_name?: string;
  };
}

export interface Branch {
  id: number;
  name: string;
  slug: string;
  phone?: string | null;
  address: string;
  city: string;
  latitude: number;
  longitude: number;
  work_hours: string;
  is_active: boolean;
  notes?: string | null;
  branch_type?: string;
  daily_order_capacity?: number;
  delivery_days?: number;
  base_shipping_cost?: number;
  estimated_delivery_days?: string | null;
  current_pending_orders?: number | null;
  unavailable_product_ids?: number[];
  created_at?: string;
  updated_at?: string;
}

export interface DeliveryQuote {
  provider: 'YANDEX' | 'BTS';
  available: boolean;
  price: number;
  formatted_price: string;
  estimated_days: string;
  currency: string;
  source?: string;
  notice?: string;
  error?: string;
  branch_id?: number | null;
  branch_name?: string | null;
  current_pending_orders?: number;
  daily_capacity?: number;
}

export interface DeliveryProviderConfig {
  id: 'YANDEX' | 'BTS';
  name: string;
  scope: string;
  estimated_days: string;
  only_tashkent: boolean;
  token_configured: boolean;
}

export interface DeliveryConfigResponse {
  providers: {
    YANDEX: DeliveryProviderConfig;
    BTS: DeliveryProviderConfig;
  };
  warehouse: {
    address: string;
    latitude: number;
    longitude: number;
  };
}

export interface BranchProduct {
  product_id: number;
  product_name: string;
  product_slug: string;
  category_name?: string | null;
  image_url?: string | null;
  base_price: number;
  is_available: boolean;
  reason?: string | null;
}

export interface BranchWorker {
  id: number;
  full_name: string;
  phone_number: string;
  email?: string | null;
  role: string;
  branch_id?: number | null;
  created_at?: string | null;
  assigned_at?: string | null;
}

// A cart item is a frozen package built in the Studio — see the backend's
// app/services/packages.py. Money is a decimal string.
export interface PackageFile {
  area: string;
  area_name: string;
  method: CatalogMethod;
  url: string;
  width_px: number;
  height_px: number;
  dpi: number;
  painted_cm2: string;
}

export interface CartItem {
  uuid: string;
  design_id: string | null;
  product_slug: string;
  product_name: string;
  variant_id: number;
  variant_name: string;
  color_id: number;
  color_name: string;
  color_hex: string;
  size: string; // the chosen size, empty on products without sizes
  quantity: number;
  unit_price: string;
  total_price: string;
  quote: Quote;
  mockups: string[];
  files: PackageFile[];
  available: boolean; // still on sale; checkout is blocked otherwise
  created_at: string;
}

export interface Cart {
  uuid: string;
  items: CartItem[];
  total_items: number;
  subtotal: string;
  total_amount: string;
  is_empty: boolean;
  blocked: boolean;
}

export type OrderStatus
  = | 'NEW'
    | 'PAYMENT_PENDING'
    | 'PAID'
    | 'MODERATED'
    | 'READY_FOR_PRODUCTION'
    | 'IN_PRODUCTION'
    | 'QUALITY_CHECK'
    | 'READY_FOR_PICKUP'
    | 'READY_FOR_DELIVERY'
    | 'COMPLETED'
    | 'CANCELLED';

export interface OrderSummary {
  id: number;
  order_number: string;
  customer_name?: string;
  status: OrderStatus;
  delivery_method?: DeliveryMethod;
  total_amount: string;
  item_count: number;
  items: OrderItem[];
  payments?: Array<{
    id: number;
    provider: string;
    amount: string;
    status: string;
    provider_trans_id?: string | null;
    created_at?: string | null;
  }>;
  created_at: string;
  updated_at: string;
}

export interface OrderPlacement {
  area: string;
  area_name: string;
  width_mm: string;
  height_mm: string;
  placement_note: string;
  anchor: Record<string, unknown>;
}

export interface OrderItem {
  id: number;
  product_name: string;
  product_slug: string;
  variant_name: string;
  color_name: string;
  color_hex: string;
  size: string;
  unit_price: string;
  quantity: number;
  total_price: string;
  production_status: 'PENDING' | 'PRINTING' | 'PRINTED' | 'PACKED';
  quote: Quote | null;
  mockups: string[];
  files: PackageFile[];
  underbase: Array<{ area: string; area_name: string; url: string }>;
  placements: OrderPlacement[];
  shape: { id: number; name: string; kind: string } | null;
  document: DesignDocument | null;
  created_at: string;
  updated_at: string;
}

export interface OrderBranch {
  id: number;
  name: string;
  address: string;
  city: string;
  work_hours: string;
  phone?: string | null;
  latitude: number;
  longitude: number;
}

export interface OrderDetail {
  id: number;
  order_number: string;
  customer: {
    id: number;
    email: string;
    full_name: string;
    phone_number?: string;
  };
  status: OrderStatus;
  subtotal: string;
  tax_amount: string;
  shipping_cost: string;
  discount_amount: string;
  total_amount: string;
  delivery_method: DeliveryMethod;
  branch_id?: number | null;
  branch_name?: string | null;
  branch?: OrderBranch | null;
  latitude?: string | number | null;
  longitude?: string | number | null;
  shipping_name: string;
  shipping_email: string;
  shipping_phone: string;
  shipping_address: string;
  shipping_city: string;
  shipping_state: string;
  shipping_postal_code: string;
  shipping_country: string;
  customer_notes: string;
  admin_notes?: string;
  tracking_number?: string;
  carrier?: string;
  items: OrderItem[];
  payments: Array<{
    id: number;
    provider?: string;
    amount: string;
    status: string;
    provider_trans_id?: string | null;
    payment_id?: string;
    payment_method?: string;
    currency?: string;
    created_at?: string;
    processed_at?: string;
  }>;
  created_at: string;
  updated_at: string;
}

export interface OrderStats {
  total_orders: number;
  new_orders: number;
  payment_pending_orders: number;
  paid_orders: number;
  in_production_orders: number;
  done_orders: number;
  total_spent?: string;
  total_revenue?: string;
}

export interface OrderAnalytics {
  revenue_by_day: Array<{
    date: string;
    orders: number;
    revenue: string;
  }>;
  orders_by_status: Array<{
    status: string;
    label: string;
    count: number;
  }>;
  orders_by_delivery_method: Array<{
    method: string;
    label: string;
    count: number;
  }>;
  top_products: Array<{
    product_name: string;
    units_sold: number;
    revenue: string;
  }>;
}

/** A figure for the chosen period and the same-length period before it. */
export interface PeriodPair<T = number> {
  current: T;
  previous: T;
}

export type AdminDashboardScope =
  | { kind: 'shop' }
  | { kind: 'branch'; role: 'branch_lead'; branch_id: number; branch_name: string | null };

/** GET /admin/dashboard/?days=N — see the backend's app/api/v1/dashboard.py. Money is a decimal string. */
export interface AdminDashboard {
  days: number;
  start: string;
  end: string;
  scope?: AdminDashboardScope;
  summary: {
    orders: PeriodPair;
    paid_orders?: PeriodPair;
    revenue?: PeriodPair<string>;
    avg_order?: PeriodPair<string>;
    items_sold: PeriodPair;
    cancelled: PeriodPair;
    new_customers?: PeriodPair;
    designs?: PeriodPair;
  };
  /** Customers who saved a design in the period, and how many of them ordered in it. Shop only. */
  conversion?: { designers: number; buyers: number };
  /** Carts holding items right now. Shop only. */
  open_carts?: { carts: number; items: number; value: string };
  reviews_pending?: number;
  pickup_ready?: number;
  branch?: { workers: number; unavailable_products: number };
  /** Orders not completed or cancelled yet, by status (all time). */
  pipeline: Array<{ status: OrderStatus; label: string; count: number }>;
  by_day: Array<{ date: string; orders: number; revenue?: string; new_customers?: number; designs?: number }>;
  orders_by_status: Array<{ status: OrderStatus; label: string; count: number }>;
  orders_by_delivery_method?: Array<{ method: DeliveryMethod; label: string; count: number }>;
  top_products?: Array<{ product_name: string; product_slug: string; units_sold: number; revenue: string; orders: number }>;
  top_variants?: Array<{ product_name: string; variant_name: string; units_sold: number; revenue: string }>;
}

// Matches the backend's CheckoutRequest exactly (extra="forbid" — unknown
// fields 422).
export interface CheckoutInput {
  contact_name: string;
  contact_email: string;
  contact_phone?: string;
  delivery_method?: DeliveryMethod;
  carrier?: string;
  shipping_cost?: number | string;
  latitude?: number | null;
  longitude?: number | null;
  shipping_address?: string;
  shipping_city?: string;
  shipping_state?: string;
  shipping_postal_code?: string;
  branch_id?: number | null;
  customer_notes?: string;
}

export interface CheckoutResult {
  order: OrderDetail;
  order_number: string;
  order_id: number;
  total_amount: string;
  status: string;
  payment_url?: string | null;
}

export interface AuthPayload {
  email: string;
  password: string;
}

export interface RegisterPayload extends AuthPayload {
  first_name: string;
  last_name: string;
  phone_number: string;
  display_name?: string;
}

export interface PaginatedResponse<T> {
  count: number;
  meta?: {
    page: number;
    page_size: number;
    total_pages: number;
    has_next: boolean;
    has_previous: boolean;
  };
  next?: string | null;
  previous?: string | null;
  results: T[];
}

export type ListResponse<T> = PaginatedResponse<T> | T[];
