"""Sets up the game's Discord server as docs/discord.md describes it, through a bot.

    python scripts/discord-setup.py --dry --clipboard   # says what it would do, changes nothing
    python scripts/discord-setup.py --clipboard         # does it
    python scripts/discord-setup.py --clipboard --webhooks --posts   # Iruka's webhooks and posts
    python scripts/discord-setup.py --clipboard --new-webhooks       # Iruka's webhooks made anew

The bot's token is taken from the clipboard (--clipboard: copy it in the Developer Portal, then
run the script), from the environment variable DISCORD_TOKEN, or asked for in the terminal (not
shown as it is typed; pasting into a hidden prompt does not always work in a Windows terminal,
which is what --clipboard is for). It is never written anywhere. The bot must be on the server
with the Administrator permission, and its role dragged to the top of the server's roles.

What it does, all of it safe to run again:
  - the server's safety: verification Medium, media scanned for everyone, notifications only
    for mentions; Discord's own "X joined" messages off;
  - the roles: staff, special, the game's (VIP, legendary shinobi, the ten ranks, Six Paths,
    given by Bloxlink), the chat levels (given by the leveling bot), languages and pings, in
    order, with the other bots' roles kept above them;
  - the categories and channels with their permissions and slow modes, the voice rooms with
    their sizes and the AFK room. CHANNELS THAT ALREADY EXIST ARE RENAMED AND MOVED, NEVER MADE
    AGAIN: what was written in them stays. A channel it does not know is left alone;
  - Community, AutoMod (with alerts in the staff's log), the welcome screen and onboarding
    (language, pings);
  - the custom emoji (assets/discord/emoji) and stickers (assets/discord/stickers) that are not
    there yet;
  - with --webhooks, a webhook "Iruka-sensei" in the channels the owner posts to through
    Discohook. Their addresses are secrets (whoever has one can post there), so they are written
    to docs/discord-posts/ready/webhooks.txt (local, not in git) and not to the terminal, whose
    output gets pasted into chats. --new-webhooks deletes Iruka's webhooks and makes new ones,
    for when an address got out;
  - with --posts, the posts of docs/discord-posts filled with the server's own channels and
    roles, ready to paste into Discohook, in docs/discord-posts/ready;
  - a permanent invite, printed at the end.

It posts nothing: what the channels say is the owner's own (owner, 2026-10-21: "let it not
write any messages of its own; I replaced them with mine").

What it cannot do: give people their roles (staff and special ones by hand, the game's by
Bloxlink, the levels by the leveling bot; docs/discord.md says how).
"""

import argparse
import base64
import getpass
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

API = "https://discord.com/api/v10"
GUILD = "1562078615405990060"
AGENT = "DiscordBot (https://github.com/vamiss8/shinobi-collect-it-all, 1.0)"
ASSETS = Path(__file__).resolve().parent.parent / "assets" / "discord"
POSTS = Path(__file__).resolve().parent.parent / "docs" / "discord-posts"

# Permission bits (Discord's own numbers).
VIEW = 1 << 10
SEND = 1 << 11
SEND_IN_THREADS = 1 << 38
PUBLIC_THREADS = 1 << 35
PRIVATE_THREADS = 1 << 36
MENTION_ALL = 1 << 17
MANAGE_MESSAGES = 1 << 13
MANAGE_THREADS = 1 << 34
KICK = 1 << 1
TIMEOUT = 1 << 40
ADMIN = 1 << 3
CONNECT = 1 << 20

# Channel types.
TEXT, VOICE, CATEGORY, ANNOUNCEMENT, FORUM = 0, 2, 4, 5, 15

# The server's system messages left off: joins, the replies to joins, setup tips.
SYSTEM_FLAGS = (1 << 0) | (1 << 2) | (1 << 3)

MOD = MANAGE_MESSAGES | MANAGE_THREADS | TIMEOUT

