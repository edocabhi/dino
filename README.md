# GenUI Hackathon Starter 🦄

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A starter Flutter app for building **Generative UI** (GenUI) experiences. Instead of the model replying with plain text, it replies with a _user interface_: buttons, lists, cards, forms, and more, rendered live as real Flutter widgets.

This template wires up a model hosted on [Featherless.ai](https://featherless.ai) to Flutter's [`genui`](https://pub.dev/packages/genui) package so you can start shaping that experience right away. You bring two things: a **catalog** of widgets the model is allowed to use, and a **system prompt** that tells it how to behave. The template handles everything in between.

New to GenUI? That's fine. This README walks you through it from scratch, including installing Flutter.

---

## What is GenUI, in one minute

A normal chat app sends your message to a model and gets text back. GenUI sends your message to a model and gets back a structured description of a UI (in a format called **A2UI**, "agent-to-UI"). The `genui` package turns that description into live Flutter widgets on screen.

The model can only ever describe widgets you've told it about. That list of allowed widgets is the **catalog**. Because the same catalog is fed to the model _and_ used to render, the model can never ask for something your app can't draw.

So the two knobs you'll touch most are:

- **`lib/catalog.dart`** — _what_ the model can build (the widget vocabulary).
- **`lib/prompt.dart`** — _how_ the model should behave (persona, tone, rules).

Everything else in this template is plumbing that connects those two things to Featherless and to the screen.

---

## Getting started

This section assumes you have **never installed Flutter**. We'll run the app as a **native desktop app**, which is the quickest path: no simulators or devices needed. Follow the instructions for your operating system below.

### 1. Install Flutter

<details open>
<summary><strong>macOS</strong></summary>

1. Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) from the App Store (required to build macOS apps). After it installs, open it once so it can finish setting up, then run:
   ```sh
   sudo xcodebuild -runFirstLaunch
   ```
