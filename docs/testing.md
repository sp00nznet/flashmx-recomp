# Testing

The harness compares what the recomp exports against what the original
Flash.exe exports from the same JSFL script. It runs in the throwaway VM,
since both need the licensed install.

1. `tools\vm\harness.ps1` (`-NoTrial` on a licensed install) runs the
   **original** Flash.exe on `tools\vm\make.jsfl`, which builds a document
   (shapes, text, two keyframes, a frame script), saves `harness.fla` and
   exports the reference `harness.swf`.
2. `tools\vm\proof.ps1` kills every Flash process, checks none is left, runs
   the **recomp** on the same script and reports the `.swf` SHA-256.
3. `py -3 tools\swf_diff.py a.swf b.swf` compares two `.swf` files tag by
   tag and names the first one that differs.

Current result: 1 of 1 identical (`7C908BA3…EBE81302` from both). The `.fla`
is not compared: it embeds a save timestamp, so any two runs differ, the
original's included.

`tools\vm\serial.ps1` types your own serial (`FLASH_SERIAL`, never stored)
into Flash's serial-entry page; `trial.ps1`, `rc.ps1`, `shot.ps1` and
`watch.ps1` drive the trial dialog, run the recomp, screenshot and watch the
licensing processes. Take no screenshot while the serial page is up.
