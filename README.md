# What this is

This is a number of poorly-documented libraries and utilities for the Minecraft
mods ComputerCraft and OpenComputers; this was originally designed for the
former, but the compatibility has since become much better with the latter.
(Please submit an issue if functionality which *should* be available in one mod
is apparently not.)

# How do I get it?

Using whichever `wget`-like client you have in your implementation, grab and
run the raw version of `programs/bootstrap`. This installer script is smart
enough to know the difference between CC and OC, and will configure itself to
work correctly in at least these cases. However, if you're doing something
weird (such as pointing it to another repository), you may have to edit it
slightly before running it. It *does* support installing to an alternate prefix
(e.g., the default of `/usr` on OC), which may help in generating installer
disks, by passing the alternative path as the first argument.

This script works by downloading one of the `manifest.*` files in the root of
this repository, and using the instructions in that file to download the rest
of the repository. This is a very flexible system for installing various
software, and you are welcome to take it and adapt it to your needs.

# Projects so far

## `libdaemon`, `dctl`, and `daemon_load`

This is a flexible framework for implementing and controlling
*daemons*--applications that run in the background, primarily responding to
events (such as signals or the passage of time). This system is designed to be
robust, stable, and usable; in particular, it *shall not* leave defunct
callbacks still registered for a daemon which was stopped or crashed, which
hopefully prevents instability and flooding of system event logs. Daemons are
provided by templates objects which permit them to be started multiple times;
each call to `start` returns a new instance which is independently controllable
from the others.

The `dctl` program is the primary method of user interaction with daemons.
Refer to its help (by running it without arguments) for details.

The `daemon_load` program reads the file `/etc/daemon.cfg`, which it
unserializes (executes, essentially), and determines if the object has a
`start` key which is a table; if it does, the keys of the table are interpreted
as daemon names to start. There is presently no way to pass parameters into the
daemon (use the `/etc/daemon/dmn` configuration file for a daemon called `dmn`
in the same serialized format), nor is there any way to start more than one
daemon from the same template. Note that the environment for deserialization is
empty, so while functions can be created (unlike serialization.serialize would
allow), no upcalls can be made. `daemon_load` can be started anyway at about
anytime, but it's common to either make it the `$PATH/rc.lua` file, or invoke
it from there.

As of manifest version 22 or so, `/etc/rc.d/daemon.lua` is also installed,
making it compatible with OpenOS's RC system. Simply run:

	rc daemon enable

...and populate `/etc/daemon.cfg` as above:

	{start={daemon1=true,daemon2=true}}

The computer will load and start `daemon1` and `daemon2` on reboot. This method
still doesn't allow for starting multiple instances, nor passing configuration
(but you can still write a serialized config file to `/etc/daemon/daemon1` for
a daemon called `daemon1` if need be).

## `vim`, `libtedit`, and `lib2daccel`

This is a Lua reimplementation of the class UNIX text editor. It is hardly
feature-complete, but it at least functional enough to work as expected where
implemented. It supports various features, many of which are not supported in
the built-in editors, such as:

- Syntax highlighting (presently only for Lua, but extensible via `libtedit`).
- Line wrapping.

...and, of course, it supports a core subset of Vim's very powerful text
editing commands, which are vastly superior to the built-in editors.

Vim and libtedit are codeveloped, and their REVISION numbers indicate this; the
Vim program is little more than an input-handling frontend to libtedit's
features. Others are welcome to build any other frontend on libtedit (and
report bugs or suggest features when doing so).

`lib2daccel` is an acceleration library that assists in rendering
highly-colored text to OC screens; since a GPU direct call is required for each
foreground color set, it is impractical to set the color for each character.
lib2daccel manipulates "framebuffer" objects, which represent an application's
"desired" state of a screen, and provide the same API as the OC GPU (so they
can be used as a drop-in replacement). When gathering calls, no screen-drawing
happens; all drawing is cached in the internal model. Finally, a
lib2daccel-using program will (probably at the end of an event loop) "flush"
the framebuffer model to the real device, which synchronizes the state.
Framebuffers can optimize draw calls further by assuming that no other call
will touch the screen between calls to `flush()`, which allows it to completely
skip cells that did not change since the last flush. Vim and libtedit are
notable users of this API, when syntax highlighting is enabled.