# Roles, top to bottom: name, color, shown apart in the member list, permissions.
STAFF_ROLES = [
    ("Founder", 0x9D5CFF, True, ADMIN),
    ("Developer", 0xFF3B30, True, MOD | KICK | MENTION_ALL),
    ("Designer", 0xFF6FB5, True, 0),
    ("Moderator", 0x4FC3F7, True, MOD),
    ("Helper", 0x80CBC4, True, TIMEOUT),
    ("Staff", 0, False, MENTION_ALL),
]
SPECIAL_ROLES = [
    ("White Reaper", 0xFFFFFF, True, 0),
    ("Content Creator", 0xFF8A3D, True, 0),
    ("Tester", 0x81C784, True, 0),
    # Given by Bloxlink: the Daimyo VIP pass.
    ("VIP", 0xFFC83D, True, 0),
]
# Given by Bloxlink, by the passes and the badges (docs/discord.md has the ids).
GAME_ROLES = [
    ("Legendary: Hagoromo", 0xEDE6D3, False, 0),
    ("Legendary: Tobirama", 0x5BA8E6, False, 0),
    ("Legendary: Tsunade", 0x7CCB6A, False, 0),
    # The ten ranks, highest first, in the game's colors (Config/Rebirths).
    ("Sage of Six Paths", 0xFFF8E1, False, 0),
    ("Sage", 0xFFD54F, False, 0),
    ("Kage", 0xFF5252, False, 0),
    ("Sannin", 0xFF7043, False, 0),
    ("ANBU Captain", 0xFFCA28, False, 0),
    ("ANBU", 0xF06292, False, 0),
    ("Jonin", 0xBA68C8, False, 0),
    ("Special Jonin", 0x7986CB, False, 0),
    ("Chunin", 0x4FC3F7, False, 0),
    ("Genin", 0x9CCC65, False, 0),
    ("Six Paths Hunter", 0xECEFF1, False, 0),
]
# Chat levels, given by the leveling bot: Naruto's own road, from the first D-rank mission
# to the Will of Fire, in colors from leaf to fire. Not the game's ranks (owner, 2026-10-21:
# "something like it, but not the rebirths").
LEVEL_ROLES = [
    ("Will of Fire", 0xE53E2B, False, 0),
    ("Hokage Candidate", 0xEE6234, False, 0),
    ("Jinchuriki", 0xF4843D, False, 0),
    ("Toad Summoner", 0xF5A445, False, 0),
    ("Rasengan", 0xF2C14A, False, 0),
    ("Shadow Clone", 0xE6D04E, False, 0),
    ("Water Walker", 0xC7D65A, False, 0),
    ("Tree Climber", 0x7FC45E, False, 0),
    ("Bell Thief", 0x9CCF7A, False, 0),
    ("Cat Catcher", 0xB5D99C, False, 0),
]
# Language roles show the language's channel; English is the server's own and needs none.
LANGUAGES = [
    # role, channel, aliases, flag, title in onboarding, the channel's topic, key of its post
    ("Русский", "🇷🇺・русский", ["general-ru"], "🇷🇺", "Русский", "Общий чат на русском.", "ru"),
    ("Español", "🇪🇸・español", [], "🇪🇸", "Español", "Chat en español.", "es"),
    ("Português", "🇧🇷・português", [], "🇧🇷", "Português (Brasil)", "Chat em português.", "pt"),
    ("Français", "🇫🇷・français", [], "🇫🇷", "Français", "Discussion en français.", "fr"),
    ("Deutsch", "🇩🇪・deutsch", [], "🇩🇪", "Deutsch", "Chat auf Deutsch.", "de"),
]
PING_ROLES = [
    ("Codes Ping", 0, False, 0),
    ("Updates Ping", 0, False, 0),
    ("Events Ping", 0, False, 0),
    ("Giveaways Ping", 0, False, 0),
    ("QOTD Ping", 0, False, 0),
    ("Sneak Peeks Ping", 0, False, 0),
]
ROLES = (
    STAFF_ROLES + SPECIAL_ROLES + GAME_ROLES + LEVEL_ROLES
    + [(name, 0, False, 0) for name, *_ in LANGUAGES] + PING_ROLES
)

BUG_GUIDE = """Please write:
- What happened, and what you expected
- Where (which zone / menu) and what you pressed
- Device: PC / phone / tablet / console
- A screenshot or video, if you can"""

SUGGEST_GUIDE = "One idea per post. Say what you would change and why. Pick a tag."

# Voice rooms for everyone: a size for every kind of talk (owner: "let everyone find a place
# to talk"). name, aliases, the most people (0: any).
VOICE_ROOMS = [
    ("🍜 Ichiraku Ramen", ["Lounge"], 0),
    ("🏯 Hokage Rock", [], 0),
    ("👥 Two-Man Cell", [], 2),
    ("🐸 Legendary Sannin", [], 3),
    ("🍥 Team 7", [], 4),
    ("🌀 Five Kage Summit", [], 5),
    ("☁️ Akatsuki Hideout", [], 10),
]
AFK_ROOM = "💤 Shikamaru's Nap"

# The stickers: file in assets/discord/stickers, name, the emoji it is found by.
STICKERS = [
    ("naruto_six_paths", "Six Paths Naruto", "🍥"),
    ("madara", "Madara", "🔥"),
    ("iruka", "Iruka Sensei", "📚"),
    ("fukasaku", "Fukasaku", "🐸"),
    ("ten_tails", "Ten-Tails", "👁️"),
]

# Where the owner posts through Discohook as Iruka.
WEBHOOK_NAME = "Iruka-sensei"


def hint(code: int, text: str, path: str = "") -> str:
    """What an error most likely means, for whoever runs this."""
    if code in (403, 404) and "/auto-moderation/" in path:
        return "\n  Discord does not let a bot change this rule (it may be one Discord made itself): edit it by hand."
    if code == 400 and not text.strip():
        return ("\n  An empty 400 comes before Discord reads the request: the token is garbled."
                "\n  Run with --clipboard after copying the token, or set DISCORD_TOKEN.")
    if code == 401:
        return ("\n  Discord does not take this token. Copy the BOT token (Bot tab > Reset Token),"
                "\n  not the application id or the client secret.")
    if code in (403, 404):
        return "\n  Is the bot on the server, with Administrator? Invite it with the OAuth2 link."
    return ""


