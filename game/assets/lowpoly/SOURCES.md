# Low Poly 3D asset provenance

Downloaded from the authors on 2026-10-05. The files in this directory are reused open assets, not AI-generated art. All four packs are published under **CC0 1.0 Universal**. Kenney's original license files are retained beside the models. The Quaternius declaration is recorded in `quaternius-dinosaur/LICENSE.txt`.

| Author / pack | Version | Original page | Used for |
| --- | --- | --- | --- |
| Kenney / Mini Dungeon | 2.0 | https://kenney.nl/assets/mini-dungeon | Rigged apprentice and enemies; walls, gates, potion, pot, chest, barrel |
| Kenney / Mini Forest | 1.0 | https://kenney.nl/assets/mini-forest | Shelter tent and puzzle platform |
| Kenney / Nature Kit | 2.1 | https://kenney.nl/assets/nature-kit | Trees, bushes, rocks, logs and campfire models |
| Quaternius / Animated Dinosaurs | December 2018; author page has no numbered version | https://quaternius.com/packs/animateddinosaurs.html | Rigged T-Rex; V6 also imports actual Triceratops, Stegosaurus and Velociraptor models with author animations |

## Original downloads and checksums

SHA-256 applies to the downloaded archive or original FBX, before extraction. `source-lock.json` additionally records every retained source model and texture.

- Mini Dungeon: https://kenney.nl/media/pages/assets/mini-dungeon/6cd72dc849-1785314274/kenney_mini-dungeon.zip
  - `19c4648680cb1d2e8836cade96cbf9781c0c1f45fbc6d2ce41cee8239a3ec4d8`
- Nature Kit: https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip
  - `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d`
- Mini Forest: https://kenney.nl/media/pages/assets/mini-forest/44a89aed7f-1784024079/kenney_mini-forest_1.0.zip
  - `8691614018075a66458e35915b8c358c2e6178648aedadafcdf313b924aa6581`
- Animated Dinosaurs: author's public download folder https://drive.google.com/drive/folders/1u5Fhu3ziuRlGonW6bUI7uClqBGoSNeF6
  - T-Rex original file: https://drive.usercontent.google.com/download?id=1JvVm-GNg4nD4MMWRxhsYu1AaxprOIUmy&export=download
  - `db4ae6f657f32ce2253851c3eeca70602be2572b7f5e7fdda3c4c6e7132dea8c`

## Integration and adaptations

V6 adds three unmodified FBX files downloaded from the author's linked public FBX folder on 2026-10-05: `Triceratops.fbx` (Drive ID `1M_CsgQ-e-H7XWBTNlTCRpP6RBe7cM-4A`), `Stegosaurus.fbx` (`1MS0H-3g1tYRiMxmE0bJIGudG56y_h8G2`), and `Velociraptor.fbx` (`1MeDC06WnI8scA1KZqmthmaFIDb8j1XtE`). Their exact original bytes and SHA-256 values are retained in `source-lock.json`. These are separate species meshes, not recolors of the T-Rex. The same CC0 declaration applies.

Godot's built-in glTF and ufbx importers import the original GLB/FBX files. Kenney's external `Textures/colormap.png` paths are preserved. No Blender installation or third-party importer is required.

`res://lowpoly/library.gd` selects the runtime models. `model_visual.gd` duplicates materials per instance, sets roughness, disables imported emission, normalizes model height and drives author animation clips. Animated models are measured after skin deformation because the T-Rex idle clip scales its skeleton relative to the mesh's rest bounds. Trees and rocks receive a restrained forest palette; the T-Rex body becomes terracotta. These changes are made at runtime; original model files are unmodified.

Collision footprints, resource stock and gameplay state remain separate from visual models. The brush, word scroll, paper door and ink/water surfaces are small original Godot meshes for this game's mechanics. UI uses a static medium-weight instance derived from the existing OFL Noto Sans SC variable font. Its original license is retained in `res://fonts/`. Preview PNGs are actual rendered Web gameplay screenshots.

The authored six-room campaign and survival logic are original project code. Design methods reference the user-selected [game-design-skills](https://github.com/jasonxu610/game-design-skills); this migration does not claim to import a complete open-source survival game.
