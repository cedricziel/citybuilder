# Republishing the design system

The "Citybuilder" design system (https://claude.ai/artifact/4jaGCEE3CUjDaC6G1LKb2T) is built from `design/web`. After a PR that changes `design/web` merges, republish the components it changed. `CLAUDE.md` has the rule.

The system keeps the layout its migration gave it: one bundle (`project/_ds_bundle.js`, `project/_ds_bundle.css`), one compiled preview per component (`project/_preview/<Name>.js`), and per component a card, types, a usage note and a re-export under `project/components/<group>/<Name>/`. `build.mjs` writes all of these from `design/web/dist`, `design/web/docs/*.md` (the component list and groups) and `.design-sync/previews/*.tsx` (the card stories).

## Steps

1. Start from `main` after the merge.
2. Read the published system with the Artifact tool, saving its current copies of the files the build edits in place:

   ```text
   Artifact { action: "read", url: "https://claude.ai/artifact/4jaGCEE3CUjDaC6G1LKb2T",
              paths: ["project/design-system.json", "project/_ds_manifest.json", "project/README.md",
                      "project/assets/notes/COMPONENTS.md"] }
   ```

   The result names the folder it saved them in, which ends in `…/artifact-files/<id>`. That folder holds `project/…`.
3. Build into a scratch folder, comparing against that copy:

   ```sh
   cd design/web
   npm ci
   npm run ds:build -- --out <scratch>/ds --artifact <saved folder> --since <last published commit>
   ```

   The last published commit is in the index's `lastChange.note`, as `main@<sha>`. The build writes `<scratch>/ds/project/…` and `<scratch>/ds/changes.json`. The JSON lists the shared files that differ, and the files of each component whose source, docs stub or preview changed since that commit. Without `--since`, every component is listed, because a rebuild words some files differently from the published copies.
4. Publish one call per group of files, with `url` set to the system, `root` set to `<scratch>/ds`, and `file_path` set to one file's absolute path:
   - first the bundle and stylesheet, when they changed: `_ds_bundle.js` and `_ds_bundle.css`;
   - then each component in `changes.json`: its `_preview/<Name>.js` plus its files under `components/…`;
   - last, `_ds_manifest.json`, `README.md`, `assets/notes/COMPONENTS.md` and the index.

   Send `.d.ts`, `.jsx` and `.html` files as `{ "from": "<path>", "contentType": "text/plain" }`, because the system stores them as text. Leave out files that didn't change, and leave other components alone.
5. For the index, read `project/design-system.json` again right before the last call. Change only its `lastChange` (`by`, `at`, `via`, `note`), with `note` naming the commit you built from (`main@<sha>: …`). Keep every other key as read.

Don't use the DesignSync tool for this. It needs the user-started `/design-sync` skill.

## Adding a component to `design/web`

- Add `src/components/<Name>/<Name>.tsx`, and export it from `src/index.ts`.
- Add `docs/<Name>.md` with `category: Art | HUD | Sheets | Screens | Foundations`.
- Add `.design-sync/previews/<Name>.tsx`, with one exported story per state.
- Optionally, set `cardMode: "column"` in `.design-sync/config.json` for wide stories.

`npm run typecheck` also checks the previews.
