# kernel-test

Build workflow for the 5.10 Melt kernel on the POCO F5 / Redmi Note 12 Turbo (marble, SM7475).

The kernel source is not in this repo. What lives here is the GitHub Actions job that clones the source, patches it, compiles it with the latest LLVM release, packs AnyKernel3 zips and publishes them as a release. The build logic stays outside the kernel tree, so fixing a broken script doesn't mean rewriting kernel history.

## Running a build

Actions → **Compile Kernel - POCO F5 (Marble)** → *Run workflow*.

The defaults give you a CORE build with BakaSU. Everything else is an input; the interesting ones:

| Input | What it does |
|---|---|
| `kernel_source`, `kernel_branch` | Repo and branch to clone. Default is `yudharn/Pzqqt-Melt-Rebase` on `Yudharn-melt-rebase`. The other two branches are the plain rebase and the LTS one. |
| `manager_official_kernelsu`, `manager_kernelsu_next`, `manager_bakasu` | Which KSU flavour gets built in. Each ticked manager becomes its own build leg. |
| `full_build`, `core_build`, `vanilla_build` | Build modes, see the table below. At least one has to be ticked. |
| `melt_blessing` | How much of Melt-Blessing to apply: `all`, `zblock-mglru`, `reverts` or `off`. |
| `perf_patches` | The 19 WildKernels performance patches. Ones that don't apply, or that the tree already contains, are skipped and listed in the release notes. |
| `nomount_metamodule` | Builds the NoMount metamodule zip from the same NoMount commit the kernel was built with. |
| `include_manager_apk` | Attaches the latest CI manager APK for each flavour that was built. |
| `susfs_lkm_tag`, `susfs_commit`, `nomount_commit` | Pin those to a specific tag or commit. Empty means latest. |
| `ccache_update` | Deletes the ccache for this branch and manager before building. It's on by default, so every run starts cold. Turn it off when you're rebuilding the same thing. |

### Build modes

| Mode | SuSFS | NoMount | BBG | Re-Kernel | DroidSpaces | KSU |
|---|---|---|---|---|---|---|
| FULL | built in | yes | yes | netlink + eBPF | yes | selected manager |
| CORE | built in | yes | no | netlink + eBPF | no | selected manager |
| VANILLA | as LKM | yes | yes | netlink + eBPF | yes | none |

VANILLA ignores the manager checkboxes. It is a single build without built-in root and without built-in SuSFS; the SuSFS LKM zip is compiled against that exact kernel and attached to the release.

## What comes out

Each run ends in one release named like `5.10.274-Melt-Rebase-20261115_1852`. Assets:

- one AnyKernel3 zip per manager and mode, e.g. `Melt-Rebase-BakaSU-CORE-SuSFS-NoMount-5.10.274.zip`
- `SuSFS-LKM_marble-*.zip` when VANILLA was built
- `NoMount-metamodule-*.zip` when NoMount was enabled
- the manager APKs, if `include_manager_apk` was on

## Repo layout

- `.github/workflows/build.yml` — the whole pipeline: build matrix, toolchain, compile, packing, release
- `scripts/patch-helpers.sh` — `apply_patch`, `apply_first` and `apply_series` around `patch`, so a change that's already in the tree gets skipped instead of failing the run
- `scripts/melt-blessing.sh` — applies ZBlock, MG-LRU-lite, the KCompressd/KShrink removals and the kgsl `__GFP_NORETRY` revert
- `scripts/wild-extras.sh` — the WildKernels performance patches plus the ptrace and unicode fixes
- `scripts/ak3-modules.sh` — edits the prebuilt module package in AnyKernel3 so it matches what the patches changed
- `patches/melt-blessing/` — 5.10 ports of three Melt-Blessing patches, used when the upstream version targets newer code
- `configs/droidspaces-gki.config` — config fragment appended for DroidSpaces builds

## Notes

- AnyKernel3 comes from my fork (`yudharn/AnyKernel3`, branch `Anykernel3`). It ships prebuilt vendor modules. `ak3-modules.sh` drops `zram.ko` and `zsmalloc.ko` when ZBlock builds them into the image, drops the KShrink modules, and swaps in a rebuilt `msm_kgsl.ko`.
- DroidSpaces only gets its config fragment when both kABI patches (SYSVIPC and POSIX mqueue) are confirmed in the tree. Without them the extra IPC options can bootloop, so the workflow skips DroidSpaces for that run and says so in the log.
- `CONFIG_CFS_BANDWIDTH` and `CONFIG_CGROUP_PIDS` are left out of the config fragment on purpose. They change exported symbol CRCs, and stock vendor modules stop loading.
- Nothing here flashes anything. The zips are for recovery or a kernel manager.
- These are test builds. Don't flash one you haven't checked.

## Credits

Kernel source: [Pzqqt-Melt-Rebase](https://github.com/yudharn/Pzqqt-Melt-Rebase). Patches: [Melt-Blessing-Patches](https://github.com/WeiguangTWK/Melt-Blessing-Patches) and [WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches). Re-Kernel by [Sakion-Team](https://github.com/Sakion-Team/Re-Kernel), Baseband-guard by [vc-teahouse](https://github.com/vc-teahouse/Baseband-guard), SuSFS LKM from [susfs4ksu-lkm](https://github.com/inforcqb/susfs4ksu-lkm), AnyKernel3 from [osm0sis](https://github.com/osm0sis/AnyKernel3).
