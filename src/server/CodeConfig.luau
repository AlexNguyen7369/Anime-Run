--!nonstrict
-- Redeemable codes (docs/MONETIZATION_SPEC.md). Server only: never move this to Shared.
-- Keys are upper case; grants are boost ids from Shared/BoostConfig. Codes never pay Money.
return {
	Codes = {
		RELEASE = { Grants = { LuckII = 2, SpeedII = 2, StaminaII = 2 } }, -- placeholder until the owner adds real codes
	},
}
