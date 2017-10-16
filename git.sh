#!/bin/bash
trap "exit 1" TERM
export TOP_PID=$$

DIRECTORIES=""	# Zde lze inicializovat pole zadanim slozek, kde se nachazeji repozitare, se kterymi se bude pracovat
				# Pokud pole neni inicializovano, jsou za repozitare povazovany vsechny slozky v adresari, kde se skript nachazi
FETCHES=""
i=0


# prompt
promptYN () {
	while true; do
		read -p "Some error occured. Please read GIT error log. Do you want to continue a running script? " yn < /dev/tty
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) kill -s TERM $TOP_PID;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}


# Ziskani URL jednotlivych repozitaru tak, aby je bylo mozne dale vyuzit - napr. push
if [ -z "$DIRECTORIES" ]; then
	echo "---------- Resolving subdirectories names ----------"
	# prohledani celeho adresare k nalezeni slozek (vyjma skrytych slozek)
	for item in `find . -maxdepth 1 -type d \( -iname "*" ! -iname ".*" \)`; do	
		DIRECTORIES[$i]=$item;
		echo "$i: $item"
		i=$((i + 1));
	done
	echo "---------- Directories names resolved ----------"
fi

# Pro kazdou slozku - repozitar se ziska jeho URL + URL vsech jeho remote
for item in "${DIRECTORIES[@]}"; do

	cd "$item";
	isFetch=1

	echo "---------- Working in a directory \"$item\" ----------"
	# ziskani checkoutnute vetve pro nasledny checkout na konci
	checkoutTmp=$(echo "$(git status)"  | grep "\# On branch " | sed -e 's/^\# On branch //g');
	if [ ! "$checkoutTmp" ]; then
		checkoutTmp=$(echo "$(git status)"  | grep "On branch " | sed -e 's/^On branch //g');
	fi
	echo "Local repository is on branch $checkoutTmp"

	# ziskani url vsech remote repozitaru
	REMOTE_V=$(echo "$(git remote -v || kill -s TERM $TOP_PID)"  | grep \(fetch\));

	echo "Repository has this remotes:" 
	echo "$REMOTE_V"

	i=0;
	GIT_URL=""
	# Provedeni FETCH a MERGE jednotlivych remote repozitaru daneho lokalniho repozitare
	while read -r address; do
			if [ ! "$address" ]; then
				continue;
			fi

		# alias adresa vzdaleneho repozitare
		GIT_URL[$i]=$(echo "$address"  | sed -e 's/\t.*$//g');

		i=$((i + 1));
	done  <<< "$REMOTE_V"
	
	# Opakuj dokud je nějaká změna.
	while [ $isFetch -eq 1 ]; do
		isFetch=0
		i=0
		for remoteRepo in "${GIT_URL[@]}"; do
			# git fetch
			IFS=$"\n"
			# provedeni FETCH a ziskani zmen (zmena = jeden radek)
			echo "git fetch $remoteRepo"
			FETCHES_BUFFER="$(git fetch "$remoteRepo" 2>&1)" || { promptYN; continue; };
			FETCHES[$i]=$(echo "$FETCHES_BUFFER" | sed -n -e '/^From /,$p' | sed '1d');

			# pro vsechny radky ve vyse nalezenych zmenach se provede:
			# 1. checkout do dane vetve
			# 2. merge
			# 3. pull do ostatnich adresaru v dane vetvi
			# 4. push dane vetve do ostatnich remote repozitaru
			while read -r line; do
				if [ ! "$line" ] || echo "$line" | grep "FETCH_HEAD" ; then
					continue;
				fi

				isFetch=1
				parsedServer="";
				parsedServer=$(echo "$line" | sed -e 's/^.*->\s*//g');
				parsedBranch="";
				parsedBranch=$(echo "$parsedServer" | sed -e 's/^.*\///g');
				parsedServer=$(echo "$parsedServer" | sed -e 's/\/.*$//g');

				if [ ! "$(echo "$(git branch)" | sed -n "/\(^\*\|^ \)\s$parsedBranch$/p")" ]; then
					# branch does not exist
					echo "git checkout -b $parsedBranch $parsedServer/$parsedBranch";
					git checkout -b "$parsedBranch" "$parsedServer/$parsedBranch" > /dev/null 2>&1 || promptYN;
				else
					# branch does exist
					echo "git checkout $parsedBranch";
					git checkout "$parsedBranch" > /dev/null 2>&1 || promptYN;
				fi

				# git merge
				echo "git merge $parsedServer/$parsedBranch"
				git merge "$parsedServer/$parsedBranch" > /dev/null 2>&1 || promptYN

				# pull zmen z ostatnich repozitaru
				repoIt=0;
				for repos in "${GIT_URL[@]}"; do
					if [ $repoIt -eq $i ]; then
						repoIt=$((repoIt + 1));
						continue;
					fi

					echo "git pull ${GIT_URL[$repoIt]} $parsedBranch"
					if ! (git pull "${GIT_URL[$repoIt]}" "$parsedBranch" > /dev/null 2>&1); then
						if [ ! "$(echo "$(git pull "${GIT_URL[$repoIt]}" "$parsedBranch" 2>&1)" | sed -n "/fatal: Couldn.t find remote ref $parsedBranch/p")" ]; then
							sleep 1
							echo "Problem with a command \"git pull ${GIT_URL[$repoIt]} $parsedBranch\".";
							promptYN
						fi
					fi

					repoIt=$((repoIt + 1));
				done
				
				# push zmen do vsech repozitaru
				repoIt=0;
				for repos in "${GIT_URL[@]}"; do
					echo "git push ${GIT_URL[$repoIt]} $parsedBranch"
					git push "${GIT_URL[$repoIt]}" "$parsedBranch" > /dev/null 2>&1 || promptYN
					repoIt=$((repoIt + 1));
				done
		
			done <<< "${FETCHES[$i]}"

			i=$((i + 1));
		done
		if [ $isFetch -eq 1 ]; then
			echo "---------- Next iteration ----------"
		fi
	done

	#############################################################
	#############################################################

	echo "git checkout $checkoutTmp"
	git checkout "$checkoutTmp" > /dev/null 2>&1

	echo "---------- Leaving a directory \"$item\" ----------";
	cd "..";

done

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "++++++++++++++++++DONE+++++++++++++++++++++++"
echo "+++++++++++++++++++++++++++++++++++++++++++++"


# for t in "${FETCHES[@]}"
# do
#	echo $t
# done
