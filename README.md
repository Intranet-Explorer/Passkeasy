# Passkeasy

**YubiKey enrollment for the help desk. One menu, no portal.**

```
    ____  ___   __________ __ __ _________   _______  __
   / __ \/   | / ___/ ___// //_// ____/   | / ___/\ \/ /
  / /_/ / /| | \__ \\__ \/ ,<  / __/ / /| | \__ \  \  /
 / ____/ ___ |___/ /__/ / /| |/ /___/ ___ |___/ /  / /
/_/   /_/  |_/____/____/_/ |_/_____/_/  |_/____/  /_/

       .: yubikey enrollment made easy :.
```

Provisioning a hardware security key through the admin portal takes fourteen
clicks and a browser tab you'll lose. Passkeasy wraps Yubico's
[YubiEnroll](https://www.yubico.com/support/download/yubienroll/) CLI in a
menu a help desk tech can drive without reading a manual: search the user,
plug in the key, enroll. A new hire's key is done in seconds.

Built for real onboarding at a financial institution. As far as I can find,
the first YubiEnroll wrapper of its kind on GitHub.

## What it does

- **Enroll a YubiKey for any user** by UPN or Object ID — with optional
  enrollment profile, display name, and NFC reader selection
- **Search users** in your identity provider from the same menu
- **List and delete credentials** per user
- **Manage enrollment profiles and identity providers** (Entra ID, Okta)
- **Install YubiEnroll for you** — detects a missing install, pulls the
  latest MSI from Yubico, and runs it silently

## Requirements

- Windows with [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows)
- [YubiEnroll](https://www.yubico.com/support/download/yubienroll/) — or let
  the script install it on first run
- An identity provider YubiEnroll supports (Microsoft Entra ID, Okta) and an
  account with enrollment rights

## Run it

```powershell
git clone https://github.com/Intranet-Explorer/Passkeasy.git
cd Passkeasy
pwsh ./Passkeasy.ps1
```

No modules, no dependencies, no admin rights — YubiEnroll handles its own
UAC elevation when it needs it.

## Why the comments are so chatty

The script doubles as a PowerShell teaching file. Every non-obvious construct
— splatting, scoping, ternaries, automatic variables — is explained where it's
used. Strip the comments and it still runs; read them and you learn the
language. That's on purpose.

## License

[GPL-3.0](LICENSE). Use it, fork it, ship it — keep derivatives open and
credited.
