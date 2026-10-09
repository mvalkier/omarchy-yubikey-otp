<div align="center">

# 🔐 YubiKey OTP for Omarchy

**Your YubiKey's TOTP codes, one click away in the Omarchy bar.**<br>
Codes only appear after you touch the key, and vanish the moment the panel closes.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Omarchy](https://img.shields.io/badge/Omarchy-plugin-8a2be2.svg)](https://omarchy.org)
[![YubiKey](https://img.shields.io/badge/YubiKey-OATH%20TOTP-84bd00.svg)](https://www.yubico.com/)
[![Python](https://img.shields.io/badge/python-3-3776ab.svg?logo=python&logoColor=white)](scripts/yk-otp)

</div>

---

## ✨ Features

- 👆 **Touch to unlock**: nothing is read from the key until you physically touch it
- ⏱️ **Countdown rings**: each code shows a ring that runs down, turning red in the last five seconds
- 📋 **Click to copy**: a click puts the code on the clipboard, confirmed with a check mark
- 🎨 **Issuer icons**: logos from [aegis-icons](https://github.com/aegis-icons/aegis-icons), built-in brand logos, or a coloured letter tile
- 🔑 **Touch-only accounts**: accounts that need a touch per code work too, right from the list
- 🧹 **Nothing lingers**: closing the panel drops every code from memory
- 🗝️ **Several keys**: with more than one key plugged in, the first one you touch wins

## 🚀 How it works

The bar shows the Yubico logo in the bar's colour.

1. **Click the logo.** The key and the logo (red) blink until you touch the key. A second
   click cancels; after thirty seconds without a touch it stops by itself.
2. **Touch the key.** The panel opens: the key's name and serial number at the top, then one
   row per account. Each row shows the issuer's icon, the issuer and (dimmed) the account
   name, and the code in groups of three (`806 027`) with its countdown ring. The panel
   grows with the number of accounts up to the screen height, and only scrolls after that.
3. **Click a code** to copy it (without the space).

With no key plugged in, the panel opens straight away with **Connect a YubiKey**; plug one
in and it continues at step 1.

Accounts that require a touch for every code show **Click and touch your YubiKey**. Click
the row, the issuer's icon blinks, touch the key, and the code appears. When its ring runs
out, the row goes back to the click text. A missed touch shows **No touch — click again**
in red.

`Escape` or a click outside the panel closes it. Reopening asks for a touch again.

> [!NOTE]
> Not supported: HOTP accounts (they have no period for the ring), accounts whose name
> starts with `_hidden:` (the Yubico Authenticator convention), and an OATH password on
> the key.

## 📦 Installation

### 1. Dependencies

On Arch / Omarchy:

```bash
sudo pacman -S --needed yubikey-manager python-fido2 pcsclite ccid wl-clipboard
sudo systemctl enable --now pcscd.socket
```

| Package | Why |
| --- | --- |
| `yubikey-manager` | provides `ykman` and the Python module `yubikit` |
| `python-fido2` | the touch on opening (FIDO selection) |
| `pcsclite`, `ccid` | the smart card service and driver that reach OATH on the key |
| `wl-clipboard` | copying codes |

### 2. The plugin

```bash
omarchy plugin add https://github.com/mvalkier/omarchy-yubikey-otp.git --enable
```

Update later with:

```bash
omarchy plugin update melkweg.yubikey-otp
```

## 🎨 Icons

Out of the box, a few brands have a built-in logo and every other issuer gets a coloured
tile with its first letter. For real logos for over a thousand services, install the
free [aegis-icons](https://github.com/aegis-icons/aegis-icons) pack. It is the same icon
pack format that Yubico Authenticator reads.

### Install the aegis-icons pack

**1. Create the pack directory.** The plugin looks for packs in
`~/.local/share/yubikey-otp/icons/`, one directory per pack:

```bash
mkdir -p ~/.local/share/yubikey-otp/icons/aegis-icons
cd ~/.local/share/yubikey-otp/icons/aegis-icons
```

**2. Download the latest release:**

```bash
curl -sLO https://github.com/aegis-icons/aegis-icons/releases/latest/download/aegis-icons.zip
```

**3. Unpack it and remove the zip:**

```bash
unzip -o aegis-icons.zip && rm aegis-icons.zip
```

**4. Check the result.** There should be a `pack.json` next to an `icons/` directory:

```bash
ls ~/.local/share/yubikey-otp/icons/aegis-icons
# icons  pack.json
```

That's it. Open the panel and touch your key: packs are read on every unlock, so no
restart is needed. Nothing is fetched from the internet at runtime.

**Updating** the pack later is the same three commands: step 1 to 3 again.

### How an issuer finds its icon

For each account, the plugin tries in this order:

1. 📁 **An icon pack.** The exact issuer name first; failing that, the longest pack name
   contained in the issuer ("Microsoft Azure" finds "Microsoft"). Names shorter than four
   characters are only matched exactly.
2. 🏷️ **A built-in brand logo** from `Providers.js`, on a rounded tile.
3. 🔤 **A coloured tile** with the issuer's first letter.

<details>
<summary><b>Making your own pack</b></summary>

<br>

A pack is a directory under `~/.local/share/yubikey-otp/icons/` with a `pack.json` in the
Aegis format. Only the `icons` list is used:

```json
{
  "icons": [
    { "filename": "icons/example.svg", "issuer": ["Example", "Example Inc"] }
  ]
}
```

`filename` is relative to the pack directory and must stay inside it. Supported formats
are SVG, PNG and JPEG. When several packs know the same issuer, the first pack in
alphabetical order wins.

</details>

## 🛠️ Development

From a working tree, to hack on the plugin:

```bash
./install --restart
omarchy plugin enable melkweg.yubikey-otp --section right
```

`install` copies the working tree to `~/.config/omarchy/plugins/melkweg.yubikey-otp` and
runs `omarchy plugin validate`. It copies rather than symlinks, because validation rejects
any symlink in a plugin directory. If the plugin directory is a checkout made by
`omarchy plugin add`, `install` refuses unless given `--force`.

`--restart` restarts the shell: imported JS (`Providers.js`) and components such as
`ProviderIcon.qml` stay cached until then.

Control without clicking:

```bash
omarchy-shell shell summon melkweg.yubikey-otp '{}'   # make the key blink
omarchy-shell shell hide melkweg.yubikey-otp          # cancel or close
```

<details>
<summary><b>Files</b></summary>

<br>

| File | Role |
| --- | --- |
| `BarWidget.qml` | The logo in the bar; forwards clicks and IPC to the panel and blinks while the key waits for a touch. |
| `Panel.qml` | State, processes and rendering. Accounts live in a `ListModel`, so rows stay in place on a refresh instead of being rebuilt. |
| `YubicoIcon.qml` | The Yubico logo as a `Shape`; there is no Nerd Font glyph for it. |
| `ProviderIcon.qml` | The icon for a row: from a pack, a built-in logo or the first letter. Blinks while waiting for a touch and briefly shows a check mark after copying. |
| `Providers.js` | Logos and colours per issuer, plus grouping of the code. To add a brand: an entry in `BRANDS` with the path and colour from Simple Icons. |
| `scripts/yk-otp` | All key I/O. Every message is one JSON line on stdout. |
| `install` | Copies the plugin into Omarchy's plugin directory. |

</details>

<details>
<summary><b>The helper script</b></summary>

<br>

`scripts/yk-otp` has three subcommands:

```bash
scripts/yk-otp unlock               # wait for a key and a touch
scripts/yk-otp codes SERIAL         # accounts, with the codes that need no touch
scripts/yk-otp code SERIAL ID_HEX   # the code of one account
```

The touch on opening goes through FIDO selection (`authenticatorSelection`), not OATH.
That way the key blinks without computing anything, the first key you touch wins when
several are plugged in, and stopping the process cancels the selection cleanly, so the key
does not keep blinking.

</details>

## ™️ Trademarks

The Yubico, Autodesk, Bambu Lab and JetBrains logos are trademarks of their respective
owners. The built-in path data comes from [Simple Icons](https://simpleicons.org) (CC0).
Icons from aegis-icons are downloaded by you and are not part of this repository.

## 📄 License

[MIT](LICENSE) © 2026 Martijn Valkier
