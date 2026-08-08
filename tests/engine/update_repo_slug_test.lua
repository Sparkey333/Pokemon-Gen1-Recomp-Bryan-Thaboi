-- Guard: every self-update path must resolve to ONE repository.
--
-- The updater used to write its GitHub slug out three times -- Check.lua,
-- check_worker.lua and SwitchOta.lua each held their own literal.  On the
-- upstream project that is only repetition.  On a fork it is a way to ship a
-- build that offers users somebody else's releases and then installs one over
-- itself: retarget two of the three literals and the third silently keeps
-- pointing home.
--
-- src/update/Repo.lua is now the single definition.  This test fails if a
-- shipped update path grows its own literal again, and if the derived URLs
-- stop agreeing with each other.
-- Self-contained: luajit tests/engine/update_repo_slug_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.harness")
local check = T.check
local eq = T.eq

local Repo = require("src.update.Repo")

-- ------- the definition itself is well formed

check(type(Repo.SLUG) == "string" and Repo.SLUG:match("^[%w%-%._]+/[%w%-%._]+$"),
  "Repo.SLUG is an owner/name pair (got " .. tostring(Repo.SLUG) .. ")")
eq(Repo.releasesApi(), "https://api.github.com/repos/" .. Repo.SLUG .. "/releases/latest",
  "releasesApi() is built from the slug")
eq(Repo.releasesPage(), "https://github.com/" .. Repo.SLUG .. "/releases/latest",
  "releasesPage() is built from the slug")

-- ------- every consumer agrees

eq(require("src.update.Check").REPO, Repo.SLUG,
  "Check.REPO comes from Repo.SLUG")
eq(require("src.update.SwitchOta").RELEASES_API, Repo.releasesApi(),
  "the Switch OTA feed comes from Repo.SLUG")

-- ------- and nobody has re-hardcoded one

-- check_worker.lua runs on a love.thread with no "src.*" searcher, so it
-- cannot be required here; scan its source instead.  Same scan catches a
-- literal creeping back into any other shipped update path.
local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local body = f:read("*a")
  f:close()
  return body
end

local SHIPPED = {
  "src/update/Check.lua",
  "src/update/check_worker.lua",
  "src/update/SwitchOta.lua",
  "src/update/Boot.lua",
}

local offenders = {}
for _, path in ipairs(SHIPPED) do
  local body = readFile(path)
  if body then
    -- any api.github.com/repos/<owner>/<name> or github.com/<owner>/<name>
    -- written as a literal rather than assembled from the slug
    for url in body:gmatch('"https://api%.github%.com/repos/[^"]+"') do
      offenders[#offenders + 1] = path .. "  " .. url
    end
    for url in body:gmatch('"https://github%.com/[%w%-%._]+/[%w%-%._]+/releases[^"]*"') do
      offenders[#offenders + 1] = path .. "  " .. url
    end
  end
end

check(#offenders == 0,
  "no shipped update path hardcodes a release URL; build it from "
  .. "src/update/Repo.lua instead"
  .. (#offenders > 0 and (":\n  " .. table.concat(offenders, "\n  ")) or ""))

-- check_worker must actually load the shared definition, and must NOT fall
-- back to a guessed slug if that load fails -- a soft fallback is how a fork
-- would quietly resume pointing at upstream.
local worker = readFile("src/update/check_worker.lua") or ""
check(worker:find("src/update/Repo.lua", 1, true) ~= nil,
  "check_worker loads src/update/Repo.lua")
check(worker:find("releasesApi", 1, true) ~= nil,
  "check_worker builds its API URL from the shared helper")

T.finish()
