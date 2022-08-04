set_displays () {
	declare -a screens
	providers=$(xrandr --listproviders)

	while read -r provider; do
		echo "$provider" | grep "Source Output" | grep "Sink Output" >/dev/null 2>&1
		if [[ "$?" == 0 ]]; then
			laptop=$(echo "$provider" | cut -d " " -f 2 | tr -d ":")
		else
			echo "$provider" | grep "Sink Output" >/dev/null 2>&1
			if [[ "$?" == 0 ]]; then
				screens+=($(echo "$provider" | cut -d " " -f 2 | tr -d ":"))
			fi
		fi
	done <<< "$providers"

	for screen in "${screens[@]}"; do
		xrandr --setprovideroutputsource "$screen" "$laptop"
	done

	displays=($(xrandr -q | grep " connected" | cut -d " " -f 1))
	case "${#displays[@]}" in
	1)
		# set laptop screen to primary
		xrandr --output "${displays[0]}" --primary
		echo "Wherever"
		;;
	2)
		# set external screen to extend above laptop
		xrandr --output "${displays[1]}" --auto --above "${displays[0]}"
		# set laptop screen to primary
		xrandr --output "${displays[0]}" --primary
		echo "Office"
		;;
	3)
		# set external screen 1 to extend above laptop
		xrandr --output "${displays[1]}" --auto --above "${displays[0]}"
		# set external screen 2 to extend left of screen 1
		xrandr --output "${displays[2]}" --auto --left-of "${displays[1]}"
		# set external screen 1 as primary
		xrandr --output "${displays[1]}" --primary
		echo "Home"
		;;
	*)
		echo "Too many external screens for me. Do it manually."
		exit 1
		;;
	esac
}
