# proot-turnip-driver

Repository built based of this github issue:
- https://github.com/xDoge26/proot-setup/issues/26

The build flags and the guide is based of the thread, especially from [@hansm629](https://github.com/hansm629)

There is a [Mesa Turnip PPA](https://github.com/MastaG/mesa-turnip-ppa) from MastaG but not really stable for my Redmi Note 9 Pro which uses (Snapdragon 720G, Adreno 618), their built packages issue is currently:
- Stutters the whole system
- Random SIGSEGV (Segmentation Fault) while running `glmark2-x11`
Except their build was stable on `vkmark` and `vkcube` tests, which not really surprising.

Expect more releases soon.
