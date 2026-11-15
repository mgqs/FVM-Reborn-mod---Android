"""Replicates scripts/external_mod_system/external_mod_system.gml 的校验规则，
用来在把示例包推到手机上之前先自查一遍（不进游戏也能发现 90% 的导入失败原因）。"""

import json
import os
import sys
import zipfile

ALLOWED_ID = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
ALLOWED_TARGET = {"normal", "air", "air_only", "throw", "track", "pierce",
                  "pierce_air", "rotate", "d_fruit", "all"}
ALLOWED_ORIGIN = {"bottom_center", "center", "custom"}
NUMERIC_FIELDS = ["hp", "cost", "atk", "range", "cooldown", "cycle"]
DEFAULTS = {"hp": 50, "cost": 100, "atk": 20, "range": 10, "cooldown": 420, "cycle": 120}

errors = []
warnings = []


def fail(msg):
    errors.append(msg)


def id_valid(cid):
    if not isinstance(cid, str) or not (3 <= len(cid) <= 100):
        return False
    if cid.find(".") < 1:          # string_pos(".", cid) < 2 → 位置 1 起算，<2 即索引 0
        return False
    return all(ch in ALLOWED_ID for ch in cid)


def check_numbers(payload, count, label):
    """external_mod_numbers：标量会展开成 count 份，数组必须正好 count 项。"""
    if not isinstance(payload, list):
        payload = [payload] * count
    if len(payload) != count:
        fail(f"{label} 必须包含 {count} 个星级数值（当前 {len(payload)}）")
        return
    for i, v in enumerate(payload):
        if isinstance(v, bool) or not isinstance(v, (int, float)):
            fail(f"{label}[{i}] 不是数值")
        elif v < 0:
            fail(f"{label}[{i}] 为负数")


def safe_rel(root, rel):
    """external_mod_path：禁绝对路径、盘符、.. 与空段。"""
    if not isinstance(rel, str) or rel == "":
        fail(f"资源路径为空：{rel!r}")
        return None
    p = rel.replace("\\", "/")
    if ":" in p or p.startswith("/"):
        fail(f"资源路径必须是包内相对路径：{rel}")
        return None
    parts = p.split("/")
    if any(seg in ("..", "", ".") for seg in parts):
        fail(f"资源路径含无效目录：{rel}")
        return None
    full = os.path.join(root, *parts)
    if not os.path.isfile(full):
        fail(f"文件不存在：{rel} → {full}")
        return None
    return full


def check_animation(root, anim, label):
    frames = anim.get("frames")
    if not isinstance(frames, list) or not (1 <= len(frames) <= 256):
        fail(f"{label} 动画需要 1–256 张 PNG")
        return
    fps = anim.get("fps", 12)
    if not isinstance(fps, (int, float)) or not (1 <= fps <= 60):
        fail(f"{label} 动画 fps 范围为 1–60（当前 {fps}）")
    origin = anim.get("origin")
    if origin is not None and origin not in ALLOWED_ORIGIN:
        fail(f"{label} origin 只能是 bottom_center、center 或 custom（当前 {origin}）")
    for fr in frames:
        full = safe_rel(root, fr)
        if full and os.path.splitext(full)[1].lower() != ".png":
            fail(f"{label} 帧必须是 .png：{fr}")
    events = anim.get("events", [])
    if not isinstance(events, list) or len(events) > 128:
        fail(f"{label} events 格式无效")
    else:
        for ev in events:
            f = ev.get("frame", -1)
            name = ev.get("name", "")
            if not isinstance(f, int) or not (1 <= f <= len(frames)) or not name:
                fail(f"{label} 事件 frame 从 1 开始且不能超过帧数：{ev}")


