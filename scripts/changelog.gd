extends Node
class_name Changelog
## Version history, newest first.
##
## Kept as data rather than a text file so the menu can render it properly and
## it can never drift from what shipped. Add a new entry at the top and bump
## VERSION whenever you build for the phones — that's the number people will
## quote at you when something breaks.

const VERSION := "1.0.0"

const ENTRIES: Array[Dictionary] = [
	{
		"version": "1.0.0",
		"title": "Beach Gas: Cellular Warfare",
		"notes": [
			"Renamed from Lens Lethal.",
			"Phone now has a working home screen — status bar, apps, dock. Your theme colour lives here, and the ZAP/TRACK/CALL icons light up to show what the lens is set to.",
			"Crouch, on a button or C.",
			"Big optimisation pass: world geometry collapsed from 350+ meshes to 49, characters from 55 to 14.",
			"Fixed: the host was clamping every hit to 12 damage instead of 34, so kills took nine shots instead of three.",
			"Your character is your name now — no separate handle to type.",
		],
	},
	{
		"version": "0.9.0",
		"title": "Character select and settings",
		"notes": [
			"Twelve characters with a live 3D select screen, each with their own pose, particle signature and stage lighting.",
			"Settings: graphics quality, frame rate, audio levels, fire mode, aim assist, look sensitivity.",
			"Tap the right side of the screen to fire, so your aiming thumb never leaves it.",
			"Aim assist for touch, and auto-fire as an option.",
			"Fixed: arms were mounted inside the torso, and every 'arm out' pose drove the left arm into the ribs.",
		],
	},
	{
		"version": "0.8.0",
		"title": "The lot gets bigger",
		"notes": [
			"Map redesigned and roughly doubled in size.",
			"Summerleaf dispensary replaces the car wash.",
			"Loading dock with a ramp, so jumping has a point.",
			"Seven vehicles you can hide behind and climb on.",
			"Ambient traffic: cars pull in, sit at a pump, and drive away.",
			"Map edges opened up — invisible boundary with the world visibly carrying on past it.",
		],
	},
	{
		"version": "0.7.0",
		"title": "Visual overhaul",
		"notes": [
			"Characters are actual people now rather than capsules.",
			"Rebuilt the viewmodel: machined phone, three-lens camera, a hand with fingers. The beam fires from the camera lens.",
			"Muzzle flash, surface-aware impacts, screen shake, head bob, landing dip, sprint speed lines.",
			"Directional damage ring around the reticle.",
		],
	},
	{
		"version": "0.6.0",
		"title": "Lobby and presentation",
		"notes": [
			"Map selection in the lobby with a drawn top-down preview.",
			"Animated main menu backdrop — real camera shots of the actual map.",
		],
	},
	{
		"version": "0.5.0",
		"title": "Call rework",
		"notes": [
			"Answering removed. A ring just slows you and takes your gun away, and ice crusts over you so everyone can see it landed.",
			"Calls reach anyone, anywhere — no line of sight needed, because phone calls don't need one.",
			"Proper death screen with a respawn countdown.",
			"No round limit; the score just keeps climbing.",
			"Fixed: a ring that expired naturally never cleaned itself up, leaving the ringtone looping forever and silently blocking every future call.",
		],
	},
	{
		"version": "0.4.0",
		"title": "Heat",
		"notes": [
			"Battery and charging pads removed — ammo is unlimited.",
			"Overheat replaces ammo as the limiter on the laser.",
			"Numerical cooldown timers on every ability.",
		],
	},
	{
		"version": "0.3.0",
		"title": "Practice and customisation",
		"notes": [
			"Practice mode against a bot, so you can play without waiting for anyone.",
			"Phone case colours and HUD themes.",
			"Protocol versioning, so mismatched builds say so instead of misbehaving.",
		],
	},
	{
		"version": "0.2.0",
		"title": "Finding each other",
		"notes": [
			"Automatic LAN discovery — the host appears in a list, no IP typing.",
			"Join code as a fallback for networks that block broadcasts.",
			"Up to 8 players. Scoreboard.",
		],
	},
	{
		"version": "0.1.0",
		"title": "First playable",
		"notes": [
			"Two-player LAN duel on a gas station forecourt.",
			"Your phone is the weapon: zap, track, call.",
			"Touch controls and desktop controls.",
		],
	},
]
