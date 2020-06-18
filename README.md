# Knife Round
This is a plugin that will add an extra round at the start of the game where players face off with only knives to choose what side they start on.

# Information
**NOTE:** I am by no means an expert SourcePawn scripter and appreciate any improvements that I can make.

The plugin will restart the game when warmup ends, strip the weapons (and the bomb) from all players and sets their money to 0 to prevent buying in the knife round
When one of the two teams kill all enemy players they will be able to choose between "swap" or "stay" and the majority vote will decide the result. In case of a stalemate the teams will get swapped. After the knife round the teams will either stay as they are or get swapped. The game will be restarted again so the default CS:GO settings will be applied for all rounds again.

To compile this plugin you will need an include called nexd.inc . All credits for this include go to KillStr3ak (nexd). This is the link to his GitHub page: https://github.com/KillStr3aK.

# Commands
`sm_skipkr`\
Flag: (ADMFLAG_CHANGEMAP)\
Description: Skips the knife round and resume the game as default without swapping the teams.\

`sm_krreload`\
Flag: (ADMFLAG_ROOT)\
Description: Reloads the plugin configuration file.