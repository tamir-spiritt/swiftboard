#!/usr/bin/env bash
# Downloads Telegram-iOS (GPL) into build/telegram-ios. It is never committed to this repository.
set -e
. "$(dirname "$0")/env.sh"
if [ ! -d "$TG/.git" ]; then
  git clone --filter=blob:none --no-checkout https://github.com/TelegramMessenger/Telegram-iOS.git "$TG"
fi
cd "$TG"
git checkout -q "${TG_REV:-master}" -- . 2>/dev/null || git checkout -q "${TG_REV:-master}"
echo "Telegram-iOS at $(git rev-parse --short HEAD) in $TG"
