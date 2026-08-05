extends Object
class_name Palette
## Every colour in the game, in one place.
##
## Before this file the colours lived as 446 literals across 17 scripts, so
## "make the lot warmer at dusk" meant hunting tuples by hand and hoping none
## were missed. Art direction now happens here.
##
## Two rules that are not style preferences:
##
## 1. **The signal trio is load-bearing.** Players read ZAP red, TRACK green and
##    CALL blue off each other from across the lot — off buttons, beams, muzzle
##    glow and the radar, all at once. Refine them if they need refining; never
##    re-assign which mode owns which hue. Someone will get shot over it.
## 2. **These are the values that shipped in 1.2.0**, copied exactly. Any change
##    to a number here is a visible change to the game, so change them
##    deliberately rather than while tidying.
##
## The generator in `tools/gen_art.py` reads its input from this file, so a
## colour changed here also changes the textures built from it.


# ---------------------------------------------------------------------------
# The signal trio — see rule 1 above
# ---------------------------------------------------------------------------

const ZAP := Color(1.0, 0.28, 0.32)
const TRACK := Color(0.30, 1.0, 0.55)
const CALL := Color(0.35, 0.70, 1.0)

## The phone indexes these by mode, so the order has to match MODE_ZAP,
## MODE_TRACK, MODE_CALL.
const MODE := [ZAP, TRACK, CALL]

## Overheating reads as "too hot to be one of the three", so it deliberately
## sits outside the trio rather than being a hotter red.
const OVERHEAT := Color(1.0, 0.42, 0.12)


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------

const ASPHALT := Color(0.085, 0.09, 0.11)
const CONCRETE := Color(0.42, 0.42, 0.44)
const CURB := Color(0.66, 0.64, 0.60)

## Lot markings. Never pure white — fresh paint on a night forecourt blows out
## under the lamps and reads as glowing rather than painted.
const PAINT := Color(0.80, 0.78, 0.62)
const PAINT_RED := Color(0.72, 0.24, 0.20)


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------

const WALL := Color(0.80, 0.78, 0.73)
const WALL_DARK := Color(0.30, 0.34, 0.40)
const WALL_WARM := Color(0.56, 0.50, 0.42)
const TRIM := Color(0.13, 0.30, 0.48)
const SHELF := Color(0.58, 0.56, 0.53)
const STOCK := Color(0.74, 0.47, 0.29)


# ---------------------------------------------------------------------------
# Metal, glass, rubber
# ---------------------------------------------------------------------------

const METAL := Color(0.46, 0.48, 0.52)
const DARK_METAL := Color(0.15, 0.16, 0.19)
const CHROME := Color(0.82, 0.84, 0.88)
const RUBBER := Color(0.06, 0.06, 0.07)

## Both carry their own alpha — the transparency is part of the colour here,
## not a separate material setting.
const GLASS := Color(0.55, 0.72, 0.80, 0.20)
const CAR_GLASS := Color(0.12, 0.16, 0.22, 0.62)


# ---------------------------------------------------------------------------
# Planting
# ---------------------------------------------------------------------------

const HEDGE := Color(0.13, 0.23, 0.15)
const PLANT := Color(0.22, 0.46, 0.20)
const PLANT_LIGHT := Color(0.34, 0.62, 0.26)
const POT := Color(0.52, 0.32, 0.24)


# ---------------------------------------------------------------------------
# Anything that emits
#
# Each of these is an albedo/emission pair rather than one colour. The emission
# is pushed slightly more saturated than the albedo so a sign still reads as lit
# when the bloom is turned down, instead of washing out to its own base colour.
# ---------------------------------------------------------------------------

const COOLER := Color(0.62, 0.86, 0.95)
const COOLER_EMIT := Color(0.35, 0.75, 0.95)
const COOLER_ENERGY := 1.2

const SIGN := Color(0.95, 0.25, 0.30)
const SIGN_EMIT := Color(1.0, 0.20, 0.26)
const SIGN_ENERGY := 2.6

const SIGN_WHITE := Color(0.95, 0.96, 1.0)
const SIGN_WHITE_EMIT := Color(0.9, 0.94, 1.0)
const SIGN_WHITE_ENERGY := 1.8

const SIGN_CYAN := Color(0.35, 0.92, 1.0)
const SIGN_CYAN_EMIT := Color(0.25, 0.90, 1.0)
const SIGN_CYAN_ENERGY := 2.4

