#!/usr/bin/env ruby

file = "input.bin"
outfile = "output.bin"

File.open(file) do |file|
  File.open(outfile, "wb") do |outfile|

    while (buffer = file.read(652)) do
      puts "read #{buffer.length} bytes"

      stripped_data = buffer[12, 640] # chop off 12 bytes of RTP headers we don't want
      puts "stripped down to #{stripped_data.length} bytes"

      outfile.write(stripped_data)
    end

  end
end
