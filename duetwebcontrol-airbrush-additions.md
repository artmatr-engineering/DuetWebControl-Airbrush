# DuetWebControl Porting Summary (Airbrush Fork Delta)

This document summarizes the code delta between:

- Base: `Duet3D/DuetWebControl` `v3.6-dev` (merge-base: `e839a91`)
- Fork: `artmatr-engineering/DuetWebControl-Airbrush` `v3.6-dev` at `1a6fa62`

Use this to re-apply the same behavior on newer upstream DuetWebControl revisions.

## Scope

- Ahead vs `Duet3D/v3.6-dev`: local ahead by 3 commits, behind by 3 (Version 3.6.2, rawPosition removal, rc.1 bump)
- 8 files changed (excluding `package-lock.json` which is lockfile churn)
- Key new files: `scripts/copy-object-model.sh`, `src/components/panels/UBabystepPanel.vue`

Files changed:

1. `scripts/copy-object-model.sh` — new file
2. `src/components/panels/UBabystepPanel.vue` — new file
3. `src/components/panels/index.ts` — register new panel
4. `src/routes/Job/Status.vue` — add U babystepping panel to job status layout
5. `src/components/panels/CNCMovementPanel.vue` — disable compensation & setWorkXYZ buttons; disable non-Z axis "Set" buttons
6. `src/store/machine/model.ts` — patch boards without skipping non-existent fields (allows `rawAngle` to propagate)
7. `package.json` — remove `@duet3d/objectmodel` dependency (uses local copy instead), add `build-copy-object-model` script
8. `package-lock.json` — lockfile churn (do not manually port; regenerate)

## High-Level Intent

Three airbrush-specific commits:

1. **`f1d734a`** `airbush babystepping and set XYUV greyed out all bad work offset buttons IDIOT PROOF`
   - Add U-axis babystepping panel
   - Disable compensation menu button (irrelevant for airbrush)
   - Disable "Set Work XYZ" button
   - Disable "Set axis" buttons for all non-Z axes
   - Reformat CNCMovementPanel.vue (tabs → 2-space indent)
   - Reformat model.ts (tabs → 2-space indent)

2. **`a12ebd4`** `OM changes added but not yet visible in DWC`
   - Change `patch()` call for `boards` key to pass `skipNonexistent = false`, allowing new firmware properties (like `rawAngle`) to flow through to the store
   - Remove `@duet3d/objectmodel` from npm dependencies (use local ObjectModel-Airbrush build instead)
   - Add `build-copy-object-model` script to `package.json`

3. **`1a6fa62`** `removed old scripts`
   - Add `scripts/copy-object-model.sh` shell script to copy ObjectModel-Airbrush into `node_modules/@duet3d/objectmodel`

## File-by-File Porting Instructions

### 1) `scripts/copy-object-model.sh` (new file)

Add this new file at `scripts/copy-object-model.sh`:

```bash
#!/bin/bash

# Script to copy modified ObjectModel-Airbrush files to @duet3d/objectmodel
# This replaces the JavaScript version with a native shell script

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SOURCE_DIR="$PROJECT_ROOT/ObjectModel-Airbrush"
TARGET_DIR="$PROJECT_ROOT/node_modules/@duet3d/objectmodel"

echo "=================================="
echo "Copying modified ObjectModel-Airbrush to @duet3d/objectmodel"
echo "=================================="
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory does not exist: $SOURCE_DIR"
    echo "Make sure ObjectModel-Airbrush is cloned in the project root"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

if command -v rsync &> /dev/null; then
    echo "Using rsync to copy files..."
    rsync -av --delete "$SOURCE_DIR/" "$TARGET_DIR/"
else
    echo "Using cp to copy files..."
    rm -rf "$TARGET_DIR/"*
    cp -r "$SOURCE_DIR/"* "$TARGET_DIR/"
fi

echo ""
echo "✓ Copy complete!"
echo "Modified ObjectModel-Airbrush has been copied to @duet3d/objectmodel"
echo ""
```

Make it executable: `chmod +x scripts/copy-object-model.sh`

### 2) `src/components/panels/UBabystepPanel.vue` (new file)

Add this new file at `src/components/panels/UBabystepPanel.vue`:

```vue
<template>
    <v-card>
        <v-card-title class="pb-0">
            <v-icon small class="mr-1">mdi-format-vertical-align-center</v-icon>
            U Axis Babystepping
        </v-card-title>

        <v-card-text class="pt-1">
            Current: {{ $displayZ(babystepping) }}

            <v-row class="mt-1" dense>
                <v-col>
                    <code-btn
                        :code="`M290 R1 U${-babystepAmount}`"
                        no-wait
                        block
                    >
                        <v-icon>mdi-arrow-collapse-vertical</v-icon>
                        {{ $displayZ(-babystepAmount) }}
                    </code-btn>
                </v-col>

                <v-col>
                    <code-btn
                        :code="`M290 R1 U${babystepAmount}`"
                        no-wait
                        block
                    >
                        <v-icon>mdi-arrow-split-horizontal</v-icon>
                        +{{ $displayZ(babystepAmount) }}
                    </code-btn>
                </v-col>
            </v-row>
        </v-card-text>
    </v-card>
</template>

<script lang="ts">
import { AxisLetter } from "@duet3d/objectmodel";
import Vue from "vue";

import store from "@/store";

export default Vue.extend({
    computed: {
        babystepping(): number {
            return (
                store.state.machine.model.move.axes.find(
                    (axis) => axis.letter === AxisLetter.U,
                )?.babystep ?? 0
            );
        },
        babystepAmount(): number {
            return 0.01;
        },
    },
});
</script>
```

### 3) `src/components/panels/index.ts`