2. Install Flutter. If you have [Homebrew](https://brew.sh):
   ```sh
   brew install --cask flutter
   ```
   Otherwise, follow the manual steps at [docs.flutter.dev/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos).
3. Confirm everything is healthy. This checks your toolchain and tells you if anything is missing:
   ```sh
   flutter doctor
   ```
   You want green checkmarks for **Flutter** and **Xcode** at minimum. Don't worry if Android/Chrome show warnings; you don't need them for macOS.

</details>

<details>
<summary><strong>Windows</strong></summary>

1. Install [Visual Studio](https://visualstudio.microsoft.com/downloads/) (the IDE, not VS Code) with the **"Desktop development with C++"** workload. This is required to build Windows desktop apps.
2. Install Flutter. If you have [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (built into Windows 10/11), open PowerShell and run:
   ```powershell
   winget install --id=Google.Flutter -e
   ```
   Otherwise, follow the manual steps at [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows). After installing, close and reopen your terminal so `flutter` is on your `PATH`.
3. Confirm everything is healthy. This checks your toolchain and tells you if anything is missing:
   ```powershell
   flutter doctor
   ```
   You want green checkmarks for **Flutter** and **Visual Studio** at minimum. Don't worry if Android/Chrome show warnings; you don't need them for Windows desktop.

</details>

<details>
<summary><strong>Linux</strong></summary>

1. Install the build dependencies for Linux desktop apps. On Debian/Ubuntu:
   ```sh
   sudo apt-get update
   sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa \
     clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
   ```
   (On Fedora/Arch the package names differ; see the Flutter docs linked below.)
2. Install Flutter. The simplest cross-distro option is [snap](https://snapcraft.io/):
   ```sh
   sudo snap install flutter --classic
   ```
   Otherwise, follow the manual steps at [docs.flutter.dev/get-started/install/linux](https://docs.flutter.dev/get-started/install/linux).
3. Confirm everything is healthy. This checks your toolchain and tells you if anything is missing:
   ```sh
   flutter doctor
   ```
   You want green checkmarks for **Flutter** and **Linux toolchain** at minimum. Don't worry if Android/Chrome show warnings; you don't need them for Linux desktop.

</details>

This project targets the Flutter SDK that ships **Dart `^3.12.1`** (see [pubspec.yaml](pubspec.yaml)). If `flutter doctor` reports an older Dart, run `flutter upgrade`.

### 2. Get a Featherless API key

The app talks to a model hosted on Featherless, which needs an API key.

1. Go to [featherless.ai](https://featherless.ai) and sign in.
2. Open your account settings and create an API key.
3. Copy the key somewhere safe. You'll paste it in the next step.

The key is **not** stored in the project. You pass it in at run time, so it never ends up in source control.

### 3. Install the project's dependencies

From the project root:

```sh
flutter pub get
```

### 4. Run the app

Enable desktop support for your platform once (harmless if already enabled):

```sh
# macOS
flutter config --enable-macos-desktop
# Windows
flutter config --enable-windows-desktop
# Linux
flutter config --enable-linux-desktop
```

Then run, passing your Featherless key in via `--dart-define`. Use the device matching your OS:

```sh
# macOS
flutter run -d macos --dart-define=FEATHERLESS_API_KEY=your_key_here
# Windows
flutter run -d windows --dart-define=FEATHERLESS_API_KEY=your_key_here
# Linux
flutter run -d linux --dart-define=FEATHERLESS_API_KEY=your_key_here
```

Replace `your_key_here` with the key from step 2. The first build takes a minute or two; later runs are faster.

> **Windows note:** In PowerShell the command above works as-is. If your key contains special characters, wrap the whole `--dart-define` value in quotes: `"--dart-define=FEATHERLESS_API_KEY=your_key_here"`.

> **Why `--dart-define`?** It injects the key as a compile-time constant the app reads via `String.fromEnvironment('FEATHERLESS_API_KEY')` (see [lib/model/featherless_model_client.dart](lib/model/featherless_model_client.dart)). This keeps your secret out of the codebase. If you forget the flag or the key is invalid, the app shows a SnackBar with the error instead of a blank screen.

Once it's running, type a request into the box at the bottom, for example _"Make a list of 3 fruits with their emojis, and a button to add a new random fruit to the list"_ The left side shows the rendered UI; the right side shows the raw A2UI JSON the model produced, so you can see exactly what it asked for.

> **Tip:** Tired of typing the long command? Most editors let you save it. In VS Code, add a `launch.json` config with `"args": ["--dart-define=FEATHERLESS_API_KEY=your_key_here"]`.

---

## How the project is laid out

Here's every meaningful file in [lib/](lib/) and what it's for. The files you'll edit most are at the top.

### The files you'll probably customize

| File                                   | What it's for                                                                                                                                                                                                                                                                                                                                        |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`lib/catalog.dart`](lib/catalog.dart) | **Defines the widgets the model knows how to use.** This is your GenUI vocabulary. It ships with `BasicCatalogItems` (a ready-made set of common widgets). Add your own components here to expand what the model can build. The catalog feeds both the renderer and the system prompt, so the model can only ever request widgets you've registered. |
| [`lib/prompt.dart`](lib/prompt.dart)   | **Defines the overall interaction.** A plain system-prompt string: the assistant's persona, tone, and any domain rules. You focus on _what_ the assistant should do; the framework already teaches the model _how_ to emit valid A2UI, so you don't have to.                                                                                         |

Start here. You can build a surprising amount just by editing these two.

### The GenUI plumbing (you might edit this)

| File                                                         | What it's for                                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`lib/model/model_client.dart`](lib/model/model_client.dart) | A model-agnostic `ModelClient` interface. It owns the conversation history and exposes the latest model response. Swap in a different model by writing a new subclass; nothing else has to change.                                                                                                            |
| [`lib/conversation.dart`](lib/conversation.dart)             | `GenUiSession`: the heart of the pipeline. It ties together the GenUI `SurfaceController` (which renders), the transport (which carries A2UI chunks), the `Conversation` (which tracks state), and the `ModelClient`. It builds and disposes all four as a single unit so the UI doesn't have to juggle them. |

### The screen and widgets for the demo UI (feel free to replace all this)

| File                                                                     | What it's for                                                                                                                                                                  |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`lib/home_page.dart`](lib/home_page.dart)                               | The main screen. Creates the catalog and session, shows the rendered surface on the left and the raw A2UI source on the right, and feeds your typed messages into the session. |
| [`lib/app.dart`](lib/app.dart)                                           | The root `MaterialApp`. Theming and top-level app config go here.                                                                                                              |
| [`lib/main.dart`](lib/main.dart)                                         | The `main()` entry point that boots the app.                                                                                                                                   |
| [`lib/widgets/message_input.dart`](lib/widgets/message_input.dart)       | The text box and send button at the bottom of the screen.                                                                                                                      |
| [`lib/widgets/a2ui_source_view.dart`](lib/widgets/a2ui_source_view.dart) | The right-hand panel that shows the raw A2UI JSON as it streams in. Handy for learning and debugging.                                                                          |
| [`lib/widgets/widgets.dart`](lib/widgets/widgets.dart)                   | A barrel file that re-exports the widgets above for tidy imports.                                                                                                              |

---

## Where to go next

- **Teach the model new tricks.** Add a custom component to [`lib/catalog.dart`](lib/catalog.dart). Once it's in the catalog, the model can use it.
- **Change the personality.** Rewrite the string in [`lib/prompt.dart`](lib/prompt.dart) to give the assistant a focus, a tone, or domain rules.
- **Try a different model.** Change `_defaultModel` in [`lib/model/featherless_model_client.dart`](lib/model/featherless_model_client.dart), or write a new `ModelClient` subclass for a different provider.
- **Learn the framework.** See the [`genui` package on pub.dev](https://pub.dev/packages/genui) for the full catalog API and A2UI format.

Happy building.

---

Developed with 💙 by [Very Good Ventures][very_good_ventures_link] 🦄

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_ventures_link]: https://verygood.ventures
