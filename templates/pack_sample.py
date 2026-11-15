"""打一个标准 ZIP（正斜杠分隔）——PowerShell 5.1 的 Compress-Archive 会写成反斜杠，
在非 Windows 环境/部分解压库下会变成名为 "images\\card_01.png" 的单个文件。"""

import os
import zipfile

BASE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.join(BASE, "demo_card")
OUT = os.path.join(BASE, "demo_card.zip")


def main():
    files = []
    for root, _dirs, names in os.walk(PACK):
        for n in sorted(names):
            full = os.path.join(root, n)
            files.append((full, os.path.relpath(full, PACK).replace("\\", "/")))

    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for full, arc in files:
            z.write(full, arc)
    print("wrote", OUT, os.path.getsize(OUT), "B")
    for _full, arc in files:
        print(" ", arc)


if __name__ == "__main__":
    main()
