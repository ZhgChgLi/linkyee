<!-- markdownlint-disable-next-line -->
English | [繁體中文](./README.zh-TW.md)

<!-- markdownlint-disable-next-line -->
<div align="center">

  <!-- markdownlint-disable-next-line -->
  # linkyee — Your Own Link Page

  A fully customized, **100% free**, open-source LinkTree alternative — deployed straight to GitHub Pages.

  Inspired by Jekyllrb and LinkTree.

  [![Automatic build](../../actions/workflows/build.yml/badge.svg)](../../actions/workflows/build.yml) [![pages-build-deployment](../../actions/workflows/pages/pages-build-deployment/badge.svg)](../../actions/workflows/pages/pages-build-deployment)

  [**Live Demo →**](https://zhgchg.li/linkyee/)

<img width="1158" height="1092" alt="image" src="https://github.com/user-attachments/assets/45b1ae8f-dfca-40e0-a14e-064c7f45ad1b" />

</div>

> **In one sentence:** click *Use this template*, edit one YAML file, push — your link page is live on GitHub Pages with a free `*.github.io` domain (or your own). No SaaS, no monthly fee, no vendor lock-in. AI-assisted theming and plugin development included.

## Table of contents

- [Why linkyee?](#why-linkyee)
- [Configuration](#configuration)
- [Themes 🎨](#themes-)
- [Plugins 🔌](#plugins-)
- [Get Started – Deploy on GitHub Pages](#get-started--deploy-on-github-pages)
- [Local testing](#local-testing)
- [Custom Domain](#custom-domain-)
- [Showcase ✨](#showcase-)
- [Donate](#donate)

---

## Why linkyee?

- **100% free.** Hosted on GitHub Pages. No subscriptions, no ads, no upsells.
- **100% yours.** Your config, themes, plugins, and content live in your own GitHub repo. Take it offline whenever you want.
- **8 ready-made themes** — switch by editing a single line in `config.yml`.
- **AI Style Designer.** Describe the look you want in plain English; the bundled [`linkyee-style-designer`](./.claude/skills/linkyee-style-designer/SKILL.md) Claude skill writes the full theme for you (HTML + CSS + JS).
- **6 built-in plugins** for live data — GitHub stars, last commit, profile stats, RSS/Atom feeds, date countdowns, latest YouTube video.
- **AI Plugin Builder.** Want data from somewhere else? Describe the source; the bundled [`linkyee-plugin-builder`](./.claude/skills/linkyee-plugin-builder/SKILL.md) skill writes the Ruby plugin and wires it in.
- **SEO + accessibility built-in.** WCAG AA contrast, dark mode, responsive down to 320 px, OG/Twitter meta, keyboard-friendly focus states.
- **Local preview with auto-rebuild.** `./preview.sh` rebuilds on save; refresh the browser, no plugins needed.

### Buy me a beer ❤️❤️❤️

[![Buy Me A Beer](https://github.com/user-attachments/assets/63f01edf-2aa5-4d91-8f8a-861e5b6b4feb)](https://www.paypal.com/ncp/payment/CMALMPT8UUTY2)

[**If this project has helped you, feel free to sponsor me a cup of coffee, thank you.**](https://www.paypal.com/ncp/payment/CMALMPT8UUTY2)

Feel free to open an issue or submit a fix/contribution via pull request. :)

---

## Configuration

Everything that ends up on your page is driven by a single file: [`config.yml`](./config.yml). It's a Liquid-rendered YAML file with five top-level sections:

```yaml
theme: default                     # ← directory under ./themes/
lang: "en"

plugins:                           # ← optional dynamic data fetched at build time
  - GithubRepoStarsCountPlugin: [ZhgChgLi/linkyee]

title: "Your Name"                 # ← profile header
avatar: "./images/profile.jpeg"
name: "@yourhandle"
tagline: "One line about you."

links:                             # ← buttons in the link list
  - link:
      icon: "fa-brands fa-github"
      text: "GitHub ({{ vars.GithubRepoStarsCountPlugin['ZhgChgLi/linkyee'] }} ⭐)"
      url: "https://github.com/yourname"
      target: "_blank"

socials: [ ... ]                   # ← icon-only social row
footer: "Free-form HTML."
copyright: "© 2026 You."
```

The shipped [`config.yml`](./config.yml) is a fully working example that exercises **every built-in plugin** — read it as the canonical reference. Edit fields in place, push, wait for GitHub Actions to rebuild, refresh.

### Multi-language sites

Configure `i18n` to render one static site for each locale. The root page
chooses a saved or browser-matching locale, then falls back to
`default_locale`.

```yaml
i18n:
  default_locale: en
  locales:
    en: locales/en.yml
    es: locales/es.yml
```

Each locale file overrides profile content and may supply UI labels:

```yaml
lang: es
og_locale: es_ES
locale_label: Español
title: Página de enlaces
name: Ejemplo
ui:
  language_switcher: Idioma
  primary_links: Enlaces principales
```

Locale hashes merge with `config.yml`; locale arrays such as `links` and
`socials` replace their base values. Builds create `/<locale>/` directories
and a root redirect page. Without `i18n`, the existing single-page output is
unchanged. See [`examples/i18n`](./examples/i18n) for a complete generic
configuration.

### Automatic redeployment

The site rebuilds automatically once a day so plugin output (star counts, latest posts, etc.) stays fresh. The cron lives in [`build.yml`](../../actions/workflows/build.yml):

```yaml
schedule:
    - cron: '0 0 * * *'   # daily at 00:00 UTC
```

Delete the `schedule:` block if you don't want scheduled redeploys.

---

## Themes 🎨

linkyee ships **8 built-in themes** designed to be drop-in usable. Switch by editing one line in `config.yml`:

```yaml
theme: minimal-mono   # any directory under ./themes/
```

| Slug | Light | Dark | Aesthetic / good for |
|---|---|---|---|
| `default` | <img width="200" alt="default light" src="./themes/default/preview-light.png"> | <img width="200" alt="default dark" src="./themes/default/preview-dark.png"> | Clean cards · safe default for anyone |
| `minimal-mono` | <img width="200" alt="minimal-mono light" src="./themes/minimal-mono/preview-light.png"> | <img width="200" alt="minimal-mono dark" src="./themes/minimal-mono/preview-dark.png"> | Swiss minimal · monospace · engineers, writers |
| `editorial-serif` | <img width="200" alt="editorial-serif light" src="./themes/editorial-serif/preview-light.png"> | <img width="200" alt="editorial-serif dark" src="./themes/editorial-serif/preview-dark.png"> | Magazine serif · drop cap · bloggers, journalists |
| `neo-brutalism` | <img width="200" alt="neo-brutalism light" src="./themes/neo-brutalism/preview-light.png"> | <img width="200" alt="neo-brutalism dark" src="./themes/neo-brutalism/preview-dark.png"> | Thick borders · primary colors · indie devs, artists |
| `glassmorphism` | <img width="200" alt="glassmorphism light" src="./themes/glassmorphism/preview-light.png"> | <img width="200" alt="glassmorphism dark" src="./themes/glassmorphism/preview-dark.png"> | Frosted glass cards · designers, agencies |
| `paper-card` | <img width="200" alt="paper-card light" src="./themes/paper-card/preview-light.png"> | <img width="200" alt="paper-card dark" src="./themes/paper-card/preview-dark.png"> | Pastel cards · rounded · creators, illustrators |
| `newsprint` | <img width="200" alt="newsprint light" src="./themes/newsprint/preview-light.png"> | <img width="200" alt="newsprint dark" src="./themes/newsprint/preview-dark.png"> | Newspaper masthead · serif + mono · numbered link rows · the live look of [link.zhgchg.li](https://link.zhgchg.li/) |
| `terminal-retro` | <img width="200" alt="terminal-retro light" src="./themes/terminal-retro/preview-light.png"> | <img width="200" alt="terminal-retro dark" src="./themes/terminal-retro/preview-dark.png"> | CRT · scanlines · phosphor-green-on-black (dark) / olive-on-cream printer-paper (light) · hackers |

Every built-in theme meets the same baseline: WCAG AA contrast, **dark mode that auto-switches with your system appearance** (no manual toggle), responsive down to 320 px, keyboard-accessible focus states, and `prefers-reduced-motion` support.

To try them locally before committing, see [Local testing](#local-testing). To regenerate the preview screenshots above after any visual change, run `./scripts/screenshot-themes.sh` (requires `npx playwright`).

### Modifying a theme by hand

Each theme lives at `./themes/<theme-name>/` with three files:

- `index.html` — Liquid template (consumes `config.yml`)
- `styles.css` — the look
- `scripts.js` — can be empty, but the file must exist

The `default` theme self-hosts Font Awesome under `themes/default/fontawesome/`. The other built-ins load Font Awesome from a CDN to keep theme directories small.

### 🤖 AI Style Designer — generate a theme by description

Don't see a vibe you like? Describe it in plain English and the bundled [`linkyee-style-designer`](./.claude/skills/linkyee-style-designer/SKILL.md) Claude skill writes a full theme for you.

**How to use it:**

1. Install [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) and open this repo with it.
2. Ask in natural language. Examples:

   > *"Design a linkyee theme inspired by 1960s Penguin paperback covers."*
   >
   > *"Make my links look like a Japanese ryokan website — quiet, elegant, lots of negative space."*
   >
   > *"I want a vaporwave aesthetic but keep it accessible."*
3. The skill reads your `config.yml`, asks clarifying questions if the brief is vague, generates `themes/<your-theme>/`, switches `theme:` in `config.yml`, and runs the build.
4. Run `./preview.sh <new-theme>` to see the result locally.

The skill enforces the same quality bar as the built-in themes: no AI slop (no unwarranted purple-pink gradients, no emoji-as-icons, no centered-everything-no-hierarchy), real typographic hierarchy, accessibility minimums, and **strict RWD** — mobile-first, ≥44 px tap targets, no horizontal scroll at 320 px.

**Deeper design tooling.** If you want a richer designer experience (multi-direction exploration, expert review, animation export), install the upstream [`huashu-design`](https://github.com/alchaincyf/huashu-design) skill alongside it. The linkyee skill defers to `huashu-design` when both are present.

---

## Plugins 🔌

Plugins are tiny Ruby classes that fetch data **at build time** and inject it into your page. Use them to render live values inside any link, the tagline, or the footer — anything that's a Liquid string.

### Built-in plugins

| Plugin | What it emits | Reference shape |
|---|---|---|
| `GithubRepoStarsCountPlugin` | Star count for one or more repos | `{{ vars.GithubRepoStarsCountPlugin['owner/repo'] }}` |
| `GithubLastCommitPlugin` | Latest commit `sha` / `date` / `message` | `{{ vars.GithubLastCommitPlugin['owner/repo'].date }}` |
| `GithubProfilePlugin` | `followers` / `following` / `repos` | `{{ vars.GithubProfilePlugin['user'].followers }}` |
| `RSSFeedPlugin` | Latest items (Medium / blog / podcast / YouTube feeds) | `{{ vars.RSSFeedPlugin['url'][0].title }}` |
| `CountdownPlugin` | Days until / since a target date | `{{ vars.CountdownPlugin.label.days }}` |
| `YouTubeChannelLatestVideoPlugin` | Latest video — title, URL, thumbnail | `{{ vars.YouTubeChannelLatestVideoPlugin['@handle'].title }}` |

Enable in `config.yml`:

```yaml
plugins:
  - GithubRepoStarsCountPlugin:
      - ZhgChgLi/linkyee
  - RSSFeedPlugin:
      - https://yourblog.example/feed.xml
```

…then reference the result anywhere a Liquid string is rendered:

```yaml
links:
  - link:
      icon: "fa-brands fa-github"
      text: "linkyee ({{ vars.GithubRepoStarsCountPlugin['ZhgChgLi/linkyee'] }} ⭐)"
      url: "https://github.com/ZhgChgLi/linkyee"
```

If a plugin fails at build time (network error, API change, expired token, …) the build still succeeds — the value renders empty and the failure is logged in GitHub Actions output. Your site never breaks because of a flaky external API.

### 🤖 AI Plugin Builder — generate a plugin by description

Want data linkyee doesn't ship out of the box? Open the repo with [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) and describe what you want. The bundled [`linkyee-plugin-builder`](./.claude/skills/linkyee-plugin-builder/SKILL.md) skill knows the plugin contract.

**Examples:**

> *"Add a plugin that shows my 3 latest posts from medium.com/@myhandle as new links."*
>
> *"Fetch the current weather in Taipei from wttr.in and show the temp in the footer."*
>
> *"Add a plugin that pulls my Steam total playtime via the Steam Web API."*

The skill will:

1. Confirm the data source and shape with you.
2. Generate `plugins/<YourPlugin>.rb` (using the base-class HTTP/JSON/cache helpers — no raw `Net::HTTP`).
3. Wire it into `config.yml` under `plugins:` and reference the output where you asked it to appear.
4. Run `bundle exec ruby ./scaffold.rb` and verify the value rendered in `_output/index.html`.

### Developer wiki

For the full plugin contract — base-class helpers, common patterns (HTTP, JSON, scrape, cache), Liquid rendering rules, and debugging tips — read **[`plugins/README.md`](./plugins/README.md)**. It's the canonical reference the AI skill loads when it generates a plugin.

---

## Get Started – Deploy on GitHub Pages
### About Github Pages
> GitHub Pages is a free hosting service provided by GitHub, designed for creating and publishing websites directly from a GitHub repository. It allows developers, designers, and anyone with a GitHub account to host personal, project, or organizational websites without needing external hosting services. GitHub Pages works seamlessly with GitHub repositories, automatically generating a static website whenever new content is pushed.

#### Step 1. Click the “Use this template” button at the top-right corner of the [linkyee](https://github.com/ZhgChgLi/linkyee) Template Repo -> “Create a new repository”:
![image](https://github.com/user-attachments/assets/4b88da62-df4b-4f3b-a22c-e78b7527a92d)

#### Step 2. Check “Include all branches,” enter your desired GitHub Pages repo name, and click “Create repository” once finished:
![image](https://github.com/user-attachments/assets/d3611204-7507-41a1-8221-707200a3e269)

> The GitHub Pages repo name will affect the access URL. If you enter `your-username.github.io` as the Repo Name, that will be the direct URL to your GitHub Pages site.
> If you already have a `your-username.github.io` repo, the GitHub Pages URL will be `your-username.github.io/Repo-Name`.

#### Wait for the fork to complete. You might encounter deployment errors during the initial setup due to forked repo permission issues. Let’s proceed with the steps to adjust this.
![image](https://github.com/user-attachments/assets/038fac9e-83eb-4f2f-ba9a-88712b4af022)

#### Step 4. Go to Settings -> Actions -> General, ensure the following options are selected:
![image](https://github.com/user-attachments/assets/6851c4e6-9466-4800-862f-e9e5e5b65b11)

- Actions permissions: `Allow all actions and reusable workflows`
- Workflow permissions: `Read and write permissions`

After selecting, click the Save button to save your changes.

#### Step 5. Go to Settings -> Pages and ensure the selected branch for GitHub Pages is set to “gh-pages”:
![image](https://github.com/user-attachments/assets/1802bc78-4615-4d29-b180-9c84f3fb8d6d)

> 	The message `Your site is live at: XXXX` above is your public GitHub Pages access URL.

#### Step 6. Go to Settings -> Actions and wait for the first deployment to complete:
![image](https://github.com/user-attachments/assets/e57336ef-2f35-4455-abc0-76dce07470ee)

#### Step 7. Access the GitHub Pages URL to ensure the fork was successful:
![image](https://github.com/user-attachments/assets/023c39f7-9351-4175-8c9f-5eb42e2ecdb9)

> Congratulations! Deployment successful. You can now modify the configuration files with your own data. 🎉🎉🎉

#### Please note that after each files modification, you need to wait for GitHub Actions to complete the `Automatic build` and `pages build and deployment` tasks.

![image](https://github.com/user-attachments/assets/0ba637cc-3bb6-4458-a076-5f754c7429b3)

Refresh the page for the changes to take effect. 🚀

---

## Local testing

Build and serve the site on `http://localhost:8080`:

```bash
./preview.sh                    # build with the theme currently set in config.yml
./preview.sh minimal-mono       # temporarily switch to <theme-name>, build, serve;
                                # restores config.yml on Ctrl-C
PORT=4000 ./preview.sh          # use a different port
```

When you pass a theme argument, `preview.sh` makes a backup of your `config.yml`, switches to the requested theme for the session, and restores the original on `Ctrl-C` — your committed config is never modified.

### Auto-rebuild on save

While the preview is running, `preview.sh` watches:

- `themes/`
- `plugins/`
- `config.yml`
- `scaffold.rb`

Any change triggers an instant rebuild — just refresh the browser. Install [`fswatch`](https://github.com/emcrisostomo/fswatch) (`brew install fswatch` on macOS) for sub-second reaction; otherwise it falls back to a 1-second polling loop that works without any extra dependencies.

If a build fails (e.g. a broken Liquid reference), the watcher prints the error and keeps running — fix the issue, save again, the next save rebuilds.

### Requirements

- Ruby (`bundle install` once to fetch `liquid` and `nokogiri`)
- Python 3 (or Ruby) for the static file server `preview.sh` spawns

---

## Custom Domain ❤️❤️❤️

You can set a custom GitHub Pages domain, such as my own: [https://link.zhgchg.li](https://link.zhgchg.li).

Follow [my tutorial for domain binding.](https://en.zhgchg.li/posts/zrealm-dev/github-pages-custom-domain-setup-replace-github-io-with-your-own-domain-483af5d93297) If you'd like, you can [purchase a domain through my Namecheap referral](https://namecheap.pxf.io/P0jdZQ) link — I'll earn a small commission, which helps me keep contributing to open-source projects.

---

## Showcase ✨

Real websites built with **linkyee** — fast, clean, and open-source.

> Built your own site with linkyee?  
> ⭐ Add it here by opening a PR and inspire others!

| Preview | Website | Description |
|--------|--------|-------------|
| <img width="180" height="180" alt="ZhgChgLi" src="https://github.com/user-attachments/assets/9052e290-f6b8-4a94-a71e-85ec36cd2900" /> | [link.zhgchg.li](https://link.zhgchg.li) | ZhgChgLi (Harry Li)'s Personal blog link page |
| - |Your Site | Your site could be featured here 🚀 |

---

## Donate

[![Buy Me A Beer](https://github.com/user-attachments/assets/63f01edf-2aa5-4d91-8f8a-861e5b6b4feb)](https://www.paypal.com/ncp/payment/CMALMPT8UUTY2)

## About
- [ZhgChg.Li](https://zhgchg.li/)
- [ZhgChgLi's Medium](https://blog.zhgchg.li/)

## Other works
### Swift Libraries
- [ZMarkupParser](https://github.com/ZhgChgLi/ZMarkupParser) is a pure-Swift library that helps you to convert HTML strings to NSAttributedString with customized style and tags.
- [ZPlayerCacher](https://github.com/ZhgChgLi/ZPlayerCacher) is a lightweight implementation of the AVAssetResourceLoaderDelegate protocol that enables AVPlayerItem to support caching streaming files.

### Integration Tools
- [XCFolder](https://github.com/ZhgChgLi/XCFolder) is a powerful command-line tool that converts Xcode virtual groups into actual directories, reorganizing your project structure to align with Xcode groups and enabling seamless integration with modern Xcode project generation tools like Tuist and XcodeGen.
- [ZReviewTender](https://github.com/ZhgChgLi/ZReviewTender) is a tool for fetching app reviews from the App Store and Google Play Console and integrating them into your workflow.
- [ZMediumToMarkdown](https://github.com/ZhgChgLi/ZMediumToMarkdown) is a powerful tool that allows you to effortlessly download and convert your Medium posts to Markdown format.
