-- The content-pack seam: POKEPORT_DATA_DIR must reach a booted game, not the
-- ROM picker.
--
-- src/core/Data.lua has honoured POKEPORT_DATA_DIR for a while (loadModule
-- reads every module out of that directory), but main.lua never got that far:
-- love.load gates the whole boot on RomImporter.isReady(), which only ever
-- probed for a ROM-derived cache.  With no cache present isReady() returned
-- false, main.lua opened the importer, and the dataset override was
-- unreachable from a real LOVE process -- so the fixture dataset could only
-- ever be loaded by a test harness calling Data:load() directly.
--
-- That is the limitation tests/modkit/shots.lua and scripts/test.sh both
-- describe ("no LOVE process can be pointed at the fixture dataset").  It is
-- also the seam a total conversion needs: a game whose content is authored
-- rather than extracted has no ROM to import, and must still boot.
--
-- This pins both halves so the seam cannot silently close again.
-- Self-contained: luajit tests/engine/data_dir_boot_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check = T.check
local eq = T.eq

local RomImporter = require("src.import.RomImporter")

local saved = os.getenv("POKEPORT_DATA_DIR")

-- The harness runs with no ROM cache, which is exactly the state that used to
-- send a POKEPORT_DATA_DIR run into the importer.
local function setDataDir(value)
  -- luajit has no os.setenv; the engine reads through os.getenv, so swapping
  -- the reader is both sufficient and side-effect free for other suites.
  local real = os.getenv
  os.getenv = function(name)          -- luacheck: ignore
    if name == "POKEPORT_DATA_DIR" then return value end
    return real(name)
  end
  return function() os.getenv = real end -- luacheck: ignore
end

-- ------- isReady short-circuits when a dataset root is supplied

local restore = setDataDir("tests/fixture_data")
check(RomImporter.isReady("red"),
  "isReady() is true under POKEPORT_DATA_DIR: the dataset replaces the cache")
check(RomImporter.isReady("blue") and RomImporter.isReady("yellow"),
  "and is version-independent -- an authored dataset is not a ROM version")
restore()

-- ------- and is unchanged without it, so shipped builds still import

restore = setDataDir(nil)
eq(RomImporter.isReady("red"), false,
  "without POKEPORT_DATA_DIR a cacheless checkout still needs an import")
restore()

-- ------- Data:load actually reads the override root

local Data = require("src.core.Data")
restore = setDataDir("tests/fixture_data")
local ok, err = pcall(function() Data:load() end)
restore()
check(ok, "Data:load() reads the override root (" .. tostring(err) .. ")")

local species = 0
for _ in pairs(Data.pokemon or {}) do species = species + 1 end
local maps = 0
for _ in pairs(Data.maps or {}) do maps = maps + 1 end
check(species > 0, "the override dataset supplies species (" .. species .. ")")
check(maps > 0, "and maps (" .. maps .. ")")

-- The fixture roster is fixmon_a/b/c, not a Gen 1 roster.  Asserting the
-- absence of the ROM species is what proves the engine is running on authored
-- content rather than quietly falling back to a cache.
check(Data.pokemon.BULBASAUR == nil and Data.pokemon.PIKACHU == nil,
  "and is genuinely not the ROM dataset -- no Gen 1 species present")

-- dexSize is derived from the roster rather than pinned to 151, which is what
-- lets a different roster size work at all (src/core/Data.lua seedDefaults).
check(Data.constants.dexSize and Data.constants.dexSize < 151,
  "dexSize follows the authored roster instead of the Gen 1 count")

if saved then setDataDir(saved) end

T.finish()
