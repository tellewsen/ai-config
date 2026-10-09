#!/usr/bin/env bash
# ./shop main checkout (another session's uncommitted edit, its stash on fix/typo) and
# ./shop-discounts worktree on feat/discounts (this session: unpushed commit, edit, own stash).
set -euo pipefail
g(){ git -c user.name=Test -c user.email=test@example.com "$@"; }
git init -q --bare remote.git; git clone -q remote.git shop 2>/dev/null; cd shop
echo "# shop" > README.md; mkdir -p src; echo "export const cart = [];" > src/cart.js; echo "export const price = (x) => x;" > src/pricing.js
g add -A; g commit -qm init; g push -q origin HEAD:main 2>/dev/null; g branch -q -u origin/main
g checkout -qb fix/typo; echo "# Shop" > README.md; g stash push -qm "WIP readme capitalisation"; g checkout -q main
g worktree add -q -b feat/discounts ../shop-discounts 2>/dev/null; cd ../shop-discounts
echo "export const DISCOUNT_CODES = { SPRING10: 0.1 };" > src/discounts.js; g add src/discounts.js; g commit -qm "feat(pricing): discount code table"
echo "// rounding experiment" >> src/discounts.js; g stash push -qm "WIP rounding experiment"
echo "export const price = (x, discount = 0) => Math.max(0, x - x * discount);" > src/pricing.js
cd ../shop; echo "export const addToCart = (i) => cart.push(i);" >> src/cart.js
