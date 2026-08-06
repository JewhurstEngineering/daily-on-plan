#!/usr/bin/env python3
"""Previously patched Watch embed into PlugIns/ for Xcode 26.

That hid the companion from the iPhone Watch app's Available Apps list.
Keep the XcodeGen default Embed Watch Content → Watch/ path instead.
This script is intentionally a no-op retained for history / future use.
"""

from __future__ import annotations


def main() -> int:
    print("Skipping PlugIns patch — Watch companion stays under Watch/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
