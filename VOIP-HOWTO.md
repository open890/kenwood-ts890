# Kenwood TS-890 LAN VOIP HOWTO

This file documents the Kenwood TS-890's UDP VOIP data stream and data formats.

This file is very much a work in progress!

## Enabling VOIP

First, establish a connection to the radio as described in the LAN-HOWTO in this repo.

Once connected and signed in, send `##VP1;` to enable the high-quality data stream, or `##VP2;` for the low-quality stream. Send `##VP0;` to turn it off.

After sending `##VP`, the TS-890 will immediately start sending UDP packets back to the connecting IP address on port `60001`

## Data Format

The packets returned are RTP (https://tools.ietf.org/html/rfc3550) packets, with the RTP payload type specified as `96`, which means that it's a vendor-specific payload.

The payload of these packets are simply raw PCM samples, and you can pipe them into `ffmpeg` for transcoding to other formats, like MP3 or M4A (see below)

The high-quality stream is 16-bit signed, little-endian PCM samples at 16000 hz sample rate. The RTP payload will be 640 bytes long.

I think the low-quality stream is 8 bit unsigned, LE PCM at 8000 hz sample rate, but have not verified this yet. 

If you have a Wireshark capture of the UDP packets coming FROM the TS-890, and export just the raw data to a file called `input.bin`,
you can use a program like [scripts/strip-rtp.rb](scripts/strip-rtp.rb) to strip the RTP headers, leaving just the raw PCM samples. This works for the high-quality stream, and
is untested with the low-quality stream.

You can then open `output.bin` in a file like Audacity, specify 16-bit LE PCM as the format, and hear audio!

## Receiving the VOIP stream with ffmpeg

If you have a separate program that will sign in to the radio and enable VOIP, the following command can be used to output an MP3 file of the audio:

`ffmpeg -loglevel quiet -protocol_whitelist file,crypto,rtp,udp -y -vn -dn -acodec pcm_s16le -i ts890-high.sdp -ac 1 -ar 44100 out.mp3`

The [SDP file](sdp/ts890-high.sdp) is required for ffmpeg to receive UDP on port 60001, recognize the custom payload type, and understand the audio format.

Once you have an audio file, you can also create a visualization of it:

`ffmpeg -i out.mp3 -filter_complex "[0:a]showwaves=s=1920x1080:rate=60:mode=p2p:scale=lin:colors=green,format=yuv420p[v]" -map "[v]" -map 0:a -c:v libx264 -c:a copy output.mkv`

## Transmitting audio

To send audio to the TS-890, send RTP packets as described above to the radio on port 60001.

### RTP Payload technical information

An RTP packet looks like this at the byte level:

Version: 2 bits (always decimal 2)
Padding: 1 bit (always decimal 1)
Extension: 1 bit (always decimal 0)
CSRC count: 4 bits (always decimal 0)
Marker: 1 bit (always decimal 0)
Payload Type: 7 bits (always decimal value 96)
Sequence Number: 2 bytes (16 bits), strictly incrementing with each successive packet sent.
Timestamp: 32 bits, but always set to 0x0
SSRC: 32 bits (4 bytes). Always 0x38 0x39 0x30 0x00. Converted to ASCII this looks like '890' in wireshark :)
Payload: 640 bytes of the PCM data.

The radio is expecting an RTP payload of 640 bytes, but in reality, it's 320 values of 16-bit unsigned integers, ranging from 0..65536.

In open890, the JS library I am using to capture microphone audio returns 16-bit signed integers (so, in the range of -32768...32767 inclusive).
I found that the max values were way too loud, and mulitiplying the values by 0.02 seemed to cause the samples to be a reasonable volume.

### Pseudocode:

```
foreach sample in samples:
  # here we have a value of -32768...32767
  sample = int(sample * 0.02) # lower the volume and convert to an integer
  sample = sample + 32768     # compensate for 'dc offset' - ensure all values are now in the range 0...65536
```

You now have 320 values of 16-bit unsigned integers. You can take the high and low bytes of these 16-bit values,
and interpret them as two 8-bit values, therfore having 640 bytes worth of payload for the RTP packet.

Note that if you end up with a value of 0x0 as a sample, you will need to convert it to two bytes of 0x0, i.e.

0x0 == 00000000 00000000 -> [0x0, 0x0]

I'm not sure what the equivalent operation of this is in say, C, or Python, but I managed to hack it together with this Elixir code:

```elixir
packet = data |> Enum.map(fn x ->
  x
  |> Kernel.*(0.02)     # not so loud
  |> trunc()            # convert to integer
  |> Kernel.+(32768)    # DC offset - make all values unsigned
  |> Enum.flat_map(fn sample ->
    # split to high/low bytes so we end up with 640 bytes of payload
    [
      sample >>> 8,
      sample &&& 0xff
    ]
  end)
end)
|> :binary.list_to_bin()
|> RTP.make_packet(seq_num)

:gen_udp.send(audio_tx_socket, String.to_charlist(connection.ip_address), @audio_tx_socket_dst_port, packet)
```

