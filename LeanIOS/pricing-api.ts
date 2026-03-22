/**
 * pricing-api.ts
 * meeting-iOS
 *
 * Pricing API integration — fetches and caches pricing tier data,
 * handles subscription plan selection, and notifies the native layer.
 */

// ── Types ─────────────────────────────────────────────────────────────────────

export interface PricingTier {
  id: string;
  name: string;
  price: number | 'custom';
  currency: string;
  period: 'monthly' | 'annual' | 'one-time' | 'custom';
  features: string[];
  isPopular?: boolean;
  ctaLabel: string;
  ctaUrl: string;
}

export interface PricingResponse {
  tiers: PricingTier[];
  currencyCode: string;
  lastUpdated: string;
}

export interface SubscriptionEvent {
  tierId: string;
  tierName: string;
  price: number | 'custom';
  currency: string;
}

// ── Configuration ─────────────────────────────────────────────────────────────

const PRICING_BASE_URL = 'https://www.meetings-managed.com';
const PRICING_ENDPOINT = `${PRICING_BASE_URL}/api/pricing`;
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

// ── Static fallback data ──────────────────────────────────────────────────────

const STATIC_TIERS: PricingTier[] = [
  {
    id: 'starter',
    name: 'Starter',
    price: 0,
    currency: 'USD',
    period: 'monthly',
    features: [
      'Up to 5 meetings/month',
      'Basic agenda templates',
      'Email summaries',
    ],
    isPopular: false,
    ctaLabel: 'Get Started Free',
    ctaUrl: `${PRICING_BASE_URL}/signup?plan=starter`,
  },
  {
    id: 'pro',
    name: 'Professional',
    price: 12,
    currency: 'USD',
    period: 'monthly',
    features: [
      'Unlimited meetings',
      'Advanced agenda templates',
      'AI-powered meeting notes',
      'Calendar integrations',
      'Priority support',
    ],
    isPopular: true,
    ctaLabel: 'Start Free Trial',
    ctaUrl: `${PRICING_BASE_URL}/signup?plan=pro`,
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price: 'custom',
    currency: 'USD',
    period: 'custom',
    features: [
      'Everything in Professional',
      'SSO & advanced security',
      'Custom integrations',
      'Dedicated account manager',
      'SLA guarantee',
    ],
    isPopular: false,
    ctaLabel: 'Contact Sales',
    ctaUrl: `${PRICING_BASE_URL}/contact?plan=enterprise`,
  },
];

// ── Cache ─────────────────────────────────────────────────────────────────────

interface CacheEntry {
  data: PricingResponse;
  timestamp: number;
}

let cache: CacheEntry | null = null;

function isCacheValid(): boolean {
  return cache !== null && Date.now() - cache.timestamp < CACHE_TTL_MS;
}

// ── API functions ─────────────────────────────────────────────────────────────

/**
 * Fetch pricing tiers from the server.
 * Returns cached data when available, falls back to static tiers on error.
 */
export async function fetchPricingTiers(): Promise<PricingResponse> {
  if (isCacheValid()) {
    return cache!.data;
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);

    const response = await fetch(PRICING_ENDPOINT, {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data: PricingResponse = await response.json();
    cache = { data, timestamp: Date.now() };
    return data;
  } catch (error) {
    console.warn('[pricing-api] Failed to fetch pricing, using static data:', error);
    const fallback: PricingResponse = {
      tiers: STATIC_TIERS,
      currencyCode: 'USD',
      lastUpdated: new Date().toISOString(),
    };
    return fallback;
  }
}

/**
 * Handle a user selecting a pricing tier.
 * Fires an analytics event (if available) and opens the tier's CTA URL.
 */
export function handleTierSelection(tier: PricingTier): void {
  trackPricingEvent({ tierId: tier.id, tierName: tier.name, price: tier.price, currency: tier.currency });

  // Notify the native iOS bridge if available.
  if (
    typeof window !== 'undefined' &&
    (window as any).AuthBridge?.openPricing
  ) {
    (window as any).AuthBridge.openPricing();
  }

  if (typeof window !== 'undefined') {
    window.location.href = tier.ctaUrl;
  }
}

/**
 * Render pricing tiers into a container element.
 * @param containerId - ID of the DOM element to render into.
 */
export async function renderPricingTiers(containerId: string): Promise<void> {
  const container = document.getElementById(containerId);
  if (!container) {
    console.warn(`[pricing-api] Container #${containerId} not found`);
    return;
  }

  container.innerHTML = '<p class="pricing-loading">Loading plans…</p>';

  const { tiers } = await fetchPricingTiers();

  container.innerHTML = tiers
    .map(
      (tier) => `
    <div class="pricing-card${tier.isPopular ? ' pricing-card--popular' : ''}">
      ${tier.isPopular ? '<span class="pricing-badge">Most Popular</span>' : ''}
      <h3 class="pricing-tier-name">${escapeHtml(tier.name)}</h3>
      <div class="pricing-price">
        ${tier.price === 'custom' ? 'Custom' : `$${tier.price}`}
        ${tier.price !== 'custom' ? `<span class="pricing-period">/${tier.period}</span>` : ''}
      </div>
      <ul class="pricing-features">
        ${tier.features.map((f) => `<li>${escapeHtml(f)}</li>`).join('')}
      </ul>
      <a href="${escapeHtml(tier.ctaUrl)}" class="pricing-cta" data-tier-id="${escapeHtml(tier.id)}">
        ${escapeHtml(tier.ctaLabel)}
      </a>
    </div>
  `
    )
    .join('');

  // Attach click handlers for native bridge notification.
  container.querySelectorAll<HTMLAnchorElement>('.pricing-cta').forEach((btn) => {
    btn.addEventListener('click', (evt) => {
      const tierId = btn.dataset.tierId;
      const tier = tiers.find((t) => t.id === tierId);
      if (tier) {
        evt.preventDefault();
        handleTierSelection(tier);
      }
    });
  });
}

// ── Analytics ─────────────────────────────────────────────────────────────────

function trackPricingEvent(event: SubscriptionEvent): void {
  // Forward to any registered analytics provider.
  if (typeof window !== 'undefined') {
    const w = window as any;
    if (typeof w.gtag === 'function') {
      w.gtag('event', 'select_pricing_tier', {
        tier_id:   event.tierId,
        tier_name: event.tierName,
        value:     typeof event.price === 'number' ? event.price : 0,
        currency:  event.currency,
      });
    }
    if (typeof w.analytics?.track === 'function') {
      w.analytics.track('Pricing Tier Selected', event);
    }
  }
}

// ── Utilities ─────────────────────────────────────────────────────────────────

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
