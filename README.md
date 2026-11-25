# Space Marine Master Crafted Edition: controller not working fix (PC)

**Warhammer 40,000: Space Marine - Master Crafted Edition** on PC ignores your
Xbox controller, Steam Controller or other gamepad, the keyboard still works, and
the game shows **PlayStation button prompts**. Toggling Steam Input, Big Picture,
the Steam overlay and running as admin make no difference.

## The cause

Some other device plugged into your PC is telling Windows it is a **joystick**.
The game grabs that fake joystick as "the controller" and ignores your real one.

In my case it was a **Keychron keyboard**: its USB connection includes an extra
"HID-compliant game controller". Other keyboards, mouse receivers, RGB/fan
controllers, wheels, pedals and flight-stick software can do the same.

The fix is to turn that fake joystick off. Your keyboard (or whatever it is)
keeps working normally; only the fake game-controller part is disabled.

## Check if this is you

Press **Win + R**, type `joy.cpl`, press Enter. If the list shows anything that
is not a real controller, or shows something even with your controller turned
off, that is almost certainly the problem.

## Fix 1: unplug it

Unplug the keyboard / gadget, launch the game, try the controller. If it now
works, you have found the culprit. Use Fix 2 or 3 so you can plug it back in.

## Fix 2: Device Manager (by hand)

1. Right-click **Start** > **Device Manager**.
2. Expand **Human Interface Devices**.
3. Find each **HID-compliant game controller**. For each one: right-click >
   **Properties** > **Details** tab > Property: **Hardware Ids**.
   - `VID_045E` = Microsoft / Xbox, `VID_054C` = Sony / PlayStation,
     `VID_28DE` = Valve / Steam. Those are real controllers: leave them alone.
   - Anything else is likely the fake one. (Mine was `VID_3434` = Keychron.)
4. Right-click the fake one > **Disable device** > Yes.
5. **Restart the PC.** Windows often only applies this after a restart, and it
   may even show an error before then.

To undo: same place, right-click > **Enable device**.

## Fix 3: the script

[`Fix-PhantomJoystick.ps1`](Fix-PhantomJoystick.ps1) does Fix 2 for you:

- lists every joystick / gamepad device Windows can see, with the real gadget name
- marks in **yellow** the ones that look fake (the same gadget is also a keyboard or mouse)
- marks known controller brands as "keep" and asks before touching them
- lets you choose which to disable, or type `U` to re-enable what you disabled
- offers to restart (it only restarts if you say yes)

Nothing is deleted. Every change can be undone with the script or Device Manager.

### Run it

1. Turn your real controllers **on** first, so you can tell them apart in the list.
2. Download [`Fix-PhantomJoystick.ps1`](https://raw.githubusercontent.com/mock1ngbb/space-marine-master-crafted-controller-fix/hee-haw/Fix-PhantomJoystick.ps1)
   (right-click the link > Save link as).
3. Right-click the downloaded file > **Run with PowerShell**. Accept the admin prompt.
4. Type the number(s) of the fake device(s) and press Enter, then let it restart.

It is a short plain-text script: open it in Notepad and read it before running it.

If Windows says the file is blocked: right-click it > Properties > tick
**Unblock** > OK.

## Does this apply to other games?

Yes. Any game that takes "the first controller it finds" can be confused the
same way, so if another game ignores your controller, check `joy.cpl` too.

## License

MIT, see [LICENSE](LICENSE).
