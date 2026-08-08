-- The GitHub repository this build updates itself from.
--
-- WHY THIS FILE EXISTS: the slug used to be written out three times --
-- src/update/Check.lua, src/update/check_worker.lua and src/update/SwitchOta.lua
-- each carried their own copy.  For the upstream project that is merely
-- repetitive; for a fork it is a live hazard.  A fork that ships a build while
-- any copy still names the upstream repository offers ITS users UPSTREAM's
-- releases, and the self-updater will happily download and install that
-- payload over the fork.  Missing one of three literals is enough to do it.
--
-- One definition, three readers, so retargeting a fork is a one-line change
-- that cannot be half-applied.
--
-- Pure Lua, no love.*: src/update/check_worker.lua runs on a love.thread where
-- the "src.*" package searcher does not exist and pulls this in with
-- love.filesystem.load instead (the same trick it already uses for Semver and
-- Boot), so this file must stay require-free.

local Repo = {}

-- owner/name on GitHub.  Changing this retargets the update check, the Switch
-- OTA feed and the "what's new" link together.
Repo.SLUG = "Sparkey333/Pokemon-Gen1-Recomp-Bryan-Thaboi"

function Repo.releasesApi()
  return "https://api.github.com/repos/" .. Repo.SLUG .. "/releases/latest"
end

function Repo.releasesPage()
  return "https://github.com/" .. Repo.SLUG .. "/releases/latest"
end

return Repo