const LEAF_SIGN := Color(0.42, 0.86, 0.34)
const LEAF_SIGN_EMIT := Color(0.35, 0.95, 0.30)
const LEAF_SIGN_ENERGY := 2.8

const GROW := Color(0.72, 0.42, 0.95)
const GROW_EMIT := Color(0.78, 0.35, 1.0)
const GROW_ENERGY := 2.6

const LAMP := Color(1.0, 0.96, 0.86)
const LAMP_EMIT := Color(1.0, 0.94, 0.80)
const LAMP_ENERGY := 3.4

const HEADLIGHT := Color(1.0, 0.97, 0.88)
const HEADLIGHT_EMIT := Color(1.0, 0.95, 0.82)
const HEADLIGHT_ENERGY := 3.2

const TAILLIGHT := Color(0.95, 0.16, 0.14)
const TAILLIGHT_EMIT := Color(1.0, 0.12, 0.10)
const TAILLIGHT_ENERGY := 2.2


# ---------------------------------------------------------------------------
# Sky and air
#
# Dusk, not night. The horizon keeps a little of the sunset in it so the lot
# reads as an evening shift rather than the small hours.
# ---------------------------------------------------------------------------

const SKY_TOP := Color(0.07, 0.11, 0.24)
const SKY_HORIZON := Color(0.42, 0.32, 0.36)
const GROUND_HORIZON := Color(0.26, 0.22, 0.26)
const GROUND_BOTTOM := Color(0.07, 0.07, 0.10)

const FOG_LIGHT := Color(0.28, 0.26, 0.36)

## Warm, low and orange — the last of the sun against the cool sky above.
const SUN := Color(1.0, 0.72, 0.58)

## Forecourt lamps run cold against that warm sun. That contrast is what makes
## the canopy read as lit rather than flat.
const LAMP_LIGHT := Color(0.86, 0.92, 1.0)

## Barely-there volumetric cone under each lamp. The alpha is doing all the work
## — raise it and the lot fills with haze.
const LIGHT_SHAFT := Color(1.0, 0.94, 0.78, 0.05)

const SIGN_TEXT_BLUE := Color(0.07, 0.24, 0.50)

# ---------------------------------------------------------------------------
# The real Beach Gas
#
# Taken from photographs of the actual station rather than invented. The
# fictional map is a night forecourt; the real one is a pale gravel clearing in
# the forest, and almost none of the colours above fit it.
# ---------------------------------------------------------------------------

## Crushed limestone, not asphalt. The whole site is this, and it is bright —
## which is why the real map needs its own ambient rather than the night one.
const GRAVEL := Color(0.72, 0.70, 0.66)

## The store: white board-and-batten under a black standing-seam roof.
const STORE_WHITE := Color(0.88, 0.88, 0.86)
const ROOF_BLACK := Color(0.11, 0.11, 0.12)

## The sign. Teal disc, orange-red ring, cream lettering — this is the brand and
## the one thing that must not drift.
const BEACH_TEAL := Color(0.42, 0.72, 0.75)
const BEACH_ORANGE := Color(0.85, 0.34, 0.18)
const BEACH_CREAM := Color(0.96, 0.95, 0.90)

## Summerleaf next door: weathered board, much darker and greyer than the store.
const BARN_WOOD := Color(0.38, 0.34, 0.30)
const CEDAR_FENCE := Color(0.60, 0.48, 0.34)

## The two horizontal fuel tanks, and the tall lot poles.
const TANK_WHITE := Color(0.86, 0.87, 0.86)

## Adirondack chairs — some white, some a strong blue.
const CHAIR_BLUE := Color(0.15, 0.42, 0.82)

## The pylon's LED price digits. Deliberately the same red family as ZAP but not
## the same colour, so nobody reads a price board as a player.
const PRICE_RED := Color(1.0, 0.22, 0.10)

## Daylight, not dusk. The real place is photographed under a hard blue sky.
const DAY_SKY_TOP := Color(0.25, 0.52, 0.86)
const DAY_SKY_HORIZON := Color(0.74, 0.85, 0.93)
const DAY_SUN := Color(1.0, 0.96, 0.88)
const FOREST_DARK := Color(0.13, 0.24, 0.14)
const FOREST_LIGHT := Color(0.22, 0.40, 0.20)
const TRUNK := Color(0.30, 0.26, 0.22)
