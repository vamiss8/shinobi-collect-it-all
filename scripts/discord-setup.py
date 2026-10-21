"""Sets up the game's Discord server as docs/discord.md describes it, through a bot.

    python scripts/discord-setup.py --dry      # says what it would do, changes nothing
    python scripts/discord-setup.py            # does it

The bot's token is taken from the clipboard (--clipboard: copy it in the Developer Portal, then
run the script), from the environment variable DISCORD_TOKEN, or asked for in the terminal (not
shown as it is typed; pasting into a hidden prompt does not always work in a Windows terminal,
which is what --clipboard is for). It is never written anywhere. The bot must be on the server
with the Administrator permission, and its role dragged to the top of the server's roles.

What it does, all of it safe to run again (what is already there is left as it is):
  - the server's safety: verification Medium, media scanned for everyone, notifications only
    for mentions;
  - the roles, in the colors of the game's marks;
  - the categories and channels with their permissions and slow modes;
  - Community switched on, with #rules and #mod-updates (this accepts Discord's community
    guidelines for the server);
  - AutoMod: the three word lists, mention spam, spam, and a list against scam links;
  - the welcome screen and onboarding (who asks to be pinged for codes and updates, which
    language);
  - the first messages: the rules in English and Russian, the welcome announcement, the first
    code;
  - a permanent invite, printed at the end.

What it cannot do: give people their roles (Founder, Developer, Designer, White Reaper are given
by hand, right-click a member > Roles).
"""

import argparse
import getpass
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://discord.com/api/v10"
GUILD = "1562078615405990060"
AGENT = "DiscordBot (https://github.com/vamiss8/shinobi-collect-it-all, 1.0)"

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

# Channel types.
TEXT, VOICE, CATEGORY, ANNOUNCEMENT, FORUM = 0, 2, 4, 5, 15

# Roles, top to bottom: name, color, shown apart in the member list, permissions.
ROLES = [
    ("Founder", 0x9D5CFF, True, ADMIN),
    ("Developer", 0xFF3B30, True, MANAGE_MESSAGES | MANAGE_THREADS | KICK | TIMEOUT | MENTION_ALL),
    ("Designer", 0xFF6FB5, True, 0),
    ("Moderator", 0x4FC3F7, True, MANAGE_MESSAGES | MANAGE_THREADS | TIMEOUT),
    ("White Reaper", 0xFFFFFF, True, 0),
    ("Tester", 0x81C784, True, 0),
    ("Staff", 0, False, MENTION_ALL),
    ("Codes Ping", 0, False, 0),
    ("Updates Ping", 0, False, 0),
]

RULES_EN = """\U0001F4DC **RULES**

1. Be kind. No insults, harassment, hate speech or discrimination.
2. No spam, flooding or self-promotion. No links to other servers.
3. No scams: no "free Robux", account trading or selling.
4. Keep it safe: no NSFW, no personal info (yours or anyone's).
5. Use the right channels: bugs in #bug-reports, ideas in #suggestions.
6. English in #general, Russian in #general-ru.
7. Exploiting or sharing exploits in the game = ban here and in the game.
8. Follow Discord's Terms of Service and Roblox's Community Standards.

Staff decisions are final. Breaking the rules: warning → timeout → ban."""

RULES_RU = """\U0001F4DC **ПРАВИЛА**

1. Уважайте друг друга. Без оскорблений, травли и дискриминации.
2. Без спама, флуда и рекламы. Без ссылок на другие серверы.
3. Без скама: никакого «бесплатного Robux», продажи и обмена аккаунтов.
4. Без NSFW и личных данных (своих и чужих).
5. Пишите по адресу: баги в #bug-reports, идеи в #suggestions.
6. Английский в #general, русский в #general-ru.
7. Читы в игре и их распространение = бан здесь и в игре.
8. Соблюдайте правила Discord и Roblox.

Решение модераторов окончательное. Нарушение: предупреждение → таймаут → бан."""

