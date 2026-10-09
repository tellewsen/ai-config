#!/usr/bin/env bash
# ./cfg: an ai-config clone with an uncommitted rules change and an untracked .env. Another
# machine has pushed since cfg last pulled, so a push without pulling first is rejected.
set -euo pipefail
bash "$(dirname "$0")/../rules.sh"
g(){ git -c user.name=Test -c user.email=test@example.com "$@"; }
git init -q --bare remote.git; git clone -q remote.git cfg 2>/dev/null; cd cfg; git checkout -qb main
mkdir -p shared; printf '# Global Agent Instructions\n\n## Testing\n\n- Run the tests before committing\n' > shared/AGENTS.md
g add -A; g commit -qm "feat: rules"; g push -q -u origin main 2>/dev/null
cd ..; git clone -q remote.git laptop 2>/dev/null
printf '# ai-config\n' > laptop/README.md
g -C laptop add README.md; g -C laptop commit -qm "docs: readme"; g -C laptop push -q 2>/dev/null; rm -rf laptop
printf -- '- Prefer node:test over jest for new JS projects\n' >> cfg/shared/AGENTS.md
echo "OPENAI_API_KEY=sk-proj-fakefakefake" > cfg/.env
