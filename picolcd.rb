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
  require 'json'
  require 'chunky_png'
  require 'open3'
  require 'withings'
  include Withings

  Dir.chdir("lcd_renderer")
  stdin, stdout, wait_thr = Open3.popen2("src/lcd_renderer", 'rw')
  Dir.chdir("..")

  devices = PicoLCD256x64.devices
  if devices.size == 0
    puts "**ERR: No PicoLCD 256x64 found"
    exit
  end

  puts "** Found PicoLCD256x64 device"
  device = devices[0]
  puts "** Open USB interface"
  device.open

  Withings.consumer_key = '<redacted>'
  Withings.consumer_secret = '<redacted>'

  config = JSON.parse(File.read("lcd_renderer/example.json"))

  while true
    print "** Acquire metrics: [CPU, "
    cpu_idle = `top -l 1 | grep "CPU usage"`.match(/(\d+(\.\d+)?)% idle/)[1].to_f
    cpu_busy = 100 - cpu_idle
    config['values']['cpu_usage'] = cpu_busy / 100
    config['values']['cpu_usage_text'] = "CPU: %.1f%%" % cpu_busy

    print "MEM, "
    all_mem = `sysctl hw.memsize | awk '{print $2;}'`.to_i
    free_mem = `vm_stat | grep "free\\|speculative"`.scan(/\d+/).map(&:to_i).inject(0) { |sum, i| sum += i } * 4096
    free_mem_prt = free_mem.to_f / all_mem
    config['values']['mem_usage'] = (1 - free_mem_prt)
    config['values']['mem_usage_text'] = "MEM: %.1f%% %dM" % [(1 - free_mem_prt) * 100, free_mem / 1024 / 1024]

    print "DISK, "
    root_info = `df -m /`.split("\n")[1].split(" ")
    root_free = root_info[3].to_i
    root_free_prt = root_info[4].to_i
    root_mountpoint = root_info[-1]
    config['values']['disk_usage'] = root_free_prt.to_f / 100
    config['values']['disk_usage_text'] = "%s: %s%% %dM" % [root_mountpoint, root_free_prt, root_free]

    print "uptime, "
    config['values']['uptime'] = `uptime`.split(' ')[1..-1].join(' ').gsub(/ averages/, '')
    config['values']['infobar'] = "%s // %s // %s" % [Time.now.strftime("%Y/%m/%d %H:%M") ,`hostname`.strip, `system_profiler SPSoftwareDataType | grep "System Version"`.strip.split(' ')[2..-1].join(' ')]

    print "Withings]\n"
    m = JSON.parse(File.read("withings.cache")) rescue nil
    if m.nil? or (Time.now.to_i - m['capture_at'] > 60 * 5)
      puts "** No Withings Cache, Update Now."
      withing_user = User.authenticate(ENV['WITHINGS_ID'].to_i, ENV['WITHINGS_KEY'], ENV['WITHINGS_SECRET'])
      last_measurement = withing_user.measurement_groups(:per_page => 1, :page => 0, :end_at => Time.now)[0]
      m = {
        'weight' => last_measurement.weight,
        'taken_at' => last_measurement.taken_at.to_i,
        'capture_at' => Time.now.to_i
      }
      File.open("withings.cache", 'w') do |f| f.write m.to_json end
    end
    config['values']['omnibar_title'] = 'Weight'
    config['values']['omnibar_content'] = "You're #{m['weight']} kg @ #{Time.at(m['taken_at']).strftime("%Y/%m/%d %H:%M:%S")}"

    puts "** Rendering"
    png_data = nil
    json_out = config.to_json
    stdin.write [json_out.length].pack("l")
    stdin.write config.to_json
    stdin.flush

    size = stdout.read(4).unpack("l")[0]
    puts "** PNG Size: #{size}"
    img = ChunkyPNG::Image.from_blob(stdout.read(size))

    screen = []
    0.upto(63) do |rownum|
      row = []
      0.upto(255) do |colnum|
        row << ((ChunkyPNG::Color.grayscale_teint(img[colnum, rownum]) > 254 ? 0 : 1) rescue 0)
      end
      screen << row
    end

    puts "** Sending update"
    device.backlight_on
    device.set_contrast(210)
    device.update(screen)
  end
end