def clipboard() -> str:
    """The text on the clipboard, read through PowerShell (Windows) or tkinter."""
    try:
        done = subprocess.run(
            ["powershell", "-NoProfile", "-Command", "Get-Clipboard -Raw"],
            capture_output=True, text=True, timeout=10,
        )
        if done.returncode == 0 and done.stdout.strip():
            return done.stdout
    except (OSError, subprocess.SubprocessError):
        pass
    try:
        import tkinter
        root = tkinter.Tk()
        root.withdraw()
        text = root.clipboard_get()
        root.destroy()
        return text
    except Exception:
        return ""


def clean(token: str) -> str:
    """The token with what a terminal may have added taken off: spaces, control characters, a
    "Bot " in front."""
    token = re.sub(r"[\x00-\x1f\x7f\s]", "", token)
    if token.lower().startswith("bot"):
        token = token[3:]
    return token


def looks_like_token(token: str) -> bool:
    """A bot token is three parts of letters, digits, - and _ joined by dots."""
    return re.fullmatch(r"[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{4,}\.[A-Za-z0-9_\-]{20,}", token) is not None


_flakes = iter(range(1, 1 << 12))


def snowflake() -> str:
    """A new id in Discord's form: milliseconds since 2015 and a counter."""
    return str(((int(time.time() * 1000) - 1420070400000) << 22) | next(_flakes))


def data_uri(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


class Discord:
    def __init__(self, token: str, dry: bool):
        self.token = token
        self.dry = dry

    def send(self, method: str, path: str, data, kind: str | None):
        while True:
            request = urllib.request.Request(API + path, data=data, method=method)
            request.add_header("Authorization", f"Bot {self.token}")
            request.add_header("User-Agent", AGENT)
            if kind:
                request.add_header("Content-Type", kind)
            try:
                with urllib.request.urlopen(request) as response:
                    text = response.read().decode()
                    return json.loads(text) if text else None
            except urllib.error.HTTPError as error:
                text = error.read().decode()
                if error.code == 429:
                    wait = float(json.loads(text).get("retry_after", 1))
                    if wait > 5:
                        print(f"  (Discord asks to wait {wait:.0f} s: its limit on how fast this may be done)")
                    time.sleep(wait + 0.1)
                    continue
                raise RuntimeError(f"{method} {path}: {error.code} {text}{hint(error.code, text, path)}") from None

    def call(self, method: str, path: str, body=None, write: bool = True):
        if self.dry and write:
            print(f"  [dry] {method} {path}")
            return None
        data = json.dumps(body).encode() if body is not None else None
        return self.send(method, path, data, "application/json" if data is not None else None)

    def form(self, path: str, fields: dict, file_field: str, file: Path):
        """A multipart POST, which a sticker needs."""
        if self.dry:
            print(f"  [dry] POST {path} ({file.name})")
            return None
        boundary = uuid.uuid4().hex
        parts = []
        for name, value in fields.items():
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{file.name}"\r\n'
            f"Content-Type: image/png\r\n\r\n".encode() + file.read_bytes() + b"\r\n"
        )
        parts.append(f"--{boundary}--\r\n".encode())
        return self.send("POST", path, b"".join(parts), f"multipart/form-data; boundary={boundary}")

    def get(self, path: str):
        return self.call("GET", path, write=False)


