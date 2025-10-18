# proot-turnip-driver

Repository built based of this github issue:
- https://github.com/xDoge26/proot-setup/issues/26

The build flags and the guide is based of the thread, especially from [@hansm629](https://github.com/hansm629), patches is provided by MastaG.
Pull requests are open, if you have any solution to issues mentioned below please open a issue or pull request.
I may have no more interest debugging these since I do not have knowledge of debugging these, I can confidently say this driver might work using xfce4.
Current Mesa build script flags only supports from 24.3.x to 25.x.x, tested on Redmi Note 9 Pro uses (Snapdragon 720G, Adreno 618).

My setup being:
- Termux nightly build `termux-app_v0.118.0+84a4318`
- [Proot](https://github.com/playbyan1453/ubuntu-termux) setup by my script using ubuntu oracular without desktop environment.
- Download my latest build on GitHub actions
- Extract the `.zip` containing the `.deb` file then copy it to your workdir
- Install the `.deb` file inside the zip on proot
- Run `vkmark` or `glmark-x11`

Log updates:
- Mesa 25.0.2 (26 March 2025)
  My built driver seems has same issue similar to MastaG's driver.
- Mesa 25.2.5 (16 October 2025)
  I can confirm that this latest iteration works fine. (TODO: Update README.md)
