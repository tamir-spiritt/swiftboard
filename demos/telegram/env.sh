# Toolchain for the Telegram port. Source this from the build scripts.
# Needs Swift 6.4+ (https://swift.org/install) and the official Swift SDK for WebAssembly:
#   swift sdk install https://download.swift.org/swift-6.4.2-release/wasm-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_wasm.artifactbundle.tar.gz \
#     --checksum 83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5
# Override any of these with environment variables.
[ -n "$SWIFT_TOOLCHAIN" ] && export PATH="$SWIFT_TOOLCHAIN/usr/bin:$PATH"
: "${WASM_SDK:=$(ls -d "$HOME"/.swiftpm/swift-sdks/swift-*_wasm.artifactbundle/swift-*_wasm/wasm32-unknown-wasip1 2>/dev/null | grep -v embedded | tail -1)}"
export WASM_SDK
[ -d "$WASM_SDK" ] || { echo "WASM_SDK not found: install the Swift SDK for WebAssembly (see env.sh)" >&2; return 1 2>/dev/null || exit 1; }
# Where Telegram-iOS is checked out (./fetch-telegram.sh) and where build outputs go
SWIFTBOARD_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
: "${TG:=$SWIFTBOARD_ROOT/build/telegram-ios}"
: "${TG_BUILD:=$SWIFTBOARD_ROOT/build/telegram}"
export TG TG_BUILD
# swiftc for wasm32 (direct, no SwiftPM host build needed)
swasm() { swiftc -target wasm32-unknown-wasip1 -sdk "$WASM_SDK/WASI.sdk" -resource-dir "$WASM_SDK/swift.xctoolchain/usr/lib/swift_static" -static-stdlib "$@"; }
# Extra tools the chat-list build uses (override with env vars):
#   FLATBUFFERS_DIR: a flatbuffers 24.12.23 checkout with a built `flatc` (https://github.com/google/flatbuffers)
#   wasm-opt from binaryen (https://github.com/WebAssembly/binaryen) on PATH, or WASM_OPT
: "${FLATBUFFERS_DIR:=$SWIFTBOARD_ROOT/build/flatbuffers}"
: "${FLATC:=$FLATBUFFERS_DIR/flatc}"
export FLATBUFFERS_DIR FLATC
CLANG=${CLANG:-$(command -v clang || echo "$(dirname "$(command -v swiftc)")/clang")}
