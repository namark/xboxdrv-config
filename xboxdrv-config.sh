#!/bin/sh

### constants

xbox_button_keys="A B X Y RB RT LB LT START BACK TL TR"
xbox_axis_keys="DPAD_X DPAD_Y X1 Y1 X2 Y2"

##done

### globals

event=""
mappings=""
same=""
axismap=""
filename=""

##done

### functions

OnExit()
{
	trap "trap - TERM && $*" INT TERM EXIT
}

PressEnter()
{
	if [ -z "$1" ]
	then
		printf "Press Enter to proceed..."
	else
		printf "$1"
	fi
	sed -n q < /dev/tty
}

DetectInputEvent()
{
	events_before=$(mktemp)
	events_after=$(mktemp)

	ls /dev/input/event* -1 > "$events_before"
	echo
	echo "If the input device is connected please disconnect it, otherwise connect it."
	PressEnter
	ls /dev/input/event* -1 > "$events_after"
	event=$(diff "$events_after" "$events_before" | awk '/^[<>] /' | sed 's/^[<>] //')
	rm "$events_after" "$events_before"

	if [ -z "$event" ]
	then
		echo "Could not detect input event. Please try again, or specify the event manually using the -e option."
		exit
	else
		echo
		echo "Input event detected: $event"
		echo "If you have disconnected the input device previously connect it now."
	fi
}

GetMappings()
{
	mappings=""
	for key in $1; do
		PressEnter "Select a mapping for $key"

		mapping=$(tail -1 "$keys")
		if [ ! -z "$mappings" ]
		then
			mappings="$mappings,"
		fi
		mappings="$mappings$mapping=$key"

		echo  "$mapping"
		echo
	done
}

##done

### handle parameters
while [ $# -gt 0 ]
do
	if [ "$(echo "$1" | cut -c 1-1)" = "-" ]
	then
		param=${1#-}
		if [ "$param" = "h" ]
		then
			echo
			echo "xboxdrv_config [params]"
			echo
			echo Params:
			echo " -e\t\tSpecify the event to create mappings for"
			echo " -i\t\tSpecify an axis to invert"
			echo " -o\t\tSpecify an output file/directory name"
			echo " -s\t\tRun evtest in the same terminal window instead of a separate xterm"
			echo " -h\t\tShow this help message"
			echo
			exit
			exit
		elif [ "$param" = "e" ]
		then
			shift
			event=$1
		elif [ "$param" = "f" ]
		then
			shift
			# TODO: output format, cmd = in the command itself, cfg = in a config file
		elif [ "$param" = "o" ]
		then
			# TODO: output filename or directory, in case of -f cmd it will create name.sh, otherwise name/run.sh name/conf.xbcfg
			shift
			filename="$1.sh"
		elif [ "$param" = "j" ]
		then
			shift
			# TODO: include a commands for linking js0 to whatever event xboxdrv creates
		elif [ "$param" = "i" ]
		then
			shift
			if [ ! -z "$axismap" ]
			then
				axismap="$axismap,"
			fi
			axismap="$axismap-$1=$1"
		elif [ "$param" = "s" ]
		then
			same="true"
		fi
	fi
	shift
done
##done

if [ -z "$event" ]
then
	DetectInputEvent
fi

echo
echo "Next you will be asked to specify the button/axis mappings one by one."
echo "All the input from your device will be logged in a separate(or the same, if -s was specified) terminal window,"
echo "but only the last line will be selected as a mapping for a given button/axis once you press Enter here,"
echo "so you can play around as much as you want to make sure you pressed the right thing."
PressEnter

keys=$(mktemp)

OnExit "rm $keys && kill -- -$$"

evtest "$event" | stdbuf -oL awk '/ type [^4]/ && /value [^0]/' | stdbuf -oL sed -e 's/\(^.*(\)//' -e 's/\().*$\)//' > "$keys" &

if [ -z $same ]
then
	xterm -e "printf 'Pressed keys will be logged here.\n' && tail -f $keys" &
else
	printf 'Pressed keys will be logged here.\n' && tail -f "$keys" &
fi

cmd="xboxdrv --evdev $event"

GetMappings "$xbox_button_keys"
cmd="$cmd --evdev-keymap $mappings"

GetMappings "$xbox_axis_keys"
cmd="$cmd --evdev-absmap $mappings"

if [ ! -z "$axismap" ]
then
	cmd="$cmd --axismap $axismap"
fi

echo "Mapping done."
echo
echo "Here is the command with mappings set up:"
echo "$cmd"

if [ ! -z "$filename" ];
then
	echo "$cmd" > "$filename"
	chmod +x "$filename"
	echo
	echo "Also written to $filename"
	echo
fi

echo "Please review before running. The command/configuration only contains the mappings, you'll have to specify any additional parameters manually."