## `libhwproxy`, `hwproxyd`, and `libnic`

This is an implementation of a (non-secure, non-authenticated) protocol for
allowing remote (over-a-network) access to components. `libhwproxy` is the
"local" side, whereas `hwproxyd` is the remote side; the latter provides
components for access, and the former accesses these components via the
protocol. `libhwproxy` does attempt to use local components when possible, so
as to avoid expensive round trips.

`libnic` is a support library for `libhwproxy` and related network applications
that provides, most usefully, a `broadcast_all` function, which sends a mesage
to every networking component (locally) reachable.

## `libchem`

This is an implementation of a correct, but possibly slightly energy-wasteful
algorithm for creating arbitrary elements using MineChem, which, given a state
and a desired state subset, emits a series of "steps" (fusion and fission
operations) which creates the desired state subset. It is untested in practice
(because fusion is hard to automate), but it seems numerically correct.


## `libtftp`, `tftpd`, and `update`

`libtftp` is a user-side library for interfacing `tftpd`, which implements a
"trivial file transfer protocol" over layer 2. No authentication or
checksumming is done (yet), but can be easily implemented out-of-band.
Transfer, like real TFTP, is lockstep (not particularly fast). Transfers are
uniquely identified by both a modem address and a filename; the cautious can
verify authenticity (in the absence of spoofing cards) by checking the "remote
NIC" address. The broadcast method of discovery also generally chooses the
closest and most-responsive server for a given file, which allows for mirroring
and load-balancing automatically (simply run multiple servers). There is no
namespace separation yet, but do note that `tftpd` does not respond in the
negative for files it does not have, so the "effectively served set" on a
network is the union of all served files. It's dangerous and unwise to have
different versions on different servers on the same broadcast domain.

`update` is a proof-of-concept using `libtftp` to implement much the same
program as `bootstrap`. To make an update server, first ensure you have
`bootstrap` revision _at least 8_, then:

	mkdir /srv
	bootstrap /srv raw

...this version of the bootstrap program should ask you to confirm "VERY
CAREFULLY" that you intended to do a raw bootstrap (id est, not an install, but
a mirror of the repo). Select yes (`y`), and allow it to download into `/srv`.

Then, as with `libdaemon` above, enable a `tftpd` daemon:

	rc enable daemon
	echo "{start={tftpd=true}}" > /etc/daemon.cfg

Then `reboot` (or at least `dctl load tftpd` and `dctl start tftpd` if you
don't want to reboot).

You can then `bootstrap /srv raw` on this machine each time you want to
download updates from this Git repository. The download will be done over the
Internet only once; on clients with the `update` program installed, simply run:

	update

...this script will check for an "update server" serving the `manifest.oc` file
(as this repository does). If it finds it, it will transfer all the content
`bootstrap` would have, but strictly over OpenOS' networks (id est, not
requiring an internet card).

**As a replacement for bootstrap:** If you want to bootstrap using `update`
alone, note that it requires `libtftp` and `libnic` (transitively). Assuming a
TFTP server as specified is running on your broadcast segment, `wget` the
following files from this repository:

	programs/update
	apis/libtftp
	apis/libnic

In your working directory, ensure the files are named `libtftp.lua` and
`libnic.lua`. Afterward, simply run `update`.

When you are done, **remove libtftp.lua and libnic.lua** so they don't
accidentally override the system-installed versions.

You can also do this using a floppy disk. Simply copy these files from a
working installation:

	/usr/bin/update.lua
	/usr/lib/libtftp.lua
	/usr/lib/libnic.lua

(Assuming the install prefix was `/usr`; if not, adjust the initial path
component appropriately.) Then, install the floppy disk into a drive, allow
OpenOS to mount it, `cd` to its mountpoint, and run `update`. Remove the floppy
when finished; a reboot is recommended as well.

# Licensing

As with the base OpenComputers addon, all programs in this repository are under
the *MIT License*. You are free to use, derive work from, modify, and
distribute this software as you please, provided that you retain the copyright
notice--see `COPYING`.
