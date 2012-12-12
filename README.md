picoLCD256x64
=============

PicoLCD 256x64 user-space driver/renderer. [Screenshot].

## Current Status

It's a Ruby/libusb-based driver for controlling [picoLCD] 256x64.  The driver
should work on Windows/Linux/Mac. It requires no driver on Linux platform.  For
Windows, you may need a libusb driver for it. For Mac, It requires a codeless
kext to be installed on the system, detaching the device from OSX HID driver so
that it could be controlled by user-space driver.

The project is still in its early stage. The picolcd.rb serves as a driver and
CLI program for now.  It simply takes "1.png" and send it to LCD. The LCD
renderer only draws a image with hard-coded. I will change it to take JSON as
input and draws the image according to the input specification.

## Credits

* Codeless Kext idea comes from [k8055-mac-codeless-kext]. Thanks, Piha.
* MetaWatch font comes from [MetaWatch] project.
* [Parson], Small json parser and reader written in C.

## License

Copyright (c) 2012 Chien-An "Zero" Cho

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[Screenshot]: https://raw.github.com/itszero/picoLCD256x64/master/Screenshot.jpg
[picoLCD]: http://www.picolcd.com/
[k8055-mac-codeless-kext]: https://github.com/piha/k8055-mac-codeless-kext
[MetaWatch]: http://www.metawatch.org
[Parson]: https://github.com/kgabis/parson