def write_posts(named: dict, roles: dict, addresses: dict):
    """Fills every post of docs/discord-posts: {#key} becomes a link to the channel, {@Role} the
    role's mention (an embed never pings). Writes a page a channel to paste from."""
    print("Posts")
    if not POSTS.exists():
        print("  docs/discord-posts is not here: nothing to fill")
        return

    def channel(match):
        found = named.get(match.group(1))
        if not found:
            return match.group(0)
        if str(found["id"]).startswith("<"):
            return "#" + found["name"]
        return f"<#{found['id']}>"

    def role(match):
        found = roles.get(match.group(1), {}).get("id")
        return f"<@&{found}>" if found else "@" + match.group(1)

    def fill(value):
        if isinstance(value, str):
            return re.sub(r"\{@([^}]+)\}", role, re.sub(r"\{#([\w-]+)\}", channel, value))
        if isinstance(value, list):
            return [fill(item) for item in value]
        if isinstance(value, dict):
            return {key: fill(item) for key, item in value.items()}
        return value

    ready = POSTS / "ready"
    ready.mkdir(exist_ok=True)
    for template in sorted(POSTS.glob("*.json")):
        post = json.loads(template.read_text(encoding="utf-8"))
        where = named.get(post["channel"], {}).get("name", post["channel"])
        lines = [f"{where}: send with this channel's Iruka-sensei webhook, the messages in this order.", ""]
        url = addresses.get(named.get(post["channel"], {}).get("id"))
        if url:
            lines += ["Webhook (SECRET, for Discohook only):", url, ""]
        for number, item in enumerate(post["messages"], 1):
            if "banner" in item:
                lines += [f"{number}. A message with no text: attach the file "
                          f"assets/discord/banners/{item['banner']}.png", ""]
            else:
                lines += [f"{number}. A message: open its JSON editor and paste:", "",
                          json.dumps(fill(item), ensure_ascii=False, indent=2), ""]
        (ready / f"{template.stem}.txt").write_text("\n".join(lines), encoding="utf-8")
        print(f"  {template.stem}: ready")


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--dry", action="store_true", help="say what would be done, change nothing")
    parser.add_argument("--guild", default=GUILD, help="the server's id")
    parser.add_argument("--clipboard", action="store_true", help="take the token from the clipboard")
    parser.add_argument("--webhooks", action="store_true", help="make Iruka's webhooks, addresses into a local file")
    parser.add_argument("--new-webhooks", action="store_true", help="delete Iruka's webhooks and make new ones")
    parser.add_argument("--posts", action="store_true", help="fill the Discohook posts with the server's ids")
    args = parser.parse_args()

    if args.clipboard:
        token = clean(clipboard())
    else:
        token = clean(os.environ.get("DISCORD_TOKEN") or getpass.getpass("Bot token (not shown): "))
    if not looks_like_token(token):
        sys.exit(
            "That is not a bot token (it should be three parts joined by dots, about 70 characters).\n"
            "Copy it in the Developer Portal (Bot > Reset Token > Copy) and run:\n"
            "    python scripts/discord-setup.py --dry --clipboard"
        )
    print(f"Token read: {len(token)} characters")
    api = Discord(token, args.dry)
    gid = args.guild

    guild = api.get(f"/guilds/{gid}")
    print(f"Server: {guild['name']}")
    me = api.get("/users/@me")
    member = api.get(f"/guilds/{gid}/members/{me['id']}")
    all_roles = api.get(f"/guilds/{gid}/roles")
    roles = {role["name"]: role for role in all_roles}
    by_id = {role["id"]: role for role in all_roles}
    mine = [by_id[r] for r in member["roles"] if r in by_id]
    top = max((role["position"] for role in mine), default=0)

    # Safety, and Discord's own join messages off.
    print("Safety settings")
    api.call("PATCH", f"/guilds/{gid}", {
        "verification_level": 2,
        "explicit_content_filter": 2,
        "default_message_notifications": 1,
        "system_channel_flags": SYSTEM_FLAGS,
    })

    # Roles.
    print("Roles")
    for name, color, hoist, perms in ROLES:
        if name in roles:
            continue
        made = api.call("POST", f"/guilds/{gid}/roles", {
            "name": name, "color": color, "hoist": hoist, "mentionable": False,
            "permissions": str(perms),
        })
        print(f"  {name}: made")
        if made:
            roles[name] = made
            all_roles.append(made)
    # A new role comes in at the foot and lifts every other one a step, this bot's too: the
    # positions read before are stale, so they are read again.
    if not args.dry:
        all_roles = api.get(f"/guilds/{gid}/roles")
        roles = {role["name"]: role for role in all_roles}
        by_id = {role["id"]: role for role in all_roles}
        mine = [by_id[r] for r in member["roles"] if r in by_id]
        top = max((role["position"] for role in mine), default=0)
    ours = [roles[name] for name, *_ in ROLES if name in roles and "id" in roles[name]]
    if ours and not args.dry:
        # Top to bottom under this bot's role: the other bots' roles (so that Bloxlink and the
        # leveling bot stand above the roles they give), ours, then whatever else there is.
        ours_ids = {role["id"] for role in ours}
        mine_ids = {role["id"] for role in mine}
        rest = sorted(
            (role for role in all_roles
             if role["id"] not in ours_ids and role["id"] not in mine_ids and role["id"] != gid
             and role.get("position", 0) < top),
            key=lambda role: -role.get("position", 0),
        )
        bots = [role for role in rest if role.get("managed") and "premium_subscriber" not in (role.get("tags") or {})]
        boosters = [role for role in rest if "premium_subscriber" in (role.get("tags") or {})]
        others = [role for role in rest if role not in bots and role not in boosters]
        # The boosters' role (Discord's own) stands after the special roles.
        cut = len(STAFF_ROLES) + len(SPECIAL_ROLES)
        order = bots + ours[:cut] + boosters + ours[cut:] + others
        if top <= len(order):
            above = [role["name"] for role in sorted(all_roles, key=lambda role: -role.get("position", 0))
                     if role.get("position", 0) > top]
            print("  ! The bot's role is not at the top: drag it above every other role in")
            print("    Server Settings > Roles and run again to put the roles in order.")
            if above:
                print(f"    Above it now: {', '.join(above)}")
        else:
            positions = [{"id": role["id"], "position": top - 1 - i} for i, role in enumerate(order)]
            try:
                api.call("PATCH", f"/guilds/{gid}/roles", positions)
                print("  put in order")
            except RuntimeError as error:
                print(f"  not put in order ({error}); is the bot's role at the very top?")

    def role_id(name):
        return roles.get(name, {}).get("id")

    staff = role_id("Staff")
    tester = role_id("Tester")
    everyone = gid

    def overwrite(rid, allow=0, deny=0):
        return {"id": rid, "type": 0, "allow": str(allow), "deny": str(deny)}

    read_only = [overwrite(everyone, deny=SEND | PUBLIC_THREADS | PRIVATE_THREADS | SEND_IN_THREADS)]
    if staff:
        read_only.append(overwrite(staff, allow=SEND | MENTION_ALL))
    hidden = [overwrite(everyone, deny=VIEW | CONNECT)]
    if staff:
        hidden.append(overwrite(staff, allow=VIEW | SEND | CONNECT))
    testing = list(hidden)
    if tester:
        testing.append(overwrite(tester, allow=VIEW | SEND))
    # Read by everyone, written in by content creators and the staff.
    creators_only = list(read_only)
    if role_id("Content Creator"):
        creators_only.append(overwrite(role_id("Content Creator"), allow=SEND))

    def language_only(role_name):
        perms = [overwrite(everyone, deny=VIEW)]
        rid = role_id(role_name)
        if rid:
            perms.append(overwrite(rid, allow=VIEW))
        if staff:
            perms.append(overwrite(staff, allow=VIEW))
        return perms

    channels = api.get(f"/guilds/{gid}/channels")
    placed = []  # every channel of ours, in the order it is to stand

    def find(names, kinds):
        for name in names:
            for channel in channels:
                if channel["name"] == name and channel["type"] in kinds:
                    return channel
        return None

    def ensure(name, kind, parent=None, aliases=(), topic=None, slow=0, perms=None, tags=None,
               fallback=None, limit=None):
        kinds = {kind} | ({fallback} if fallback is not None else set())
        found = find([name, *aliases], kinds)
        if found:
            change = {}
            if found["name"] != name:
                change["name"] = name
            if parent and found.get("parent_id") != parent:
                change["parent_id"] = parent
            if topic and kind != VOICE and not found.get("topic"):
                change["topic"] = topic
            if limit is not None and found.get("user_limit", 0) != limit:
                change["user_limit"] = limit
            if change and not str(found["id"]).startswith("<"):
                api.call("PATCH", f"/channels/{found['id']}", change)
                said = ", ".join(f"{key} {value}" for key, value in change.items() if key != "parent_id")
                print(f"  {found['name']}: {said or 'moved'}")
            if perms and not args.dry and not str(found["id"]).startswith("<"):
                for item in perms:
                    api.call("PUT", f"/channels/{found['id']}/permissions/{item['id']}", {
                        "type": 0, "allow": item["allow"], "deny": item["deny"],
                    })
            found["name"] = name
            placed.append(found)
            return found
        body = {"name": name, "type": kind}
        if parent:
            body["parent_id"] = parent
        if topic:
            body["topic"] = topic
        if slow:
            body["rate_limit_per_user"] = slow
        if perms:
            body["permission_overwrites"] = perms
        if tags:
            body["available_tags"] = [{"name": tag} for tag in tags]
        if limit:
            body["user_limit"] = limit
        try:
            made = api.call("POST", f"/guilds/{gid}/channels", body)
        except RuntimeError as error:
            if fallback is None:
                raise
            print(f"  {name}: could not be made as type {kind} ({error}); made as a text channel")
            body["type"] = fallback
            body.pop("available_tags", None)
            made = api.call("POST", f"/guilds/{gid}/channels", body)
        print(f"  {name}: made")
        made = made or {"id": f"<{name}>", "name": name, "type": kind}
        channels.append(made)
        placed.append(made)
        return made

    print("Channels")
    start = ensure("🍃 ACADEMY GATE", CATEGORY, aliases=["📌 START"])
    rules = ensure("📜・rules", TEXT, start["id"], ["rules"], "The village rules. Read before you post.", perms=read_only)
    welcome = ensure("👋・welcome", TEXT, start["id"], topic="What this server is and how to find your way.",
                     perms=read_only)
    verify = ensure("🔗・verify", TEXT, start["id"],
                    topic="Link your Roblox account (Bloxlink) for your game roles: VIP, legends, ranks. Optional.",
                    perms=read_only)

    office = ensure("📜 HOKAGE'S OFFICE", CATEGORY)
    staff_area = ensure("🔒 ANBU HQ", CATEGORY, aliases=["🔒 STAFF"], perms=hidden)
    mod_updates = ensure("📋・mod-updates", TEXT, staff_area["id"], ["mod-updates"], perms=hidden)

    # Community, which announcement channels, onboarding and the welcome screen need.
    features = guild.get("features", [])
    if "COMMUNITY" not in features:
        print("Community: switching on")
        try:
            api.call("PATCH", f"/guilds/{gid}", {
                "features": features + ["COMMUNITY"],
                "verification_level": 2,
                "explicit_content_filter": 2,
                "rules_channel_id": rules["id"],
                "public_updates_channel_id": mod_updates["id"],
                "preferred_locale": "en-US",
            })
        except RuntimeError as error:
            print(f"  not switched on ({error})")
            print("  Switch it on by hand (Server Settings > Enable Community, with #rules and")
            print("  #mod-updates) and run the script again: the announcement channels need it.")

    def news(name, aliases, topic):
        return ensure(name, ANNOUNCEMENT, office["id"], aliases, topic, perms=read_only, fallback=TEXT)

    announcements = news("📢・announcements", ["announcements"], "News about the game and the server.")
    updates = news("🛠・updates", ["updates"], "What's new in every update.")
    codes = news("🎁・codes", ["codes"], "Codes for the game: Settings > Codes in the game.")
    events = news("🌕・events", [], "The game's events: Leaf Festival, Akatsuki Raid, Crimson Moon.")
    sneak = news("👀・sneak-peeks", [], "A look at what is coming.")

    village = ensure("🏮 HIDDEN LEAF", CATEGORY, aliases=["💬 COMMUNITY"])
    general = ensure("💬・general", TEXT, village["id"], ["general"], "Chat in English. Show off your catches here too.",
                     slow=3)
    discussion = ensure("🎮・game-discussion", TEXT, village["id"], topic="Talk about the game: builds, zones, mutations.",
                        slow=5)
    help_channel = ensure("❓・help", TEXT, village["id"], ["help"], "Questions about the game.", slow=5)
    qotd = ensure("❔・qotd", TEXT, village["id"], topic="The question of the day. Answer below!", slow=30)
    memes = ensure("😂・memes", TEXT, village["id"], topic="Naruto and game memes. Keep it friendly.", slow=10)
    creations = ensure("🎬・creations", TEXT, village["id"],
                       topic="Your videos, edits and screenshots of the game.", slow=30)
    promotion = ensure("📣・creator-promotion", TEXT, village["id"],
                       topic="Content creators share their videos about the game here.", perms=creators_only)

    nations = ensure("🌐 FIVE NATIONS", CATEGORY)
    language_channels = {}
    for role_name, channel_name, aliases, _, _, topic, _ in LANGUAGES:
        language_channels[role_name] = ensure(channel_name, TEXT, nations["id"], aliases, topic, slow=3,
                                              perms=language_only(role_name))

    desk = ensure("🛠 MISSION DESK", CATEGORY)
    suggestions = ensure("💡・suggestions", FORUM, desk["id"], ["suggestions"], SUGGEST_GUIDE,
                         tags=["UI", "Balance", "New shinobi", "Events", "Other"], fallback=TEXT)
    bugs = ensure("🐛・bug-reports", FORUM, desk["id"], ["bug-reports"], BUG_GUIDE,
                  tags=["Open", "Fixed", "Can't reproduce"], fallback=TEXT)
    tickets = ensure("🎫・create-ticket", TEXT, desk["id"],
                     topic="Something wrong with a purchase or your progress? Open a ticket.", perms=read_only)

    voice = ensure("🔊 TRAINING GROUNDS", CATEGORY, aliases=["🔊 VOICE"])
    for name, aliases, limit in VOICE_ROOMS:
        ensure(name, VOICE, voice["id"], aliases, limit=limit)
    afk = ensure(AFK_ROOM, VOICE, voice["id"])

    # The staff's own, last.
    placed.remove(staff_area)
    placed.append(staff_area)
    placed.remove(mod_updates)
    placed.append(mod_updates)
    ensure("🔒・staff", TEXT, staff_area["id"], ["staff"], perms=hidden)
    mod_log = ensure("🗂・mod-log", TEXT, staff_area["id"], topic="AutoMod's alerts.", perms=hidden)
    ensure("🧪・testing", TEXT, staff_area["id"], ["testing"], perms=testing)
    ensure("🎙 ANBU Briefing", VOICE, staff_area["id"], perms=hidden)

    # #catches is gone (owner: "let them do it in general"): taken away if nothing was written
    # in it, else left for the owner to decide.
    catches = find(["catches"], {TEXT})
    if catches:
        history = api.get(f"/channels/{catches['id']}/messages?limit=1")
        if history:
            print("  #catches has messages: delete it by hand if it is not wanted")
        else:
            api.call("DELETE", f"/channels/{catches['id']}")
            print("  #catches: empty, taken away")

    # The order: categories in turn, each with its channels.
    if not args.dry:
        order = []
        for position, channel in enumerate(placed):
            if not str(channel["id"]).startswith("<"):
                order.append({"id": channel["id"], "position": position})
        try:
            api.call("PATCH", f"/guilds/{gid}/channels", order)
            print("  put in order")
        except RuntimeError as error:
            print(f"  not put in order ({error}); drag them by hand")

    # The AFK room: who sits silent in voice for 15 minutes is moved there.
    try:
        api.call("PATCH", f"/guilds/{gid}", {"afk_channel_id": afk["id"], "afk_timeout": 900})
    except RuntimeError as error:
        print(f"  AFK room not set ({error})")
    try:
        api.call("PATCH", f"/guilds/{gid}", {
            "description": "Throw kunai, catch shinobi, build your dojo. The official community of "
                           "Shinobi: Collect It All! on Roblox.",
        })
    except RuntimeError as error:
        print(f"  description not set ({error})")

    # AutoMod.
    print("AutoMod")
    existing = api.get(f"/guilds/{gid}/auto-moderation/rules") or []
    kinds = {rule["trigger_type"] for rule in existing}
    names = {rule["name"] for rule in existing}
    exempt = [staff] if staff else []
    actions = [{"type": 1}]
    if mod_log and not str(mod_log["id"]).startswith("<"):
        actions.append({"type": 2, "metadata": {"channel_id": mod_log["id"]}})
    automod = [
        (4, "Bad words", {"presets": [1, 2, 3]}),
        (5, "Mention spam", {"mention_total_limit": 5, "mention_raid_protection_enabled": True}),
        (3, "Spam", {}),
        (1, "Scam links", {"keyword_filter": [
            "*free robux*", "*robux generator*", "*free-robux*", "discord.gg/*", "*discord.com/invite*",
        ]}),
    ]
    for trigger, name, metadata in automod:
        if name in names or (trigger in (3, 4, 5) and trigger in kinds):
            continue
        try:
            api.call("POST", f"/guilds/{gid}/auto-moderation/rules", {
                "name": name, "event_type": 1, "trigger_type": trigger,
                "trigger_metadata": metadata, "actions": actions, "enabled": True,
                "exempt_roles": exempt,
            })
            print(f"  {name}: made")
        except RuntimeError as error:
            print(f"  {name}: not made ({error}); set it by hand, docs/discord.md part 1")
    # The rules made before tell the staff's log too.
    for rule in existing:
        if len(actions) > 1 and not any(action["type"] == 2 for action in rule.get("actions", [])):
            try:
                api.call("PATCH", f"/guilds/{gid}/auto-moderation/rules/{rule['id']}",
                         {"actions": rule.get("actions", []) + actions[1:]})
                print(f"  {rule['name']}: alerts go to the log")
            except RuntimeError as error:
                print(f"  {rule['name']}: alerts not added ({error})")

    # Welcome screen and onboarding: best done, else by hand.
    print("Welcome screen")
    try:
        api.call("PATCH", f"/guilds/{gid}/welcome-screen", {
            "enabled": True,
            "description": "The official community of Shinobi: Collect It All! on Roblox.",
            "welcome_channels": [
                {"channel_id": rules["id"], "description": "Read the village rules", "emoji_name": "📜"},
                {"channel_id": codes["id"], "description": "Free rewards for the game", "emoji_name": "🎁"},
                {"channel_id": general["id"], "description": "Chat with other shinobi", "emoji_name": "💬"},
                {"channel_id": help_channel["id"], "description": "Questions about the game", "emoji_name": "❓"},
                {"channel_id": bugs["id"], "description": "Report a bug", "emoji_name": "🐛"},
            ],
        })
        print("  set")
    except RuntimeError as error:
        print(f"  not set ({error}); set it by hand, docs/discord.md part 5")

    print("Onboarding")

    # Discord wants an id on every prompt and option: the ones there are kept (by title), so
    # that what members picked before stays theirs; new ones get new ids.
    known = {}
    try:
        for prompt in (api.get(f"/guilds/{gid}/onboarding") or {}).get("prompts", []):
            known[prompt["title"]] = prompt["id"]
            for choice in prompt.get("options", []):
                known[(prompt["title"], choice["title"])] = choice["id"]
    except RuntimeError:
        pass

    def option(title, emoji, role=None, channel=None, prompt=""):
        rid = role_id(role) if role else None
        return {"id": known.get((prompt, title)) or snowflake(), "title": title, "emoji_name": emoji,
                "role_ids": [rid] if rid else [], "channel_ids": [channel["id"]] if channel else []}

    language_title = "Which language do you speak?"
    ping_title = "What do you want to be pinged for?"

    try:
        api.call("PUT", f"/guilds/{gid}/onboarding", {
            "enabled": True,
            "mode": 0,
            "default_channel_ids": [c["id"] for c in (
                rules, welcome, verify, announcements, updates, codes, events, sneak, general, discussion,
                help_channel, qotd, memes, creations, promotion, suggestions, bugs, tickets,
            )],
            "prompts": [
                {
                    "id": known.get(language_title) or snowflake(),
                    "type": 0, "title": language_title, "single_select": True,
                    "required": False, "in_onboarding": True,
                    "options": [option("English", "🇬🇧", channel=general, prompt=language_title)] + [
                        option(title, flag, role=role, prompt=language_title)
                        for role, _, _, flag, title, _, _ in LANGUAGES
                    ],
                },
                {
                    "id": known.get(ping_title) or snowflake(),
                    "type": 0, "title": ping_title, "single_select": False,
                    "required": False, "in_onboarding": True,
                    "options": [
                        option("New codes", "🎁", "Codes Ping", codes, ping_title),
                        option("Game updates", "🛠️", "Updates Ping", updates, ping_title),
                        option("Events", "🌕", "Events Ping", events, ping_title),
                        option("Giveaways", "🎉", "Giveaways Ping", prompt=ping_title),
                        option("Question of the day", "❔", "QOTD Ping", qotd, ping_title),
                        option("Sneak peeks", "👀", "Sneak Peeks Ping", sneak, ping_title),
                    ],
                },
            ],
        })
        print("  set")
    except RuntimeError as error:
        print(f"  not set ({error}); set it by hand, docs/discord.md part 5")

    # Emoji and stickers that are not there yet.
    print("Emoji")
    have = {emoji["name"] for emoji in (api.get(f"/guilds/{gid}/emojis") or [])}
    for path in sorted((ASSETS / "emoji").glob("*.png")):
        if path.stem in have:
            continue
        try:
            api.call("POST", f"/guilds/{gid}/emojis", {"name": path.stem, "image": data_uri(path), "roles": []})
            print(f"  :{path.stem}: added")
        except RuntimeError as error:
            print(f"  :{path.stem}: not added ({error})")
            if "30008" in str(error):  # the server has no room for more
                break
    print("Stickers")
    have = {sticker["name"] for sticker in (api.get(f"/guilds/{gid}/stickers") or [])}
    for file, name, tag in STICKERS:
        path = ASSETS / "stickers" / f"{file}.png"
        if name in have or not path.exists():
            continue
        try:
            api.form(f"/guilds/{gid}/stickers", {"name": name, "description": "", "tags": tag}, "file", path)
            print(f"  {name}: added")
        except RuntimeError as error:
            print(f"  {name}: not added ({error})")
            if "30039" in str(error):  # no room for more
                break

    # Iruka's webhooks, for Discohook. Their addresses go into a local file only.
    addresses = {}
    if args.webhooks or args.new_webhooks:
        print("Iruka's webhooks")
        avatar = ASSETS / "iruka_avatar.png"
        targets = [rules, welcome, announcements, updates, codes, events, sneak, tickets] + list(
            language_channels.values()
        )
        for channel in targets:
            if str(channel["id"]).startswith("<"):
                continue
            hooks = [h for h in (api.get(f"/channels/{channel['id']}/webhooks") or []) if h.get("name") == WEBHOOK_NAME]
            if args.new_webhooks:
                for old in hooks:
                    api.call("DELETE", f"/webhooks/{old['id']}")
                hooks = []
            hook = next((h for h in hooks if h.get("token")), None)
            if not hook:
                body = {"name": WEBHOOK_NAME}
                if avatar.exists():
                    body["avatar"] = data_uri(avatar)
                hook = api.call("POST", f"/channels/{channel['id']}/webhooks", body)
                print(f"  {channel['name']}: made" + (" anew" if args.new_webhooks else ""))
            if hook:
                addresses[channel["id"]] = f"https://discord.com/api/webhooks/{hook['id']}/{hook['token']}"
        if addresses:
            ready = POSTS / "ready"
            ready.mkdir(parents=True, exist_ok=True)
            by_id = {channel["id"]: channel["name"] for channel in targets}
            lines = ["SECRET. Whoever has one of these addresses can post in its channel as Iruka.",
                     "Paste them into Discohook only, never into a chat. If one gets out:",
                     "    python scripts/discord-setup.py --clipboard --new-webhooks", ""]
            lines += [f"{by_id[cid]}: {url}" for cid, url in addresses.items()]
            (ready / "webhooks.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
            print(f"  {len(addresses)} addresses written to docs/discord-posts/ready/webhooks.txt (secret)")

    # The posts, filled with this server's channels and roles.
    if args.posts:
        named = {
            "rules": rules, "welcome": welcome, "verify": verify, "announcements": announcements,
            "updates": updates, "codes": codes, "events": events, "sneak": sneak, "general": general,
            "discussion": discussion, "help": help_channel, "qotd": qotd, "memes": memes,
            "creations": creations, "promotion": promotion,
            "suggestions": suggestions, "bugs": bugs, "tickets": tickets,
        }
        for role_name, *_, key in LANGUAGES:
            named[key] = language_channels[role_name]
        write_posts(named, roles, addresses)

    # A permanent invite.
    if not args.dry:
        invite = api.call("POST", f"/channels/{rules['id']}/invites", {"max_age": 0, "max_uses": 0, "unique": False})
        if invite:
            print(f"\nInvite: https://discord.gg/{invite['code']}")
    print("\nDone. What is left by hand is in docs/discord.md: the bots (Bloxlink, Ticket Tool, Lurkr)")
    print("and the roles given by hand.")


if __name__ == "__main__":
    main()