WELCOME = """\U0001F343 Welcome to the official community of **Shinobi: Collect It All!**

Train your Chakra, throw your kunai down the lane, catch shinobi and outrun their enemies, fill your dojo and collect them all.

\U0001F381 Every new code is posted in #codes: pick the **Codes Ping** role to never miss one.
\U0001F41E Found a bug? #bug-reports. \U0001F4A1 Have an idea? #suggestions.

See you in the village!"""

CODE_POST = """\U0001F381 **NEW CODE: HIDDENLEAF**

200 Herbs + 15 minutes of your dojo's income + a premium Ichiraku Ramen (x2 Ryo, 15 min).

In the game: ⚙️ Settings → Codes → type the code → Redeem.
One use per player. {ping}"""

BUG_GUIDE = """Please write:
- What happened, and what you expected
- Where (which zone / menu) and what you pressed
- Device: PC / phone / tablet / console
- A screenshot or video, if you can"""

SUGGEST_GUIDE = "One idea per post. Say what you would change and why. Pick a tag."


def hint(code: int, text: str) -> str:
    """What an error most likely means, for whoever runs this."""
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


class Discord:
    def __init__(self, token: str, dry: bool):
        self.token = token
        self.dry = dry

    def call(self, method: str, path: str, body=None, write: bool = True):
        if self.dry and write:
            print(f"  [dry] {method} {path}")
            return None
        data = json.dumps(body).encode() if body is not None else None
        while True:
            request = urllib.request.Request(API + path, data=data, method=method)
            request.add_header("Authorization", f"Bot {self.token}")
            request.add_header("User-Agent", AGENT)
            if data is not None:
                request.add_header("Content-Type", "application/json")
            try:
                with urllib.request.urlopen(request) as response:
                    text = response.read().decode()
                    return json.loads(text) if text else None
            except urllib.error.HTTPError as error:
                text = error.read().decode()
                if error.code == 429:
                    wait = json.loads(text).get("retry_after", 1)
                    time.sleep(float(wait) + 0.1)
                    continue
                raise RuntimeError(f"{method} {path}: {error.code} {text}{hint(error.code, text)}") from None

    def get(self, path: str):
        return self.call("GET", path, write=False)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--dry", action="store_true", help="say what would be done, change nothing")
    parser.add_argument("--guild", default=GUILD, help="the server's id")
    parser.add_argument("--clipboard", action="store_true", help="take the token from the clipboard")
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
    roles = {role["name"]: role for role in api.get(f"/guilds/{gid}/roles")}
    by_id = {role["id"]: role for role in roles.values()}
    top = max((by_id[r]["position"] for r in member["roles"] if r in by_id), default=0)

    # Safety.
    print("Safety settings")
    api.call("PATCH", f"/guilds/{gid}", {
        "verification_level": 2,
        "explicit_content_filter": 2,
        "default_message_notifications": 1,
    })

    # Roles.
    print("Roles")
    for name, color, hoist, perms in ROLES:
        if name in roles:
            print(f"  {name}: already there")
            continue
        made = api.call("POST", f"/guilds/{gid}/roles", {
            "name": name, "color": color, "hoist": hoist, "mentionable": False,
            "permissions": str(perms),
        })
        print(f"  {name}: made")
        if made:
            roles[name] = made
    ours = [roles[name] for name, *_ in ROLES if name in roles and "id" in roles[name]]
    if ours and not args.dry:
        if top <= len(ours):
            print("  ! The bot's role is not above the new roles: drag it to the top of")
            print("    Server Settings > Roles and run again to put the roles in order.")
        else:
            positions = [{"id": role["id"], "position": len(ours) - i} for i, role in enumerate(ours)]
            api.call("PATCH", f"/guilds/{gid}/roles", positions)
            print("  put in order")

    staff = roles.get("Staff", {}).get("id")
    tester = roles.get("Tester", {}).get("id")
    codes_ping = roles.get("Codes Ping", {}).get("id")
    updates_ping = roles.get("Updates Ping", {}).get("id")
    everyone = gid

    def overwrite(role_id, allow=0, deny=0):
        return {"id": role_id, "type": 0, "allow": str(allow), "deny": str(deny)}

    read_only = [overwrite(everyone, deny=SEND | PUBLIC_THREADS | PRIVATE_THREADS | SEND_IN_THREADS)]
    if staff:
        read_only.append(overwrite(staff, allow=SEND | MENTION_ALL))
    hidden = [overwrite(everyone, deny=VIEW)]
    if staff:
        hidden.append(overwrite(staff, allow=VIEW | SEND))
    testing = list(hidden)
    if tester:
        testing.append(overwrite(tester, allow=VIEW | SEND))

    channels = api.get(f"/guilds/{gid}/channels")

    def find(name, kinds):
        for channel in channels:
            if channel["name"] == name and channel["type"] in kinds:
                return channel
        return None

    def ensure(name, kind, parent=None, topic=None, slow=0, perms=None, tags=None, fallback=None):
        found = find(name, {kind} | ({fallback} if fallback is not None else set()))
        if found:
            print(f"  #{name}: already there")
            if perms and not args.dry:
                for item in perms:
                    api.call("PUT", f"/channels/{found['id']}/permissions/{item['id']}", {
                        "type": 0, "allow": item["allow"], "deny": item["deny"],
                    })
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
        try:
            made = api.call("POST", f"/guilds/{gid}/channels", body)
        except RuntimeError as error:
            if fallback is None:
                raise
            print(f"  #{name}: could not be made as type {kind} ({error}); made as a text channel")
            body["type"] = fallback
            body.pop("available_tags", None)
            made = api.call("POST", f"/guilds/{gid}/channels", body)
        print(f"  #{name}: made")
        if made:
            channels.append(made)
        return made or {"id": f"<{name}>", "name": name}

    print("Channels")
    start = ensure("📌 START", CATEGORY)
    staff_area = ensure("🔒 STAFF", CATEGORY, perms=hidden)
    rules = ensure("rules", TEXT, start["id"], "Read before you post.", perms=read_only)
    mod_updates = ensure("mod-updates", TEXT, staff_area["id"], perms=hidden)
    ensure("staff", TEXT, staff_area["id"], perms=hidden)
    ensure("testing", TEXT, staff_area["id"], perms=testing)

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
    else:
        print("Community: already on")

    announcements = ensure("announcements", ANNOUNCEMENT, start["id"], "News about the game.",
                           perms=read_only, fallback=TEXT)
    codes = ensure("codes", ANNOUNCEMENT, start["id"], "Codes for the game: Settings > Codes in the game.",
                   perms=read_only, fallback=TEXT)
    updates = ensure("updates", ANNOUNCEMENT, start["id"], "What's new in the game.",
                     perms=read_only, fallback=TEXT)
    community = ensure("💬 COMMUNITY", CATEGORY)
    general = ensure("general", TEXT, community["id"], "English chat.", slow=5)
    general_ru = ensure("general-ru", TEXT, community["id"], "Общий чат на русском.", slow=5)
    catches = ensure("catches", TEXT, community["id"], "Show off your catches: mutations, stars, Six Paths.", slow=30)
    suggestions = ensure("suggestions", FORUM, community["id"], SUGGEST_GUIDE,
                         tags=["UI", "Balance", "New shinobi", "Events", "Other"], fallback=TEXT)
    bugs = ensure("bug-reports", FORUM, community["id"], BUG_GUIDE,
                  tags=["Open", "Fixed", "Can't reproduce"], fallback=TEXT)
    help_channel = ensure("help", TEXT, community["id"], "Questions about the game.", slow=5)
    voice = ensure("🔊 VOICE", CATEGORY)
    ensure("Lounge", VOICE, voice["id"])

    # AutoMod.
    print("AutoMod")
    existing = api.get(f"/guilds/{gid}/auto-moderation/rules") or []
    kinds = {rule["trigger_type"] for rule in existing}
    names = {rule["name"] for rule in existing}
    exempt = [staff] if staff else []
    block = [{"type": 1}]
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
            print(f"  {name}: already there")
            continue
        try:
            api.call("POST", f"/guilds/{gid}/auto-moderation/rules", {
                "name": name, "event_type": 1, "trigger_type": trigger,
                "trigger_metadata": metadata, "actions": block, "enabled": True,
                "exempt_roles": exempt,
            })
            print(f"  {name}: made")
        except RuntimeError as error:
            print(f"  {name}: not made ({error}); set it by hand, docs/discord.md part 1")

    # Welcome screen and onboarding: best done, else by hand.
    print("Welcome screen")
    try:
        api.call("PATCH", f"/guilds/{gid}/welcome-screen", {
            "enabled": True,
            "description": "Official community of Shinobi: Collect It All! on Roblox.",
            "welcome_channels": [
                {"channel_id": codes["id"], "description": "Codes for the game", "emoji_name": "🎁"},
                {"channel_id": catches["id"], "description": "Show off your catches", "emoji_name": "✨"},
                {"channel_id": bugs["id"], "description": "Report a bug", "emoji_name": "🐞"},
            ],
        })
        print("  set")
    except RuntimeError as error:
        print(f"  not set ({error}); set it by hand, docs/discord.md part 5")

    print("Onboarding")
    try:
        api.call("PUT", f"/guilds/{gid}/onboarding", {
            "enabled": True,
            "mode": 0,
            "default_channel_ids": [c["id"] for c in (
                rules, announcements, codes, updates, general, catches, help_channel, suggestions, bugs,
            )],
            "prompts": [
                {
                    "type": 0, "title": "What do you want to be pinged for?", "single_select": False,
                    "required": False, "in_onboarding": True,
                    "options": [
                        {"title": "New codes", "emoji_name": "🎁", "role_ids": [codes_ping] if codes_ping else [],
                         "channel_ids": [codes["id"]]},
                        {"title": "Game updates", "emoji_name": "📢",
                         "role_ids": [updates_ping] if updates_ping else [], "channel_ids": [updates["id"]]},
                    ],
                },
                {
                    "type": 0, "title": "Which language do you speak?", "single_select": True,
                    "required": False, "in_onboarding": True,
                    "options": [
                        {"title": "English", "emoji_name": "🇬🇧", "role_ids": [], "channel_ids": [general["id"]]},
                        {"title": "Русский", "emoji_name": "🇷🇺", "role_ids": [], "channel_ids": [general_ru["id"]]},
                    ],
                },
            ],
        })
        print("  set")
    except RuntimeError as error:
        print(f"  not set ({error}); set it by hand, docs/discord.md part 5")

    # The first messages, each only into a channel that has none.
    print("First messages")

    def post_once(channel, text, ping_role=None):
        if args.dry:
            print(f"  [dry] message into #{channel['name']}")
            return
        last = api.get(f"/channels/{channel['id']}/messages?limit=1")
        if last:
            print(f"  #{channel['name']}: has messages already, nothing posted")
            return
        for part in text if isinstance(text, list) else [text]:
            api.call("POST", f"/channels/{channel['id']}/messages", {
                "content": part,
                "allowed_mentions": {"parse": [], "roles": [ping_role] if ping_role else []},
            })
        print(f"  #{channel['name']}: posted")

    post_once(rules, [RULES_EN, RULES_RU])
    post_once(announcements, WELCOME)
    post_once(codes, CODE_POST.format(ping=f"<@&{codes_ping}>" if codes_ping else ""), codes_ping)

    # A permanent invite.
    if not args.dry:
        invite = api.call("POST", f"/channels/{rules['id']}/invites", {"max_age": 0, "max_uses": 0, "unique": False})
        if invite:
            print(f"\nInvite: https://discord.gg/{invite['code']}")
    print("\nDone. Give people their roles by hand: right-click a member > Roles.")


if __name__ == "__main__":
    main()