def check_card(root, rel, seen_ids):
    path = safe_rel(root, rel)
    if not path:
        return
    with open(path, encoding="utf-8") as f:
        d = json.load(f)

    cid = d.get("id", "")
    if not id_valid(cid):
        fail(f"卡片 ID 无效：{cid!r}（3–100 字符，含 . ，允许字母数字 . _ -）")
    elif cid in seen_ids:
        fail(f"卡片 ID 重复：{cid}")
    seen_ids.add(cid)

    if d.get("api_version", 1) != 1:
        fail("卡片 api_version 必须为 1")
    if not d.get("name"):
        fail("卡片缺少名称 name")
    if not d.get("description"):
        fail("卡片缺少描述 description")

    is_gold = bool(d.get("is_gold", d.get("is_god", False)))
    max_level = d.get("max_star", 18 if is_gold else 16)
    if max_level not in (16, 18):
        fail(f"max_star 只能是 16 或 18（当前 {max_level}）")
    if max_level == 18 and not is_gold:
        fail("18 星卡片必须是金卡（is_gold: true）")

    script = d.get("script", "logic.lua")
    if not script.lower().endswith(".lua"):
        warnings.append(f"script 不是 .lua（{script}）：安卓会忽略行为脚本")
    elif not os.path.isfile(os.path.join(root, *script.replace("\\", "/").split("/"))):
        warnings.append(f"缺少 {script}：安卓忽略、Windows 会当成加载失败")

    shapes = d.get("shapes", [d])
    if not isinstance(shapes, list) or not (1 <= len(shapes) <= 6):
        fail("需要 1–6 个连续形态")

    card_dir = os.path.dirname(path)
    for s, sh in enumerate(shapes):
        tag = f"形态{s}"
        if sh.get("shape", s) != s:
            fail(f"{tag} 的 shape 必须从 0 连续编号")
        for field in NUMERIC_FIELDS:
            check_numbers(sh.get(field, DEFAULTS[field]), max_level + 1, f"{tag}.{field}")
        tt = sh.get("target_type", "normal")
        if tt not in ALLOWED_TARGET:
            fail(f"{tag}.target_type 无效：{tt}")
        icon = sh.get("icon", d.get("icon", d.get("sprite", "card.png")))
        icon_full = safe_rel(card_dir, icon)
        if icon_full and os.path.splitext(icon_full)[1].lower() != ".png":
            fail(f"{tag} 图标必须是 .png：{icon}")
        anims = sh.get("animations", d.get("animations", {"idle": {"frames": [icon], "fps": 1}}))
        if "idle" not in anims:
            fail(f"{tag} 缺少 idle 动画")
        for key, anim in anims.items():
            check_animation(card_dir, anim, f"{tag}.{key}")

    for key, proj in d.get("projectiles", {}).items():
        check_animation(card_dir, proj, f"子弹 {key}")


def main(pack_dir):
    if zipfile.is_zipfile(pack_dir):
        import tempfile
        tmp = tempfile.mkdtemp(prefix="modcheck_")
        with zipfile.ZipFile(pack_dir) as z:
            for info in z.infolist():
                if "\\" in info.filename:
                    fail(f"ZIP 内条目用了反斜杠，安卓/部分解压库会当成单个文件名：{info.filename}")
            z.extractall(tmp)
        print(f"压缩包：{os.path.basename(pack_dir)}")
        pack_dir = tmp

    pack_dir = os.path.abspath(pack_dir)
    root = pack_dir
    for nested in sorted(os.listdir(pack_dir)):
        cand = os.path.join(pack_dir, nested)
        if os.path.isdir(cand) and (os.path.isfile(os.path.join(cand, "manifest.json"))
                                    or os.path.isfile(os.path.join(cand, "card.json"))):
            if root != pack_dir:
                fail("包内只能有一层外目录")
            root = cand

    manifest_path = os.path.join(root, "manifest.json")
    manifest = {}
    if os.path.isfile(manifest_path):
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)
        if manifest.get("api_version", 1) != 1:
            fail("不支持的 Mod API 版本（api_version 必须为 1）")
    else:
        warnings.append("没有 manifest.json，按裸 card.json 解析")

    cards = manifest.get("cards", ["card.json"])
    if not isinstance(cards, list) or not (1 <= len(cards) <= 64):
        fail("manifest.cards 必须为 1–64 个 card.json 路径")
        cards = []

    seen = set()
    for rel in cards:
        check_card(root, rel, seen)

    print(f"包根：{root}")
    print(f"包名：{manifest.get('name', '(未声明)')}")
    print(f"卡片：{len(seen)} 个 → {', '.join(sorted(seen)) or '(无)'}")
    for w in warnings:
        print(f"  [提示] {w}")
    if errors:
        print(f"\n发现 {len(errors)} 个问题：")
        for e in errors:
            print(f"  [错误] {e}")
        return 1
    print("\n校验通过，可以直接投放。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "demo_card")))
