# proot-turnip-driver

Repository built based of this github issue:
- https://github.com/xDoge26/proot-setup/issues/26

The build flags and the guide is based of the thread, especially from [@hansm629](https://github.com/hansm629), patches is provided by MastaG.
Pull requests are open, if you have any solution to issues mentioned below please open a issue or pull requests.
I may have no more interest debugging these since I do not have knowledge of debugging these, might pick this up again in the future.

Current Mesa build script flags only supports from 24.3.x to 25.x.x

There is a [Mesa Turnip PPA](https://github.com/MastaG/mesa-turnip-ppa) from MastaG tested on Redmi Note 9 Pro which uses (Snapdragon 720G, Adreno 618), their built packages issue is currently:
- Stutters the whole system
- Presistent SIGSEGV (Segmentation Fault) while running `glmark2-x11`
Except their build was stable on `vkmark` and `vkcube` tests, which not really surprising.

My setup being:
- Termux nightly build `termux-app_v0.118.0+84a4318`
- [Proot](https://github.com/playbyan1453/ubuntu-termux) setup by my script using ubuntu oracular
- Download my latest build on GitHub actions
- Extract the `.deb` then copy it to your workdir
- Install the `.deb` file inside the zip on proot
- Run `vkmark`

Log updates:
- Mesa 25.0.2 (26 March 2025)
  My built driver seems has same issue similar to MastaG's driver.
- Mesa 25.2.5 (16 October 2025)
  I can confirm that this latest iteration works fine. (TODO: Update README.md)
