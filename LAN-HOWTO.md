# Kenwood TS-890 LAN Connection HOWTO

The Kenwood TS-890 has an extensive command set, and there are some goodies you can only access via the LAN port, like the audio VOIP stream, or the high-speed bandscope. The Kenwood documentation is actually quite good, but there are some gotchas.

During this process, you can refer to the TS-890 command reference here: https://www.kenwood.com/i/products/info/amateur/pdf/ts890_pc_command_en_rev1.pdf

In general, commands are send one line at a time, although occasionally, the TS-890 will send multiple commands at once, but still separated by a semicolon (`;`). I've found that it's a good process to read data from the socket one line at a time, and split any incoming data on the semicolon, and then deal with each command individually.

## Gotchas

* The TS-890 will close the TCP connection if it does not receive any data for 10 seconds. The simple way to get around this is to send the `PS;` (Power Status) command every 5 seconds once you're connected - this is what the ARCP software from Kenwood does.

## Getting Started

* Set up a user on the radio in KNS. Let's assume the username is `kenwood` and the password is `admin`
* Connect your TS-890 to your home network, turn on DHCP (on the radio), or assign a static IP address. Let's assume the radio is assigned the internal IP address `192.168.1.100`

Open a TCP socket to the radio on port `60000`. Once connected, send the string `##CN;`

If you're allowed to connect, the radio will respond with `##CN1;`, otherwise it will respond with `##CN0;`

## Send username and password

Now, we need to send the username and password, but in a special format that the radio wants. The general format is:

`##ID<user_type><length_of_username><length_of_password><username><password>;`

* `user_type` is `0` if the KNS user you setup is designated as an administrator, otherwise, use the string `0` (zero)
* The length of the username and password is a 2-digit number between `01` and `32` (indicating the length in characters of each)

So, if you set up an admin user named `kenwood` and the password `admin`, the full connection string becomes:

`##ID00705kenwoodadmin;`

If successful, the radio will then automatically send three responses for `##ID`, `##UE` and `##TI` commands, all on one line. **Don't expect each command on its own line here**:

e.g.:

`##ID1;##UE1;##TI1;`

Once you get the response from the `TI` command, you may start sending commands back to the radio, e.g. `AI2;` to enable auto-info mode, or `##VP1;` to enable the VOIP audio stream.
