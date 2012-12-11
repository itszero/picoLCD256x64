#!/usr/bin/env ruby
require 'rubygems'
require 'libusb'

class PicoLCD256x64
  PICOLCD_USB_EP_WRITE = 0x01
  OUT_REPORT_LCD_BACKLIGHT = 0x91
  OUT_REPORT_LCD_CONTRAST = 0x92
  OUT_REPORT_CMD = 0x94
  OUT_REPORT_DATA = 0x95
  OUT_REPORT_CMD_DATA = 0x96
  SCREEN_W = 256
  SCREEN_H = 64

  class DeviceNotOpenedException < Exception; end
  class InvalidScreenBufferSizeException < Exception; end

  def self.devices
    usb = LIBUSB::Context.new
    usb.devices(:idVendor => 0x04d8, :idProduct => 0xc002).map { |dev|
      PicoLCD256x64.new(dev)
    }
  end

  def initialize(device)
    @device = device
  end

  def open
    @handle = @device.open
    @handle.set_configuration(1)
    @handle.detach_kernel_driver(0) if @handle.kernel_driver_active?(0)
    @handle.claim_interface(0)
  end

  def close
    @handle.close
    @handle = nil
  end

  def backlight_off
    write([OUT_REPORT_LCD_BACKLIGHT, 0x00])
  end

  def backlight_on(level=0xFF)
    write([OUT_REPORT_LCD_BACKLIGHT, level])
  end

  def set_contrast(contrast)
    contrast = 0 if contrast < 0
    contrast = 0xFF if contrast > 0xFF
    write([OUT_REPORT_LCD_CONTRAST, contrast])
  end

  def update(screen=[0] * SCREEN_W * SCREEN_H)
    screen = screen.flatten
    raise InvalidScreenBufferSizeException unless screen.size == SCREEN_W * SCREEN_H

    0.upto(3) do |cs|
      chipsel = (cs << 2)
      0.upto(7) do |line|
        pkt1 = [OUT_REPORT_CMD_DATA, chipsel, 0x02, 0x00, 0x00, 0xb8 | line, 0x00, 0x00, 0x40, 0x00, 0x00, 32]
        pkt2 = [OUT_REPORT_DATA, chipsel | 0x01, 0x00, 0x00, 32]

        0.upto(63) do |index|
          pixel = 0x00
          0.upto(7) do |bit|
            x = cs * 64 + index
            y = (line * 8 + bit) % SCREEN_H

            pixel |= (1 << bit) if (screen[y * 256 + x] > 0)
          end
          (index < 32 ? pkt1 : pkt2) << pixel
        end
        write(pkt1); write(pkt2);
      end
    end

    true
  end

  def write(data)
    raise DeviceNotOpenedException if @handle.nil?

    @handle.interrupt_transfer(
      :endpoint => PICOLCD_USB_EP_WRITE,
      :dataOut => data.pack("C*")
    )
  end
end

if __FILE__ == $0
  # drawing
  require 'chunky_png'
  img = ChunkyPNG::Image.from_file("1.png")
  screen = []
  0.upto(63) do |rownum|
    row = []
    0.upto(255) do |colnum|
      row << ((ChunkyPNG::Color.grayscale_teint(img[colnum, rownum]) > 254 ? 0 : 1) rescue 0)
    end
    screen << row
  end


  devices = PicoLCD256x64.devices
  if devices.size == 0
    puts "**ERR: No PicoLCD 256x64 found"
    exit
  end

  puts "** Found PicoLCD256x64 device"
  device = devices[0]
  puts "** Open USB interface"
  device.open
  puts "** Sending update"
  device.backlight_on
  device.set_contrast(210)
  device.update(screen)
  puts "** Close interface"
  device.close
end