-- Golden-screenshot capture helper (21-testing-and-ci "golden
-- screenshots").  Only meaningful inside a real LOVE run under a driver:
-- main.lua:98-109 flushes game.capturePath to a PNG after the frame is
-- drawn, so capture is "set the path, yield two frames".
--
-- The diffing lives in tools/compare_shots.py; this side only decides
-- where a shot goes, so a driver and CI agree on the filename without
-- either hard-coding a directory.

local Shots = {}

-- CI hands the run a scratch directory; a developer capturing locally gets
-- the same layout under the repo so --bless-shots can copy them across
Shots.DEFAULT_DIR = "tests/goldens/shots"

function Shots.dir()
  return os.getenv("SHOT_DIR") or Shots.DEFAULT_DIR
end

function Shots.path(name)
  local file = tostring(name):gsub("%.png$", "")
  return Shots.dir() .. "/" .. file .. ".png"
end

-- capture from inside a driver coroutine; `wait` is the driver kit's
-- frame-yield so the capture flushes before the driver moves on
function Shots.capture(game, name, wait)
  game.capturePath = Shots.path(name)
  if wait then wait(2) end
  return game.capturePath
end

-- The fixture-dataset shot list, named here rather than in the workflow so
-- adding a golden is a one-line change next to the driver that produces
-- it.
--
-- The override this list was waiting on now exists: src/core/Data.lua reads
-- POKEPORT_DATA_DIR (loadModule), and RomImporter.isReady() honours it too,
-- so `POKEPORT_DATA_DIR=tests/fixture_data ... love .` boots the game on the
-- ROM-free dataset and renders instead of opening the ROM picker
-- (tests/engine/data_dir_boot_test.lua pins both halves).
--
-- What is still missing is the DATASET, not the plumbing: tests/fixture_data
-- is 3 species / 2 maps and carries no player sprite, so a driver reaches the
-- title screen and the start menu but cannot walk an overworld, open a battle
-- or drive the mod screen.  Capturing the four shots below needs the fixture
-- set grown to a playable slice first; until then a driver can only satisfy
-- the first two.
Shots.FIXTURE_SHOTS = {
  "fixture_title",
  "fixture_start_menu",
  "fixture_battle_intro",
  "fixture_mod_screen",
}

return Shots
