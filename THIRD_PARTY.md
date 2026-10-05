# Third-party code

## ProfileStore

Session-locked DataStore saving by MAD STUDIO (loleris).

- File: `src/server/Vendor/ProfileStore.luau` (64 654 bytes, unmodified)
- Source: https://github.com/MadStudioRoblox/ProfileStore
- Commit: `45c9847cbcf1fc260369c50eb335aba7c35aecdd`
- SHA-256: `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f`
- License: Apache 2.0, copy in `licenses/ProfileStore-LICENSE.txt`

It is vendored as a single file because it is not published to the Wally registry.
The file is excluded from formatting and linting (`.styluaignore`, `selene.toml`).

To update, pick a newer commit and download the same two files:

```bash
curl -sL https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/<commit>/ProfileStore.luau -o src/server/Vendor/ProfileStore.luau
```

```bash
curl -sL https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/<commit>/LICENSE -o licenses/ProfileStore-LICENSE.txt
```

Then update the commit and checksum above (`sha256sum src/server/Vendor/ProfileStore.luau`).
