# proot-turnip-driver

Repository built based of this github issue:
- https://github.com/xDoge26/proot-setup/issues/26

The build flags and the guide is based of the thread, especially from [@hansm629](https://github.com/hansm629)

Current Mesa script build flags support from 24.3.x to 25.x.x

There is a [Mesa Turnip PPA](https://github.com/MastaG/mesa-turnip-ppa) from MastaG but not really stable for my Redmi Note 9 Pro which uses (Snapdragon 720G, Adreno 618), their built packages issue is currently:
- Stutters the whole system
- Random SIGSEGV (Segmentation Fault) while running `glmark2-x11`
Except their build was stable on `vkmark` and `vkcube` tests, which not really surprising.

Log updates:
- Mesa 25.0.2 (26 March 2025)
  My built driver seems has same issue similar to MastaG's driver but worse

Expect more releases soon.
