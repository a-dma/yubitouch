* YubiTouch

A Bash script for setting or clearing touch requirements for
cryptographic operations in the OpenPGP application on a *YubiKey 4*
or *YubiKey 5*.

** Note

This tool has been superseded in functionality by [[https://developers.yubico.com/yubikey-manager/][YubiKey Manager]]
(currently only the CLI side). However, some people have shown
interest in keeping this script around for ease of use and because of
its smaller surface / fewer dependencies.

* Dependencies

 - ~gpg-connect-agent~ for talking to the device
 - ~pinentry~ (any kind, optional) for reading the admin PIN
 - ~xxd~ or ~od~ for hex/ASCII conversion

* Usage

Run the tool as:
#+BEGIN_SRC sh
./yubitouch.sh {all|sig|aut|dec} {get|off|on|fix|cacheon|cachefix} [admin_pin]
#+END_SRC

where the parameters indicate the following:

#+BEGIN_EXAMPLE
 {all|sig|aut|dec|att} All keys, signature, authentication, decryption or attestation key
 {get|off|on|fix|cacheon|cachefix} Touch setting to use
 [admin_pin] The Admin PIN of the YubiKey (optional)
#+END_EXAMPLE

** Key choice

The five possible values for the key parameter are explained below.

- all :: Loop over all keys
- sig :: Key used for digital signatures
- aut :: Key used for authentication (e.g. SSH)
- dec :: Key used for decryption
- att :: Key used for attestation. YubiKey 5.2.2 and later

The attestation functionality is a Yubico proprietary extension. More
information available [[https://developers.yubico.com/PGP/Attestation.html][here]].

** Touch settings

The six possible touch settings are explained below.

- get :: Read out the current touch setting of the private key
- off :: Touch is not required to use the private key
- on :: Touch is required to use the private key
- fix :: Same as _on_, plus it can only be reset by
         deleting/overwriting the private key
- cacheon :: Same as _on_, plus each touch event is cached for 15
             seconds. YubiKey 5.2.1 and later
- cachefix :: Combination of _cacheon_ and _fix_. This setting can be
              changed to the more restrictive _fix_. YubiKey 5.2.1 and
              later

Setting the touch option to ~fix~ will cause any subsequent invocation
of this script on that same subkey to do nothing. The only way to
reset this is by generating or importing a new key for that slot.

Setting the touch option to ~cacheon~ or ~cachefix~ on a key will make
the device "remember" a touch event for 15 seconds allowing commands
requiring touch that are sent to the OpenPGP application to behave is
if touch was provided. The touch timeout counter is not reset after an
implicit touch. It is not possible to change the 15 seconds value.

Once set to ~cachefix~, the touch option can only be changed to ~fix~.
To change it to any other value a new key must be generated or
imported.

** PIN input

If a PIN is provided through the command line, make sure to
escape/quote it if it contains special characters like ~$~. Also, *be
mindful of having sensitive data stored in your shell history*.

If the Admin PIN is not provided through the command line, the tool
will ask the user for it. If a version of ~pinentry~ is available it
will be used, otherwise it will fall back to reading standard input. If all is
used for the key parameter then the tool will ask the user only once for it.

** Personalization advice

To mitigate the fact that this tool needs to interact with the Admin
PIN of a device, it is advisable to run the script after having
generated/imported keys, but /before/ doing the full device
personalization. Specifically, using this tool on a YubiKey that still
has the default Admin PIN (~12345678~) set.