Add import and component registration for `UBabystepPanel`:

```diff
 import ZBabystepPanel from "./ZBabystepPanel.vue";
+import UBabystepPanel from "./UBabystepPanel.vue";
 import FFFContainerPanel from "./FFFContainerPanel.vue";
```

```diff
 Vue.component("z-babystep-panel", ZBabystepPanel);
+Vue.component("u-babystep-panel", UBabystepPanel);
 Vue.component("cnc-axes-position", CNCAxesPosition);
```

### 4) `src/routes/Job/Status.vue`

Add `<u-babystep-panel />` before `<z-babystep-panel />` in the left column of the job status layout:

```diff
-                    <v-col cols="12">
-                        <z-babystep-panel />
-                    </v-col>
+                    <v-col cols="12">
+                        <u-babystep-panel />
+                    </v-col>
+                    <v-col cols="12">
+                        <z-babystep-panel />
+                    </v-col>
```

The file also has tab→space reformatting throughout. Only the `<u-babystep-panel />` insertion is functionally required.

### 5) `src/components/panels/CNCMovementPanel.vue`

Three functional changes (remainder of diff is tab→2-space reformatting):

**a) Disable the Compensation menu button** — change `:disabled="uiFrozen"` to just `disabled` (always disabled):

```diff
-              <v-btn
-                v-show="visibleAxes.length"
-                color="primary"
-                block
-                class="mx-0 move-btn"
-                :disabled="uiFrozen"
-                v-on="on"
-              >
+              <v-btn
+                v-show="visibleAxes.length"
+                color="primary"
+                block
+                class="mx-0 move-btn"
+                disabled
+                v-on="on"
+              >
```

**b) Disable the "Set Work XYZ" button** — add `disabled` attribute:

```diff
-          <v-btn @click="setWorkplaceZero" block class="move-btn">
+          <v-btn @click="setWorkplaceZero" block class="move-btn" disabled>
```

**c) Disable the per-axis "Set" button for all non-Z axes** — add `:disabled="axis.letter !== 'Z'"`:

```diff
               <code-btn
                 color="warning"
                 tile
                 block
                 :code="`G10 L20 P${currentWorkplace} ${axis.letter}0`"
+                :disabled="axis.letter !== 'Z'"
                 class="move-btn"
               >
```

### 6) `src/store/machine/model.ts`

One functional change (remainder is tab→2-space reformatting):

In the `update` mutation, when patching board data, pass `skipNonexistent = false` so new firmware fields like `rawAngle` can flow into the store even if not present in the default model:

```diff
-            patch((state as any)[key], (typedState as any)[key]);
+            // Don't skip non-existent fields when patching boards to allow new firmware properties (like rawAngle)
+            const skipNonexistent = key !== "boards";
+            patch(
+              (state as any)[key],
+              (typedState as any)[key],
+              skipNonexistent
+            );
```

Search anchor: find the `else` branch in the `update` mutation that calls `patch(...)`.

### 7) `package.json`

Two changes:

**a) Remove `@duet3d/objectmodel` from dependencies** (the local ObjectModel-Airbrush build is used instead via the copy script):

```diff
-    "@duet3d/objectmodel": "~3.6.0",
```

**b) Add `build-copy-object-model` script**:

```diff
     "build": "vue-cli-service build",
+    "build-copy-object-model": "node ../ObjectModel-Airbrush/node_modules/@duet3d/objectmodel",
     "build-plugin": "node scripts/build-plugin.js",
```

### 8) `package-lock.json`

Do not manually port. Regenerate with `npm install` or `bun install` after applying the `package.json` changes.

## Porting to an Upstream 3.6.2 Base

Since `artmatr-engineering/DuetWebControl-Airbrush` has no version tags, use the upstream `Duet3D/DuetWebControl` `v3.6-dev` commit `3d6eaaf` ("Version 3.6.2") as the base:

```bash
git remote add upstream https://github.com/Duet3D/DuetWebControl.git
git fetch upstream
git checkout upstream/v3.6-dev -b 3.6.2-airbrush
# then apply changes above
```

## Validation Checklist

1. `bun run build` (or `npm run build`) completes without errors.
2. U-axis babystepping panel appears on Job Status page.
3. CNC compensation menu button is permanently disabled (greyed out).
4. "Set Work XYZ" button is permanently disabled.
5. Per-axis "Set" buttons are disabled for all axes except Z.
6. `boards[].drivers[].closedLoop.rawAngle` updates live in the UI (requires ObjectModel-Airbrush and firmware changes).
7. Run `scripts/copy-object-model.sh` to inject local ObjectModel-Airbrush before building.

## Conflict Hotspots on Newer Upstream

1. `src/store/machine/model.ts` — `update` mutation's `patch()` call; upstream may refactor patch logic.
2. `src/routes/Job/Status.vue` — layout column structure may change.
3. `src/components/panels/index.ts` — import order/grouping.
4. `package.json` — dependency versions may change.

Search anchors:

1. `patch((state as any)` — in `model.ts` update mutation
2. `z-babystep-panel` — in `Status.vue` for panel insertion point
3. `ZBabystepPanel` import — in `index.ts`
4. `setWorkplaceZero` — in `CNCMovementPanel.vue`
5. `@duet3d/objectmodel` — in `package.json`

## Notes

- The `artmatr-engineering/DuetWebControl-Airbrush` org repo already contains all three airbrush commits; there is no separate clean base tag.
- The upstream `Duet3D/DuetWebControl` `v3.6-dev` is 3 commits ahead (Version 3.6.2, rawPosition removal, rc.1 bump) of the merge-base.
- `model.ts` and most `.vue` files have significant tab→space reformatting; only the semantic changes listed above need to be applied when porting forward.
