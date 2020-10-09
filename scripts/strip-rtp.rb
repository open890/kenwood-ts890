#!/usr/bin/env ruby

# This script simply strips all RTP headers off of a raw Wireshark UDP dump
# of the TS-890 audio stream. It assumed you've enabled the high-quality
# stream, and have dumped the data to `input.bin`
#
# You can then load `output.bin` into an audio tool like Audacity

file = "input.bin"
outfile = "output.bin"

File.open(file) do |file|
  File.open(outfile, "wb") do |outfile|

    # HQ UDP packets come in 652 bytes at a time
    while (buffer = file.read(652)) do
      # chop off the first 12 bytes of RTP headers we don't want,
      # writing the remaining 640 bytes to the file.
      outfile.write(buffer[12, 640])
    end

  end
end
