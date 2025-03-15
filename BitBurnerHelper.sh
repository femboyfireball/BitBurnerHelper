#!/bin/env bash
#set -v
set -e # Exit on any error. Might build in error handling in the future but meh, I hate error
       # handling in both bash and powershell.

##################################################################################################
##################################################################################################
##                                                                                              ##
##    /$$$$$$$  /$$$$$$$$ /$$$$$$$  /$$   /$$  /$$$$$$   /$$$$$$  /$$$$$$ /$$   /$$  /$$$$$$    ##
##   | $$__  $$| $$_____/| $$__  $$| $$  | $$ /$$__  $$ /$$__  $$|_  $$_/| $$$ | $$ /$$__  $$   ##
##   | $$  \ $$| $$      | $$  \ $$| $$  | $$| $$  \__/| $$  \__/  | $$  | $$$$| $$| $$  \__/   ##
##   | $$  | $$| $$$$$   | $$$$$$$ | $$  | $$| $$ /$$$$| $$ /$$$$  | $$  | $$ $$ $$| $$ /$$$$   ##
##   | $$  | $$| $$__/   | $$__  $$| $$  | $$| $$|_  $$| $$|_  $$  | $$  | $$  $$$$| $$|_  $$   ##
##   | $$  | $$| $$      | $$  \ $$| $$  | $$| $$  \ $$| $$  \ $$  | $$  | $$\  $$$| $$  \ $$   ##
##   | $$$$$$$/| $$$$$$$$| $$$$$$$/|  $$$$$$/|  $$$$$$/|  $$$$$$/ /$$$$$$| $$ \  $$|  $$$$$$/   ##
##   |_______/ |________/|_______/  \______/  \______/  \______/ |______/|__/  \__/ \______/    ##
##                                                                                              ##
##    Special author's note:                                                                    ##
##  		"I fucking hate bash scripting."                                                    ##
##  		--FemboyFireball, March 14, 2025                                                    ##
##                                                                                              ##
##################################################################################################
##################################################################################################

# Random yes/no prompt function I found on StackOverflow, thanks https://stackoverflow.com/a/29436423
# Slightly modified to work better for my brain
function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) echo true; break  ;;
            [Nn]*) echo false; break ;;
        esac
    done
}

function cleanup() {
	if [ -v $editorPid ]; then
		kill $editorPid;
	fi
	kill $bitburnerPid;
	exit 0
}

# Didn't find the config file, resort to setting it up from scratch.
if [ ! -f "/home/$(whoami)/.config/BitBurnerHelperScript/config" ]; then
	echo "Did not find a config file for the BitBurner Helper Script";
	echo "Please input an absolute folder path to put the BitBurner source code (BitBurner game files)";
	echo "e.x, /home/$(whoami)/BitBurner/ or /home/bob/BitBurner";
	read bbSrcPath;
	doUseEditor=$(yes_or_no "Do you wish to use an external editor?")
	echo $doUseEditor;
	# Set up the variables for the external editor setup
	if [[ $doUseEditor ]]; then
		echo "This script currently only supports Viteburner and bb-external-editor"
		while true; do
			read -p "Viteburner or bb-external-editor? " editor;
			case $editor in
				"Viteburner")
					break;;
				"bb-external-editor")
					break;;
			esac
		done

		echo "Please input an absolute folder path to put the external editor tool";
		echo "e.x, /home/$(whoami)/BitBurnerScripts/ or /home/bob/BitBurnerScripts";
		read bbEditorPath;
	fi

	# Create any missing directories
	if [ ! -d "/home/$(whoami)/.config/BitBurnerHelperScript" ]; then
		echo "Creating config directory...";
		mkdir "/home/$(whoami)/.config/BitBurnerHelperScript";
	fi
	if [ ! -d "$bbSrcPath" ]; then
		echo "Creating BitBurner directory...";
		mkdir $bbSrcPath;
	fi
	if [ ! -d "$bbEditorPath" ]; then
		echo "Creating BitBurner editor directory...";
		mkdir $bbEditorPath;
	fi
	# The > probably makes the file anyways? Either way, touch it just to be sure.
	touch "/home/$(whoami)/.config/BitBurnerHelperScript/config";

	echo "Creating config file...";

	# Redirect the path to the Bitburner src and to the editor tool (If applicable) to the config file.
	printf "bbSrcPath=\"$bbSrcPath\"\ndoUseEditor=$doUseEditor\n" > /home/$(whoami)/.config/BitBurnerHelperScript/config;
	if [[ $doUseEditor ]]; then
		printf "bbEditorPath=\"$bbEditorPath\"\neditor=$editor" >> /home/$(whoami)/.config/BitBurnerHelperScript/config;
	fi
fi

# Gotta find an alternative to this. If someone replaces the config file with rm -rf --no-preserve-root / then the user is fucked.
# Just runs the code in the given script, not good.
# Then again, perhaps the source of the ultimate troll or revenge against your friend. Please don't troll your friend like this lol
source /home/$(whoami)/.config/BitBurnerHelperScript/config;
echo "Config loaded!";

# Set up and run the external editor tool (If applicable)
# Has to be done BEFORE BitBurner starts. The modern remote file API for BitBurner connects to the external editor as a client,
# requiring the API server to be running first
if [[ $doUseEditor ]]; then

	echo "Running chosen external editor...";
	if [ ! -d "$bbEditorPath" ]; then
		echo "External editor directory not found, making directory";
		mkdir $bbEditorPath;
	fi
	cd $bbEditorPath;
	if [ "$editor" = "Viteburner" ] ; then
		echo "Initalizing Viteburner";
		if [ ! -n "$(ls -A $bbEditorPath)" ]; then
			echo "Viteburner editor directory is empty... Cloning new instance of Viteburner...";
			# We can reasonably assume that if the folder is empty then this is first time setup
			git clone https://github.com/Tanimodori/viteburner-template.git $bbEditorPath;
		fi
		npm ci;
		echo "Running Viteburner";
		npm run dev &
		editorPid="$1";

	elif [ "$editor" = "bb-external-editor" ]; then
		echo "Initalizing bb-external-editor";
		if [ ! -n "$(ls -A $bbEditorPath)" ]; then
			echo "bb-external-editor directory is empty... Cloning new instance of bb-external-editor...";
			git clone https://github.com/shyguy1412/bb-external-editor $bbEditorPath;
		fi
		npm ci esbuild-bitburner-plugin@latest; # We pull from the template repo this is based off of at the instruction
							                    # of the maintainer
		echo "Running bb-external-editor";
		npm start &
		editorPid="$!";
	fi
fi

# Pull from the BitBurner repo, make sure the npm packages are up to date, and run the webpack
# dev build.

if [ ! -d "$bbSrcPath" ]; then
	echo "BitBurner src directory not found, making directory";
	mkdir $bbSrcPath;
fi
if [ ! -n "$(ls -A $bbSrcPath)" ]; then
	echo "BitBurner src directory empty, cloning from the bitburner repository";
	git clone https://github.com/bitburner-official/bitburner-src $bbSrcPath;
fi

cd $bbSrcPath;
npm ci;
echo "Running bitburner webpack dev...";
npm run start:dev &
bitburnerPid="$!";

echo "Press ctrl+c to close BitBurner and your external editor tool";

trap "cleanup" INT

while true; do
	sleep 1;
done