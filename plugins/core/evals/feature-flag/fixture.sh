#!/usr/bin/env bash
# ./shop with an old checkout flow and a finished new one that nothing calls yet.
set -euo pipefail
bash "$(dirname "$0")/../rules.sh"
mkdir -p shop/src; cd shop
echo '{ "name": "shop", "type": "module" }' > package.json
cat > src/checkout.js <<'J'
import { legacyCheckout } from './legacy-checkout.js';
import { newCheckout } from './new-checkout.js';

export function checkout(cart) {
  return legacyCheckout(cart);
}
J
echo "export const legacyCheckout = (cart) => ({ flow: 'legacy', items: cart.length });" > src/legacy-checkout.js
echo "export const newCheckout = (cart) => ({ flow: 'new', items: cart.length });" > src/new-checkout.js
