This repo lets you automatically build your [SMAPI][] (C#) mods through free [GitHub Actions][].

> [!CAUTION]  
> The build workflow is still experimental and unversioned. It may change at any time, which may
> break your automated mod builds.
>
> Consider waiting for the 1.0.0 release, unless you're fine updating your repo whenever it changes.

# Contents
* [What is this?](#what-is-this)
* [Usage](#usage)
  * [Overview](#overview)
  * [Requirements](#requirements)
  * [Add the build workflow](#add-the-build-workflow)
  * [Git branch conventions](#git-branch-conventions)
  * [Further customization](#further-customization)
* [Using attestations](#using-attestations)
  * [What are attestations](#what-are-attestations)
  * [Recommended usage](#recommended-usage)
* [Actions](#actions)
  * [`add-build-environment`](#add-build-environment)
  * [`add-reference-assemblies`](#add-reference-assemblies)
  * [`set-prerelease-versions`](#set-prerelease-versions)
  * [`upload-release-artifacts`](#upload-release-artifacts)
* [More actions](#more-actions)
  * [Upload to GitHub](#upload-to-github)
  * [Upload to Nexus Mods](#upload-to-nexus-mods)
* [See also](#see-also)

## What is this?
These instructions add a build workflow to your GitHub repo which contains C# mods. It will run
automatically each time you push changes to your code.

By default, the workflow...
- sets up the build environment;
- builds the mod projects;
- uploads the mod zips as build artifacts which can be downloaded from the build page (with
  pre-release version numbers for non-release branches);
- and creates [attestations](#using-attestations) for release builds.

This has several benefits. For example:
- Detect any changes which break the build or unit tests (if any), including in pull requests.
- Provide automatic preview builds for pre-release changes.
- Ensure that any malware on your computer doesn't infect players installing your mods.
- Create [attestations](#using-attestations), which make your mod more trustworthy and verifiable.

You can customize or extend the workflow as much as you want.

# Usage
## Requirements
There's a few steps before you can automate builds on GitHub:

1. [Publish your source code on GitHub](https://stardewvalleywiki.com/Modding:Open_source).  
   _Either monorepo (multiple mods in one Git repo) or polyrepo (one mod per repo) is fine._
2. Create a `Directory.Build.props` file in your solution folder with this content:
   ```xml
   <Project>
       <PropertyGroup>
           <ModZipPath>$(MSBuildThisFileDirectory)/_releases</ModZipPath>
       </PropertyGroup>
   </Project>
   ```
   This configures the [mod build package][] to put its mod `.zip` files in one folder. You can use
   a different folder if you prefer, though you'll need to edit the default workflow if so.
3. For each mod, set the version number in its `.csproj` file. For example:
   ```xml
   <Project Sdk="Microsoft.NET.Sdk">
     <PropertyGroup>
       <Version>1.0.0</Version>
   </PropertyGroup>
   ```
   In the mod's `manifest.json` file, set the version to this exact string to automate it. (This
   will still work when building the mods yourself too.)
   ```json
   "Version": "%ProjectVersion%"
   ```

## Add the build workflow
Once your repo [meets the requirements](#requirements), you can add the default workflow in just two
steps.

1. From the repo folder, create a `.github/workflows/build.yml` file with this content:
   ```yml
   name: Build releases
   on: push
   jobs:
       build:
           runs-on: ubuntu-latest
           permissions:
              id-token: write     # for attestation
              attestations: write # for attestation
           env:
               RELEASE_REF: refs/heads/main # pushes to this branch are treated as public releases
           steps:
               - name: Fetch code
                 uses: actions/checkout@v4
                 with:
                     fetch-tags: false

               - name: Add build environment
                 uses: Pathoschild/SMAPI-ModBuildWorkflow/add-build-environment@v0

               - name: Set prerelease versions
                 uses: Pathoschild/SMAPI-ModBuildWorkflow/set-prerelease-versions@v0
                 if: github.ref != env.RELEASE_REF

               - name: Build mods
                 run: dotnet build --configuration Release

               - name: Upload release zips
                 uses: Pathoschild/SMAPI-ModBuildWorkflow/upload-release-artifacts@v0
                 with:
                     create_attestations: ${{github.ref == env.RELEASE_REF}}
      ```
2. Commit and push to GitHub.

That's it! If you check your repo on GitHub, you'll see the build running automatically on the
'Actions' tab.

## Git branch conventions
The default workflow assumes you **either**...

- Commit all changes directly to a `main` branch (e.g. GitHub's default flow).
- Or have a _release_ branch, which is updated when you create a public release (e.g. [Git flow][]).
  For example:
  ```
  • 1.2.0
  |\
  | \
  |  • update version
  |  • fix bug
  |  • add feature
  | /
  |/
  • 1.1.0
  |\
  | \
  |  • update version
  |  • ...
  ```

In either case, the workflow will work automatically for you. If your main/release branch
isn't named `main`, just edit the `RELEASE_REF` line to match.

For custom conventions, you can change the workflow to match by editing the `if:` and
`create_attestation:` lines.

## Further customization
[GitHub Actions][] are very flexible, and there's a large ecosystem of build steps you can use. The
instructions above set up a default workflow that works for most mod authors, but you can do much
more with it if you want!

For example, add this step after "_Build mods_" to fail the build if you have unit tests that don't
pass:
```yaml
- name: Run tests
  run: dotnet test --no-build
```

# Using attestations
## What are attestations?
The default workflow automatically creates GitHub [attestations][] for release builds. You can view
the attestation on GitHub by clicking the build on the 'Actions' tab, then clicking the link under
'Attestation Created'.

An _attestation_ is an unfalsifiable record which shows exactly how a release zip was created:
- which code was compiled;
- which scripts were run;
- what the build output said;
- and the signatures of each file produced.

Every step is public and verifiable, and players can read all of the code that was run. This can
also be used by local security tools. That makes your mod much more trustworthy.

## Recommended usage
When publishing a mod release:
1. Upload the zip created by the automated build.  
   _Don't zip the mods yourself, since the file signatures won't match the attestation. If your
   repo has many mods, you can [set the `create_combined_zip` option](#upload-release-artifacts) to
   download all the produced zips at once._
2. Include a link to the attestation in the download info. For example:
   ```
   See [release notes](https://…) and [security attestation](https://…).
   ```

# Actions
This section documents the custom [GitHub actions][] in this repo (which are used via the `uses:`
lines in your workflow). You can ignore this section unless you want to change their settings.

## `add-build-environment`
This action sets up the basic build environment:
- installs the .NET version used by the game (currently .NET 6);
- creates a game folder containing [reference assemblies][].

The basic usage sets up the default environment:
```yaml
- name: Add build environment
  uses: Pathoschild/SMAPI-ModBuildWorkflow/add-build-environment
```

You can optionally override the configuration:
```yaml
- name: Add build environment
  uses: Pathoschild/SMAPI-ModBuildWorkflow/add-build-environment
  with:
      # The .NET SDK version to install. This should usually be left as-is.
      dotnet_version: 6.0.x

      # Whether to build the mods using the selected .NET version (not just target it). This can
      # avoid compatibility issues in some cases, but prevents using newer .NET features in your
      # code.
      force_build_with_dotnet_version: false
```

## `add-reference-assemblies`
This action creates a game folder containing [reference assemblies][] (from
[StardewModders/mod-reference-assemblies][]). These are just `.dll` files with the public API
(without the actual implementation), which let you compile your mod code without installing the game
on the build server.

The basic usage adds them in a standard location for Linux, which will be auto-detected when you
build the mods:
```yaml
- name: Add reference assemblies
  uses: Pathoschild/SMAPI-ModBuildWorkflow/add-reference-assemblies@v0
```

You can optionally override the configuration:
```yaml
- name: Add reference assemblies
  uses: Pathoschild/SMAPI-ModBuildWorkflow/add-reference-assemblies@v0
  with:
      # The GitHub repository from which to fetch the reference assemblies, in the form 'owner/repo'.
      repository: StardewModders/mod-reference-assemblies

      # The Git branch, tag, or SHA to fetch.
      ref: main

      # The absolute path to the 'game folder' to create with the reference assemblies.
      path: "$HOME/.steam/steam/steamapps/common/Stardew Valley"
```

## `set-prerelease-versions`
This action changes the `<Version>` in each mod project to an auto-generated pre-release version
useful for preview builds (e.g. automated non-release builds). The version format is configurable
if needed.

Each `<Version>` is adjusted as such:
1. If the current version is stable (i.e. `x.y.z` with no `-tag`), the third number is incremented.
2. The tag is then appended or replaced.

For example, with the default settings:

version in code | new version
--------------- | -----------
`1.0.5`         | `1.0.6-alpha.202612302359`
`1.0.6-test`    | `1.0.6-alpha.202612302359`

The basic usage applies the change for all projects which create a release zip using the default
version format. In most cases, you should add `if:` to only do it for non-release branches:
```yaml
- name: Set prerelease versions
  uses: Pathoschild/SMAPI-ModBuildWorkflow/set-prerelease-versions@v0
  if: github.ref != env.RELEASE_REF # defined in default workflow
```

You can optionally override the configuration:
```yaml
- name: Set prerelease versions
  uses: Pathoschild/SMAPI-ModBuildWorkflow/set-prerelease-versions@v0
  if: github.ref != env.RELEASE_REF # defined in default workflow
  with:
      # Whether to only change projects which create a mod release zip.
      #
      # This skips `.csproj` files which set `<EnableModZip>false</EnableModZip>`. This only reads
      # the raw XML, so it doesn't support property inheritance or conditions.
      only_zipped: true

      # The format string for the timestamp in the pre-release tag (as .NET date format specifiers).
      timestamp_format: yyyyMMddHHmm

      # The pre-release tag to set, including the leading hyphen. If present, {{timestamp}} is
      # replaced automatically with a timestamp based on the `timestamp_format` option.
      tag_format: -alpha.{{timestamp}}
```

## `upload-release-artifacts`
This action uploads every `.zip` in the release folder as a build artifact (so it can be downloaded
from the build page on GitHub), and optionally creates [attestations](#using-attestations) for the
uploaded files.

The basic usage assumes the `.zip` files are in a `_releases` folder, and creates attestations
for release builds:
```yaml
- name: Upload release zips
  uses: Pathoschild/SMAPI-ModBuildWorkflow/upload-release-artifacts@v0
  with:
      create_attestations: ${{github.ref == env.RELEASE_REF}}
```

You can optionally override the configuration:
```yaml
- name: Upload release zips
  uses: Pathoschild/SMAPI-ModBuildWorkflow/upload-release-artifacts@v0
  with:
      # The path to the folder containing release zips.
      path: _releases

      # The name of a combined zip file to create containing all the mod zips, or omit to disable.
      # For example, setting this to `all mods` will upload an `all mods.zip` file.
      #
      # This is mainly useful when the repository contains multiple mods, so you can download all of
      # the zips at once before releasing them individually.
      create_combined_zip: ""

      # Whether to create GitHub attestations for each uploaded artifact.
      #
      # This requires the `id-token: write` and `attestations: write` permissions (which are enabled
      # by the default worflow), and should usually be enabled only for release builds.
      create_attestations: false
```

This provides three output variables:

token             | contains
----------------- | --------
`attestation-id`  | The GitHub attestation ID, like `17379361`.
`attestation-url` | The GitHub attestation URL, like `https://github.com/Pathoschild/SMAPI/attestations/17379361`.
`attestation-bundle-path` | The absolute path to the file containing the generated attestation, like `/tmp/attestation.json`.

You can reference these as tokens in any later workflow step. For example, if you set
`id: create-artifacts`, then you can get the attestation URL using
`${{steps.create-artifacts.outputs.attestation-url}}`.

# More actions
There's a [rich ecosystem of actions](https://github.com/marketplace?type=actions) you can add to
your workflow. This section covers a few examples which are particularly relevant to Stardew Valley
mod authors.

## Upload to GitHub
Creating a [GitHub release][] lets players download your mods directly from your GitHub repo.

See [ncipollo/release-action](https://github.com/ncipollo/release-action) for the available options.

For example, you can create a release with all the zip files in the `_releases` folder when a tag is
pushed:
```yaml
- name: Upload to GitHub
  uses: ncipollo/release-action@v1
  if: github.ref_type == 'tag'
  with:
      artifacts: '_releases/*.zip'
      name: 'Mod version ${{github.ref_name}}'
      body: |
          See [release notes][].

          [release notes]: docs/release-notes.md#${{github.ref_name}}
```

If your workflow [creates an attestation](#upload-release-artifacts), you can reference it in any of
those fields. For example:

```yaml
body: See [attestation](${{steps.create-artifacts.outputs.attestation-url}}).
```

The action has many other options to customize your workflow, like...
- creating a draft release;
- creating a Git tag;
- updating an existing release;
- auto-generating release notes;
- etc.

## Upload to Nexus Mods
You can deploy a mod update to your [Nexus Mods][] mod page automatically, usually based on a
release tag or branch.

See [Nexus-Mods/upload-action](https://github.com/Nexus-Mods/upload-action) to configure the
required options.

For example, you can upload an update with a compiled zip file when a tag is pushed (using the tag
name as the version):
```yaml
- name: Upload to Nexus Mods
  uses: Nexus-Mods/upload-action@<tag>
  if: github.ref_type == 'tag'
  with:
    api_key: ${{secrets.NEXUS_MODS_API_KEY}}
    file_group_id: <file_group_id>
    filename: _releases/YourMod-${{github.ref_name}}.zip
    version: ${{github.ref_name}}
```

# See also
* [Release notes](_docs/release-notes.md)

[attestations]: https://docs.github.com/en/actions/concepts/security/artifact-attestations
[Git flow]: https://www.gitkraken.com/learn/git/git-flow
[GitHub Actions]: https://github.com/features/actions
[GitHub release]: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
[Nexus Mods]: https://www.nexusmods.com/games/stardewvalley
[reference assemblies]: https://learn.microsoft.com/en-us/dotnet/standard/assembly/reference-assemblies

[mod build package]: https://smapi.io/package
[SMAPI]: https://github.com/Pathoschild/SMAPI
[StardewModders/mod-reference-assemblies]: https://github.com/StardewModders/mod-reference-assemblies
