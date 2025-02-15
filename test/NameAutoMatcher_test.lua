package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
-- local assert_messages = utils.assert_messages
-- local c = utils.console_message
-- local player = utils.player
-- local leader = utils.raid_leader
-- local is_in_raid = utils.is_in_raid

NameAutoMatcherSpec = {}

-- Disabled because it uses softres.it encoded data.
-- function NameAutoMatcherSpec:should_load_encoded_softres_and_match_names()
--   -- Given
--   player( "Psikutas" )
--   is_in_raid( leader( "Psikutas" ), "Stalls" )
--
--   local rf = utils.load_roll_for()
--   local sr = rf.unfiltered_softres
--   rf.import_encoded_softres_data( "eNq9lMFOwzAMht/F5xzW0XVbb4wThwmJwQnt4DXeGjVNKicFbdPeHRc4FCQYoxJH2/H/5Y8cH6GmiBojQn4EoyEHOmhuKlBgXIjoCupye/JbisTOxH0yasZSLo3W5CDfog2koGDCSPo6Qp5k03Q+nWTzVEHb6M/pLJslChiNXkXkGLqKa61VoE0oPOtHtkIUgPOxY8NJQfDbyBSInylA/nQE9tYuvGslGilobBvuHL0HDuuu7ab0rtp70SksBimBlguWlTO7MvbUxWek+l2185+OJvOkX5YrEYvyaX1SvwEvqd4Qbwh534dzK+o/YtNB2IX3Owxlu8MetWFD4YzbyWwI9pprtL6oetAX5I/MD9RskNnbJhgrc8Voe+Aad3SGOhpCvRdXFEMl4MOlfoe98pLYGuflxP+5XUU5Ei4bpqT78n9HPlAtkMt+zbeDtJYVhaw/rY23nqv5ZKxg6/nLmlmfXgESnJNE" )
--
--   -- When
--   local matched, unmatched = rf.name_matcher.get_matches()
--
--   -- Then
--   lu.assertEquals( matched, {
--     { matched_name = "Stalls", similarity = "0.6009", softres_name = "Stolls" }
--   } )
--   lu.assertEquals( unmatched, {} )
--   lu.assertEquals( #sr.get_all_softres_player_names(), 9 )
--   assert_messages(
--     c( "RollFor: Soft-res data loaded successfully!" )
--   )
-- end

utils.mock_libraries()
utils.load_real_stuff()
require( "libs/bcc/LibDeflate/LibDeflate" )
require( "src/bcc/Json" )

os.exit( lu.LuaUnit.run() )
