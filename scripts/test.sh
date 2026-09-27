#!/bin/bash
# Запуск тестов на машине без полного Xcode.
#
# XCTest в этой среде недоступен (Command Line Tools его не содержат,
# swift.org-тулчейны тоже), поэтому тесты используют swift-testing,
# который есть в тулчейне swift-6.3.2-RELEASE из ~/Library/Developer/Toolchains.
# Если тулчейн не установлен — откатываемся на обычный `swift test`
# (работает на машинах с Xcode или Linux-тулчейнами).
set -euo pipefail
TC="$HOME/Library/Developer/Toolchains/swift-6.3.2-RELEASE.xctoolchain"
if [[ -x "$TC/usr/bin/swift" ]]; then
    exec "$TC/usr/bin/swift" test "$@"
else
    exec swift test "$@"
fi
