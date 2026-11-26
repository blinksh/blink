# Portable apps (experimental)

Open Blink Settings (for example, run `config` at the Blink prompt), then
choose **Apps (Experimental)** under **Configuration**. Tap **Plugin
Playground** to try a bundled app, or choose **Install from GitHub…** and
paste a public repository or plugin-folder URL. For a terminal UI, try:

```text
https://github.com/myneid/wink/tree/main/examples/hterm-tui
```

Review the app name, ID, version, permissions and pinned GitHub commit before
installation. Long-press an installed app to open its source repository or
check for updates. Updates require another review and preserve the previous
package and the app's stored data.

Blink and Wink use the same version-1 manifest and HTML entry point.
Blink provides `blink.host.info()` and, when requested by the manifest,
`blink.storage.get(key)` and `blink.storage.set(key, value)`. Storage is
limited to 64 KiB per app. Consult the
[plugin authoring guide](https://github.com/myneid/wink/blob/main/docs/plugins.md)
for package structure and the hterm starter.

Apps run in separate nonpersistent WebViews with same-package assets and no
network API, shell, SSH, PTY, or access to terminal sessions. The starter
bundles its own hterm; opening it does not replace Blink's terminal. Wink's
Spotify service is host-specific and is not part of Blink's portable API.
