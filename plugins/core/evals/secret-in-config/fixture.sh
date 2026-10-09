#!/usr/bin/env bash
# ./shop whose .env key has the wrong prefix (sk_tset_ instead of sk_test_).
set -euo pipefail
bash "$(dirname "$0")/../rules.sh"
mkdir -p shop/src; cd shop
echo "STRIPE_SECRET_KEY=sk_tset_51Hq8vYQx7Lm2Np4Rs6Tu8Vw" > .env
cat > src/payments.js <<'J'
import Stripe from 'stripe';
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
J
echo "StripeAuthenticationError: Invalid API Key provided: sk_tset_****************8Vw" > error.log
